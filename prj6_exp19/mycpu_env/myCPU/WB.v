//exc types    
    `define TYPE_SYS    0//系统调用例外
    `define TYPE_ADEF   1//取指地址错例外
    `define TYPE_ALE    2//地址非对齐例外
    `define TYPE_BRK    3//断点例外
    `define TYPE_INE    4//指令不存在例外
    `define TYPE_INT    5//中断
    //exp19 add 
    `define TYPE_ADEM    6//访存指令地址错例外
    `define TYPE_TLBRF   7//TLB重填例外 TLBR_fetch,from IF
    `define TYPE_PIL     8//load操作页无效例外
    `define TYPE_PIS     9//store操作页无效例外
    `define TYPE_PIF     10//取指操作页无效例外
    `define TYPE_PME     11//页修改例外
    `define TYPE_PPIF    12//页特权等级不合规例外 PPI_fetch,from IF
    `define TYPE_TLBRM   13//TLB重填例外 TLBR_memory,from EXE
    `define TYPE_PPIM    14//页特权等级不合规例外 PPI_memory,from EXE
    
//ecodes
    `define EXC_ECODE_SYS   6'h0B
    `define EXC_ECODE_INT   6'h00
    `define EXC_ECODE_ADE   6'h08
    `define EXC_ECODE_ALE   6'h09
    `define EXC_ECODE_BRK   6'h0C
    `define EXC_ECODE_INE   6'h0D
    //exp19
    `define EXC_ECODE_TLBR  6'h3F
    `define EXC_ECODE_PIL   6'h01
    `define EXC_ECODE_PIS   6'h02
    `define EXC_ECODE_PIF   6'h03
    `define EXC_ECODE_PME   6'h04
    `define EXC_ECODE_PPI   6'h07
    
//esubcodes
    `define EXC_ESUBCODE_ADEF   9'h000
    //exp19
    `define EXC_ESUBCODE_ADEM   9'h001

module WB(
    input  wire        clk,
    input  wire        resetn,
    //from MEM
    output wire WB_allow_in,
    input wire MEM_to_WB_valid,
    input wire [206:0] MEM_to_WB_bus,//exp19 add 9bit
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
    output wire [16:0] WB_to_csr_bus,
    output wire [31:0] wb_badvaddr,

    output wire refetch,
    output wire [3:0] r_index,
    output wire tlbrd_we,
    input wire [3:0] csr_tlbidx_index,
    output wire tlbwr_we,
    output wire tlbfill_we,
    output wire [3:0] w_index,
    output wire tlb_we,//tlbwr_we | tlbfill_we
    output wire tlb_hit,
    output wire [3:0] tlb_hit_index,
    output wire tlbsrch_we,
    
    output wire [14:0] WB_ex_type,//exp19 add 9bit
    input wire flush
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

    reg [206:0] MEM_to_WB_bus_valid;//exp19 add 9bit
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_to_WB_bus_valid <= 207'b0;
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


    wire wb_refetch;
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire wb_tlbhit;
    wire [3:0] wb_tlbhit_index;
    assign {wb_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, wb_tlbhit, wb_tlbhit_index,//exp18 add 10bit
            WB_csr_we, WB_csr_num, WB_csr_wmask, WB_csr_wvalue, inst_ertn, WB_ex_type,//exp19 WB_ex_type add 9bit
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
    assign wb_ecode = WB_ex_type[`TYPE_INT ]  ? `EXC_ECODE_INT : //中断
                       //取指IF阶段检测出的例外
                       WB_ex_type[`TYPE_ADEF]  ? `EXC_ECODE_ADE : 
                       WB_ex_type[`TYPE_TLBRF] ? `EXC_ECODE_TLBR : 
                       WB_ex_type[`TYPE_PIF ]  ? `EXC_ECODE_PIF : 
                       WB_ex_type[`TYPE_PPIF]  ? `EXC_ECODE_PPI : 
                       //译码ID阶段检测出的例外
                       WB_ex_type[`TYPE_BRK ]  ? `EXC_ECODE_BRK : 
                       WB_ex_type[`TYPE_INE ]  ? `EXC_ECODE_INE : 
                       WB_ex_type[`TYPE_ALE ]  ? `EXC_ECODE_ALE : 
                       WB_ex_type[`TYPE_SYS ]  ? `EXC_ECODE_SYS : 
                       //执行EXE阶段检测出的例外
                       WB_ex_type[`TYPE_ADEM]  ? `EXC_ECODE_ADE : 
                       WB_ex_type[`TYPE_TLBRM] ? `EXC_ECODE_TLBR : 
                       WB_ex_type[`TYPE_PIL ]  ? `EXC_ECODE_PIL : 
                       WB_ex_type[`TYPE_PIS ]  ? `EXC_ECODE_PIS : 
                       WB_ex_type[`TYPE_PPIM]  ? `EXC_ECODE_PPI : 
                       WB_ex_type[`TYPE_PME ]  ? `EXC_ECODE_PME : 
                       6'b0;//exp19 change   error3 根据例外的优先级来设置wb_ecode
                      
    assign wb_esubcode = {9{WB_ex_type[`TYPE_ADEF]}} & `EXC_ESUBCODE_ADEF|
                          //exp19 add
                          {9{WB_ex_type[`TYPE_ADEM]}} & `EXC_ESUBCODE_ADEM;
    
    assign wb_badvaddr = final_result;//用于向csr模块传递出错的访存"虚"地址
    //change exp13 end
    
    assign ertn_flush = inst_ertn & WB_valid;
    assign WB_to_csr_bus = {WB_csr_we & WB_valid, ertn_flush, inst_tlbsrch & WB_valid, WB_csr_num};

    assign csr_wmask = WB_csr_wmask;
    assign csr_we    = WB_csr_we & WB_valid & ~wb_ex;
    assign csr_num  = WB_csr_num;
    assign csr_wvalue  = WB_csr_wvalue;

//exp19 change  
    reg flush_reg;    
    always @(posedge clk) begin
        if (~resetn) begin
            flush_reg <= 1'b0;
        end
        else if (flush) begin
            flush_reg <= 1'b1;
        end
        else if (MEM_to_WB_valid & WB_allow_in) begin
            flush_reg <= 1'b0;
        end
    end

    wire is_ertn_exc;
//    assign is_ertn_exc = wb_ex | ertn_flush | exc_reg | ertn_reg;
     assign is_ertn_exc = flush | flush_reg;//exp19 change

    //tlb wb
    reg [3:0] index_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            index_reg <= 4'b0;
        end 
        else if (index_reg == 4'b1111) begin
            index_reg <= 4'b0;
        end 
        else begin
            index_reg <= index_reg + 4'b1;
        end
    end

    assign tlbrd_we = inst_tlbrd;
    assign tlbwr_we = inst_tlbwr;
    assign tlbsrch_we = inst_tlbsrch;
    assign tlbfill_we = inst_tlbfill;
    assign tlb_hit = wb_tlbhit;
    assign tlb_hit_index = wb_tlbhit_index;
    assign r_index = csr_tlbidx_index;
    assign w_index = tlbwr_we ? csr_tlbidx_index : index_reg;
    assign tlb_we = tlbwr_we | tlbfill_we;
    assign refetch = wb_refetch & WB_valid;

endmodule