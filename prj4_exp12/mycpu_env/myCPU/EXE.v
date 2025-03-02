module EXE(
    input  wire        clk,
    input  wire        resetn,
    //from ID
    output wire EXE_allow_in,
    input wire ID_to_EXE_valid,
    input wire [306:0] ID_to_EXE_bus,//改位宽
    //to MEM
    output wire EXE_to_MEM_valid,
    input wire MEM_allow_in,
    output wire [188:0] EXE_to_MEM_bus,
    // to data sram interface
    output wire        data_sram_en,
    output wire [3 :0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    //判断阻塞 EXE写信号
    output wire  [38:0]EXE_wr_bus,

    //csr
    output [15:0] EXE_to_csr_bus,
    input wb_ex,
    input ertn_flush,
    input MEM_ex,
    input MEM_ertn
    );

    wire    [18:0]  alu_op;//声明提前
    
    //有符号除
    wire [31:0] div_src1;//有符号除 被除数
    wire [31:0] div_src2;//有符号除 除数
    wire div_src1_ready;
    wire div_src2_ready;
    wire div_src1_valid;
    wire div_src2_valid;
    reg div_src1_flag;//为1时表示成功发送。除法操作完成后清零
    reg div_src2_flag;
    wire [63:0] div_res;//有符号除 结果
    wire [31:0] div_res_remainder;//余数
    wire [31:0] div_res_quotient;//商
    wire div_out_valid;//有符号除 返回值有效
    
    //无符号除
    wire [31:0] divu_src1;//无符号除 被除数
    wire [31:0] divu_src2;//无符号除 除数
    wire divu_src1_ready;
    wire divu_src2_ready;
    wire divu_src1_valid;
    wire divu_src2_valid;
    reg divu_src1_flag;//为1时表示成功发送。除法操作完成后清零
    reg divu_src2_flag;
    wire [63:0] divu_res;//无符号除 结果
    wire [31:0] divu_res_remainder;//余数
    wire [31:0] divu_res_quotient;//商
    wire divu_out_valid;//无符号除 返回值有效
    
    //inside EXE
    reg EXE_valid;
    wire EXE_ready_go;
    //assign EXE_ready_go = 1'b1;    
    assign EXE_ready_go = (alu_op[15] | alu_op[17]) & div_out_valid | //有符号除+除法结果准备好
                          (alu_op[16] | alu_op[18]) & divu_out_valid | //无符号除+处罚结果准备好
                          (~(alu_op[15] | alu_op[16] | alu_op[17] | alu_op[18]));//非除法，恒为1
    
    wire [31:0] EXE_inst;
    wire [31:0] EXE_pc;
    assign EXE_to_MEM_valid = EXE_ready_go & EXE_valid;
    assign EXE_allow_in = EXE_to_MEM_valid & MEM_allow_in | ~EXE_valid;
    
    always @(posedge clk)begin
        if(~resetn)begin
            EXE_valid <= 1'b0;
        end
        else if (wb_ex | ertn_flush) begin
            EXE_valid <= 1'b0;
        end
        else if(EXE_allow_in)begin
            EXE_valid <= ID_to_EXE_valid;
        end
    end  

    reg [186:0] ID_to_EXE_bus_valid;
    always @(posedge clk)begin
        if(ID_to_EXE_valid & EXE_allow_in)begin
            ID_to_EXE_bus_valid <= ID_to_EXE_bus;
        end
    end
    //bus
    //wire    [18:0]  alu_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire            res_from_mem;
    wire            gr_we;
    wire            mem_we;
    wire    [ 4:0]  dest;
    wire    [31:0]  rkd_value;
    //csr changed exp12
    wire EXE_csr_we;
    wire EXE_csr_re;
    wire [13:0] EXE_csr_num;
    wire [31:0] EXE_csr_wvalue;
    wire [31:0] EXE_csr_rvalue;
    wire [31:0] EXE_csr_wmask;
    wire [5:0] EXE_ex_type;
    wire inst_ertn;


//change exp12
    assign{ EXE_csr_we, EXE_csr_re, EXE_csr_num, EXE_csr_wmask, EXE_csr_wvalue, EXE_csr_rvalue,//112bit
            inst_ertn, EXE_ex_type,//change exp12
            alu_op, alu_src1, alu_src2, 
            res_from_mem, gr_we, mem_we, dest,
            rkd_value,
            EXE_pc, EXE_inst} = ID_to_EXE_bus_valid;

    assign EXE_ex = (|EXE_ex_type) & EXE_valid; 
    assign EXE_ertn = inst_ertn & EXE_valid;
    assign EXE_to_csr_bus = { EXE_csr_we & EXE_valid, EXE_ertn, EXE_csr_num };
//change end

    wire [31:0] alu_result;
    wire [31:0] exe_result;//exp10 added
    alu u_alu(
     .alu_op     (alu_op    ),
     .alu_src1   (alu_src1  ),//修改名称
     .alu_src2   (alu_src2  ),
     .alu_result (alu_result)
     ); 
     
//store by dxl start
    wire inst_st_w;
    wire inst_st_h;
    wire inst_st_b;
    assign inst_st_w = EXE_inst[31:22] == 10'b0010100110;
    assign inst_st_h = EXE_inst[31:22] == 10'b0010100101;
    assign inst_st_b = EXE_inst[31:22] == 10'b0010100100;
    
    wire [1:0] vaddr;
    assign vaddr = alu_result[1:0];
    
    wire [3:0] store_we;//store写使能
    assign store_we =   {4{inst_st_w}} & 4'b1111 |
                        {4{inst_st_h}} & {{2{vaddr[1]}},{2{~vaddr[1]}}} |
                        {4{inst_st_b}} & {{vaddr[1] & vaddr[0]},{vaddr[1] & ~vaddr[0]},{~vaddr[1] & vaddr[0]},{~vaddr[1] & ~vaddr[0]}};
    
    assign data_sram_en = ~(wb_ex | MEM_ex | EXE_ex | ertn_flush | MEM_ertn | EXE_ertn);//change exp12
    assign data_sram_we    = {4{mem_we}} & store_we;
    assign data_sram_addr  = {alu_result[31:2],2'b00};//
    assign data_sram_wdata =    {32{inst_st_w}} & rkd_value |
                                {32{inst_st_h}} & {2{rkd_value[15:0]}} |
                                {32{inst_st_b}} & {4{rkd_value[7:0]}};//考虑写使能
//store by dxl end


//exp10 除法添加    
//by wjr start
//有符号除
    //flag信号表示是否已给除法器发送了操作数，确保除法器不会重复接收到同一个操作数
    always @(posedge  clk) begin
        if (~resetn) begin
            div_src1_flag <= 1'b0;
        end
        else if (div_src1_valid & div_src1_ready) begin
            div_src1_flag <= 1'b1;//除法器已经接收了第一个操作数
        end
        else if (EXE_ready_go & MEM_allow_in) begin
            div_src1_flag <= 1'b0;//可以重新准备发送操作数，用于下一次除法操作
        end
    end
    assign div_src1_valid = (alu_op[15] | alu_op[17]) & EXE_valid & ~div_src1_flag;//请求操作数信号。需要执行除法操作且操作数未发送时，置1
    
    always @(posedge  clk) begin
        if (~resetn) begin
            div_src2_flag <= 1'b0;
        end
        else if (div_src2_valid & div_src2_ready) begin
            div_src2_flag <= 1'b1;
        end
        else if (EXE_ready_go & MEM_allow_in) begin
            div_src2_flag <= 1'b0;
        end
    end
    assign div_src2_valid = (alu_op[15] | alu_op[17]) & EXE_valid & ~div_src2_flag;
    
    assign div_src1 = alu_src1;
    assign div_src2 = alu_src2;
    mydiv u_mydiv (
        .aclk                   (clk),
        .s_axis_dividend_tdata  (div_src1),
        .s_axis_dividend_tready (div_src1_ready),
        .s_axis_dividend_tvalid (div_src1_valid),
        .s_axis_divisor_tdata   (div_src2),
        .s_axis_divisor_tready  (div_src2_ready),
        .s_axis_divisor_tvalid  (div_src2_valid),
        .m_axis_dout_tdata      (div_res),
        .m_axis_dout_tvalid     (div_out_valid)
    );
    assign {div_res_remainder, div_res_quotient} = div_res;//exp10 错误2

//无符号除    
    always @(posedge  clk) begin
        if (~resetn) begin
            divu_src1_flag <= 1'b0;
        end
        else if (divu_src1_valid & divu_src1_ready) begin
            divu_src1_flag <= 1'b1;
        end
        else if (EXE_ready_go & MEM_allow_in) begin
            divu_src1_flag <= 1'b0;
        end
    end
    assign divu_src1_valid = (alu_op[16] | alu_op[18]) & EXE_valid & ~divu_src1_flag;
    
    always @(posedge  clk) begin
        if (~resetn) begin
            divu_src2_flag <= 1'b0;
        end
        else if (divu_src2_valid & divu_src2_ready) begin
            divu_src2_flag <= 1'b1;
        end
        else if (EXE_ready_go & MEM_allow_in) begin
            divu_src2_flag <= 1'b0;
        end
    end
    assign divu_src2_valid = (alu_op[16] | alu_op[18]) & EXE_valid & ~divu_src2_flag;
    
    assign divu_src1 = alu_src1;
    assign divu_src2 = alu_src2;
    mydivu u_mydivu (
        .aclk                   (clk),
        .s_axis_dividend_tdata  (divu_src1),
        .s_axis_dividend_tready (diuv_src1_ready),
        .s_axis_dividend_tvalid (divu_src1_valid),
        .s_axis_divisor_tdata   (divu_src2),
        .s_axis_divisor_tready  (divu_src2_ready),
        .s_axis_divisor_tvalid  (divu_src2_valid),
        .m_axis_dout_tdata      (divu_res),
        .m_axis_dout_tvalid     (divu_out_valid)
    );
    assign {divu_res_remainder, divu_res_quotient} = divu_res;
    
    assign exe_result = EXE_csr_re ? EXE_csr_rvalue://change exp12
                        alu_op[15] ? div_res_remainder :
                        alu_op[17] ? div_res_quotient :
                        alu_op[16] ? divu_res_remainder :
                        alu_op[18] ? divu_res_quotient :
                                     alu_result;
    
//by wjr end

//change exp12
assign EXE_to_MEM_bus ={EXE_csr_we, EXE_csr_num, EXE_csr_wmask, EXE_csr_wvalue,//112bit
                        inst_ertn, EXE_ex_type,
                        exe_result,
                        res_from_mem, gr_we, dest, 
                        EXE_pc, EXE_inst};
//相较于exp7改动
    wire EXE_write;
    assign EXE_write = EXE_valid & gr_we;
    wire EXE_load;
    assign EXE_load = EXE_valid & res_from_mem;
    assign EXE_wr_bus = {EXE_write,EXE_load,dest, exe_result};//alu_result 改为 exe_result 
endmodule
