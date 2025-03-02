    `define CSR_CRMD    14'h000
    `define CSR_PRMD    14'h001
    `define CSR_ESTAT   14'h005
    `define CSR_ERA     14'h006
    `define CSR_EENTRY  14'h00c
    `define CSR_SAVE0   14'h030
    `define CSR_SAVE1   14'h031
    `define CSR_SAVE2   14'h032
    `define CSR_SAVE3   14'h033
    `define CSR_ECFG    14'h004
    `define CSR_BADV    14'h007
    `define CSR_TID     14'h040
    `define CSR_TCFG    14'h041
    `define CSR_TVAL    14'h042
    `define CSR_TICLR   14'h044
    `define CSR_CRMD_PLV 1:0
    `define CSR_PRMD_PPLV 1:0
    `define CSR_CRMD_PIE 2
    `define CSR_PRMD_PIE 2
    `define CSR_ECFG_LIE 12:0
    `define CSR_ESTAT_IS10 1:0
    `define CSR_ERA_PC  31:0
    `define CSR_EENTRY_VA 31:6
    `define CSR_SAVE_DATA 31:0
module csr(
    input wire clk,
    input wire resetn,

    //读使能省略

    input wire csr_we,              //写使能
    input wire [13:0] csr_num,      //寄存器号(写)
    input wire [31:0] csr_wmask,    //写掩码
    input wire [31:0] csr_wvalue,   //写数据

    input wire [13:0] csr_raddr,    //读地址
    output wire [31:0] csr_rvalue,  //读数据

    output wire [31:0] ex_entry,    //中断程序入口地址
    output wire [31:0] ex_exit,     //中断程序退出地址

    input wire ertn_flush,          //ertn指令执行的有效信号
    output wire has_int,            //中断有效信号

    input wire wb_ex,               //异常处理触发信号
    input wire [5:0] wb_ecode,
    input wire [8:0] wb_esubcode,
    input wire [31:0] WB_pc
);

//CRMD
    //CRMD-PLV
    reg [1:0] csr_crmd_plv;
    reg [1:0] csr_prmd_pplv;
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_plv <= 2'b0;
        else if (wb_ex)
            csr_crmd_plv <= 2'b0;
        else if (ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if (csr_we && csr_num ==`CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]| ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
    end

    //CRMD-IE
    reg csr_crmd_ie;
    reg csr_prmd_pie;
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_ie <= 1'b0;
        else if (wb_ex)
            csr_crmd_ie <= 1'b0;
        else if (ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if (csr_we && csr_num ==`CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]| ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
    end

    //第十章改
    wire csr_crmd_da;
    wire csr_crmd_pg;
    wire [1:0] csr_crmd_datf;
    wire [1:0] csr_crmd_datm;
    assign csr_crmd_da = 1'b1;
    assign csr_crmd_pg = 1'b0;
    assign csr_crmd_datf = 2'b00;
    assign csr_crmd_datm = 2'b00;

    wire [31:0] csr_crmd_rvalue;
    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

//PRMD  
    
    //PRMD-PPLV,PIE
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_num ==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV] | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE] | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
        end
    end
    wire [31:0] csr_prmd_rvalue;
    assign  csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};

//for exp13
//ECFG
    //ECFG-LIE
    reg     [12:0]  csr_ecfg_lie;
    always @(posedge clk) begin
        if (~resetn)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num ==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE] | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
    end
    wire [31:0] csr_ecfg_rvalue;
    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};


//ESTAT
    //ESTAT-IS
    reg [12:0] csr_estat_is;
    always @(posedge clk) begin
        if (~resetn)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num ==`CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        csr_estat_is[9:2] <= 8'b0;
        //csr_estat_is[9:2] <= hw_int_in[7:0];

        csr_estat_is[10] <= 1'b0;

        csr_estat_is[11] <= 1'b0;//exp13要改
        //if (timer_cnt[31:0]==32'b0)
        //    csr_estat_is[11] <= 1'b1;
        //else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wvalue[`CSR_TICLR_CLR])
        //    csr_estat_is[11] <= 1'b0;
        
        csr_estat_is[12] <= 1'b0;
        //csr_estat_is[12] <= ipi_int_in;
    end
    
    //ESTAT-Ecode Esubcode
    reg     [ 5:0]  csr_estat_ecode;
    reg     [ 8:0]  csr_estat_esubcode;
    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
    
    wire [31:0] csr_estat_rvalue;
    assign csr_estat_rvalue = { 4'b0, csr_estat_esubcode, csr_estat_ecode, csr_estat_is };


//ERA
    //ERA-PC
    reg [31:0] csr_era_pc;
    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= WB_pc;
        else if (csr_we && csr_num ==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
    
    wire [31:0] csr_era_rvalue;
    assign  csr_era_rvalue = csr_era_pc;

//EENTRY
    //EENTRY-VA
    reg [25:0] csr_eentry_va;
    always @(posedge clk) begin
        if (csr_we && csr_num ==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end

    wire [31:0] csr_eentry_rvalue;
    assign  csr_eentry_rvalue = { 6'b0, csr_eentry_va };


//SAVE 0-3
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;
    always @(posedge clk) begin
        if (csr_we && csr_num ==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
        if (csr_we && csr_num ==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
        if (csr_we && csr_num ==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
        if (csr_we && csr_num ==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
    end
    assign { csr_save0_rvalue, csr_save1_rvalue, csr_save2_rvalue, csr_save3_rvalue } = { csr_save0_data,  csr_save1_data,  csr_save2_data,  csr_save3_data };

    // assign ex_entry  = csr_eentry_rvalue;
    // assign ex_exit  = csr_era_rvalue;

    assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

    assign csr_rvalue = {32{csr_raddr == `CSR_CRMD  }} & csr_crmd_rvalue     |
                        {32{csr_raddr == `CSR_PRMD  }} & csr_prmd_rvalue    |
                        {32{csr_num   == `CSR_ECFG  }} & csr_ecfg_rvalue    |
                        {32{csr_raddr == `CSR_ESTAT }} & csr_estat_rvalue   |
                        {32{csr_raddr == `CSR_ERA   }} & csr_era_rvalue     |
                        {32{csr_raddr == `CSR_EENTRY}} & csr_eentry_rvalue  |
                        {32{csr_raddr == `CSR_SAVE0 }} & csr_save0_rvalue   |
                        {32{csr_raddr == `CSR_SAVE1 }} & csr_save1_rvalue   |
                        {32{csr_raddr == `CSR_SAVE2 }} & csr_save2_rvalue   |
                        {32{csr_raddr == `CSR_SAVE3 }} & csr_save3_rvalue   ;

endmodule