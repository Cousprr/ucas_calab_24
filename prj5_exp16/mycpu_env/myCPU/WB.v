    //exc types
    `define TYPE_SYS    0
    `define TYPE_ADEF   1
    `define TYPE_ALE    2
    `define TYPE_BRK    3
    `define TYPE_INE    4
    `define TYPE_INT    5
    
    //ecodes
    `define EXC_ECODE_SYS   6'h0B
    `define EXC_ECODE_INT   6'h00
    `define EXC_ECODE_ADE   6'h08
    `define EXC_ECODE_ALE   6'h09
    `define EXC_ECODE_BRK   6'h0C
    `define EXC_ECODE_INE   6'h0D
    //esubcodes
    `define EXC_ESUBCODE_ADEF   9'h000

module WB(
    input  wire        clk,
    input  wire        resetn,
    //from MEM
    output wire WB_allow_in,
    input wire MEM_to_WB_valid,
    input wire [187:0] MEM_to_WB_bus,
    //to ID
    output wire [37:0] WB_to_ID_bus,
    //for DEBUG
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    //csr
    output wire csr_we,
    output wire [13:0]csr_num,
    output wire [31:0] csr_wmask,    //写掩码
    output wire [31:0] csr_wvalue,   //写数据

    output wire wb_ex,               //异常处理触发信号
    output wire [5:0] wb_ecode,
    output wire [8:0] wb_esubcode,
    output wire [31:0] WB_pc,

    output wire ertn_flush,
    output wire [15:0] WB_to_csr_bus,
    output wire [31:0] wb_badvaddr
    );
    
    //inside MEM
    reg WB_valid;
    wire WB_ready_go;
    assign WB_ready_go = 1'b1;
    assign WB_allow_in = WB_ready_go | ~WB_valid;//有区别
    wire [31:0] WB_inst;
    
    always @(posedge clk)begin
        if(~resetn)begin
            WB_valid <= 1'b0;
        end
        else if(WB_allow_in)begin
            WB_valid <= MEM_to_WB_valid;
        end
    end  

    // reg [63:0] MEM_to_WB_bus_valid;
    reg [187:0] MEM_to_WB_bus_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_to_WB_bus_valid <= 188'b0;
        end
        else if(MEM_to_WB_valid & WB_allow_in)begin
            MEM_to_WB_bus_valid <= MEM_to_WB_bus;
        end
    end
    
    //bus
    wire [31:0] final_result;
    wire            res_from_mem;
    wire            gr_we;
    wire    [  4:0] dest;
    wire WB_csr_we;
    wire [13:0] WB_csr_num;
    wire [31:0] WB_csr_wmask;
    wire [31:0] WB_csr_wvalue;
    wire inst_ertn;
    wire [5:0]WB_ex_type;
    assign {WB_csr_we, WB_csr_num, WB_csr_wmask, WB_csr_wvalue, inst_ertn, WB_ex_type,
            final_result,
            gr_we, dest,
            WB_pc, WB_inst} = MEM_to_WB_bus_valid;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    assign rf_we    = gr_we && WB_valid && ~is_ertn_exc;
    assign rf_waddr = dest;
    assign rf_wdata = final_result;
    
    assign debug_wb_pc       = WB_pc;
    assign debug_wb_rf_we   = {4{rf_we}};//修改拼写
    assign debug_wb_rf_wnum  = dest;
    assign debug_wb_rf_wdata = final_result;
    
    //bus
    assign WB_to_ID_bus = {rf_we, rf_waddr, rf_wdata};

//change exp12 csr
    assign wb_ex = WB_valid & (|WB_ex_type);
    //assign wb_ecode    = {6{WB_ex_type[0]}} & 6'h0B;//`TYPE_SYS=0  EXC_ECODE_SYS=6'h0B
    //assign wb_esubcode = 9'b0;
    
    //change exp13 start
    assign wb_ecode = {6{WB_ex_type[`TYPE_ADEF]}} & `EXC_ECODE_ADE|
                       {6{WB_ex_type[`TYPE_BRK ]}} & `EXC_ECODE_BRK|
                       {6{WB_ex_type[`TYPE_INE ]}} & `EXC_ECODE_INE|
                       {6{WB_ex_type[`TYPE_INT ]}} & `EXC_ECODE_INT|
                       {6{WB_ex_type[`TYPE_ALE ]}} & `EXC_ECODE_ALE|
                       {6{WB_ex_type[`TYPE_SYS ]}} & `EXC_ECODE_SYS;

    assign wb_esubcode = {9{WB_ex_type[`TYPE_ADEF]}} & `EXC_ESUBCODE_ADEF;
    
    assign wb_badvaddr = final_result;//用于向csr模块传递出错的访存"虚"地址
    //change exp13 end
    
    assign ertn_flush = inst_ertn & WB_valid;
    assign WB_to_csr_bus = {WB_csr_we & WB_valid, ertn_flush, WB_csr_num};

    assign csr_wmask = WB_csr_wmask;
    assign csr_we    = WB_csr_we & WB_valid & ~wb_ex;
    assign csr_num  = WB_csr_num;
    assign csr_wvalue  = WB_csr_wvalue;

    reg exc_reg;
    reg ertn_reg;
    assign is_ertn_exc = wb_ex | ertn_flush | exc_reg | ertn_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
        else if (wb_ex) begin
            exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            ertn_reg <= 1'b1;
        end 
        else if (MEM_to_WB_valid & WB_allow_in)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end
    end
endmodule
