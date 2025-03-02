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

module MEM(
    input  wire         clk,
    input  wire         resetn,
    //from EXE
    output wire         MEM_allow_in,
    input  wire         EXE_to_MEM_valid,
    input  wire [209:0] EXE_to_MEM_bus,//exp19 add 9bit
    //to WB
    output wire         MEM_to_WB_valid,
    input  wire         WB_allow_in,
    output wire [206:0] MEM_to_WB_bus,  //exp19 add 9bit
    //to data sram interface
    input  wire [ 31:0] data_sram_rdata,
    input  wire         data_sram_data_ok,
    output wire [ 38:0] MEM_wr_bus,

    //csr
    output wire MEM_ex,
    output wire MEM_ertn,
    output wire [16:0] MEM_to_csr_bus,
    output wire ldst_cancel,
    input wire wb_ex,
    input wire ertn_flush,
    
    input wire flush
);

    //load inst by swt start
    assign inst_ld_b  = MEM_inst[31:22] == 10'b0010100000;
    assign inst_ld_h  = MEM_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = MEM_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = MEM_inst[31:22] == 10'b0010101001;
    assign inst_ld_w  = MEM_inst[31:22] == 10'b0010100010;
    assign is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
    //by swt end

    //inside MEM
    reg MEM_valid;
    wire MEM_ready_go;
    wire [31:0] MEM_inst;
    wire [31:0] MEM_pc;

    assign MEM_ready_go = (is_load | mem_we) ?
        (|MEM_ex_type) | ls_cancel | data_sram_data_ok : 1'b1;
    assign MEM_to_WB_valid = MEM_ready_go & MEM_valid & ~is_ertn_exc;
    assign MEM_allow_in = MEM_ready_go & WB_allow_in | ~MEM_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_valid <= 1'b0;
        end
        else if(MEM_allow_in)begin
            MEM_valid <= EXE_to_MEM_valid;
        end
    end  
   
    reg [209:0] EXE_to_MEM_bus_valid;//exp19 add 9bit
    always @(posedge clk)begin
        if(~resetn)begin
            EXE_to_MEM_bus_valid <= 210'b0;
        end
        else if(EXE_to_MEM_valid & MEM_allow_in)begin
            EXE_to_MEM_bus_valid <= EXE_to_MEM_bus;
        end
    end
    
    //bus
    wire [31:0] alu_result;
    wire        res_from_mem;
    wire        gr_we;
    wire [ 4:0] dest;
    wire        MEM_csr_we;
    wire [13:0] MEM_csr_num;
    wire [31:0] MEM_csr_wmask;
    wire [31:0] MEM_csr_wvalue;
    wire        inst_ertn;
    wire [14:0] EXE_ex_type;//exp19 add 9bit
    wire [14:0] MEM_ex_type;//exp19 add 9bit
    wire        ls_cancel;
    wire        mem_we;

    wire mem_refetch;
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire mem_tlbhit;
    wire [3:0] mem_tlbhit_index;

    assign {mem_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, mem_tlbhit, mem_tlbhit_index,//exp18 add 10bit
            MEM_csr_we, MEM_csr_num, MEM_csr_wmask, MEM_csr_wvalue,
            inst_ertn, EXE_ex_type,//exp19 EXE_ex_type add 9bit
            alu_result,
            res_from_mem, gr_we, dest, 
            MEM_pc, MEM_inst, ls_cancel, mem_we} = EXE_to_MEM_bus_valid;
    assign MEM_ex_type = EXE_ex_type;

    //add exp14 control
    assign ldst_cancel = MEM_ex | MEM_ertn | (mem_refetch & MEM_valid);

//exp19 change    
    reg flush_reg;
    always @(posedge clk ) begin
        if(~resetn)begin
            flush_reg <= 1'b0;
        end
        else if (flush) begin
            flush_reg <= 1'b1;
        end
        else if (EXE_to_MEM_valid & MEM_allow_in)begin
            flush_reg <= 1'b0;
        end
    end                     

//    assign is_ertn_exc = wb_ex | ertn_flush | exc_reg | ertn_reg;
    assign is_ertn_exc = flush | flush_reg;//exp19 change
    
    //load by swt start
    wire    [ 1:0]  vaddr;
    wire    [31:0]  word;
    wire    [15:0]  half;
    wire    [ 7:0]  byte;
    wire    [31:0]  half_xtnd;
    wire    [31:0]  byte_xtnd;
    wire    [31:0]  mem_ld_result;
    wire    [31:0]  final_result;
    
    assign  vaddr = alu_result[1:0];
    assign  word  = data_sram_rdata;
    assign  half  = vaddr[1] ? word[31:16] : word[15:0];
    assign  byte  = vaddr[1] & vaddr[0] ? word[31:24] :
                    vaddr[1] &~vaddr[0] ? word[23:16] :
                   ~vaddr[1] & vaddr[0] ? word[15: 8] :
                                          word[ 7: 0] ;
    assign  half_xtnd = {32{inst_ld_h}} & {{16{half[15]}}, half} | {32{inst_ld_hu}} & {16'b0, half};
    assign  byte_xtnd = {32{inst_ld_b}} & {{24{byte[ 7]}}, byte} | {32{inst_ld_bu}} & {24'b0, byte};

    assign  mem_ld_result = {32{inst_ld_b | inst_ld_bu}} & byte_xtnd |
                            {32{inst_ld_h | inst_ld_hu}} & half_xtnd |
                            {32{inst_ld_w             }} & word      ;

    assign final_result = MEM_ex_type[`TYPE_ALE] |  //change exp13 地址非对齐例外，要给寄存器写访存出错的虚地址
                           MEM_ex_type[`TYPE_ADEM] | MEM_ex_type[`TYPE_TLBRM] | MEM_ex_type[`TYPE_PPIM] | MEM_ex_type[`TYPE_PIL] | MEM_ex_type[`TYPE_PIS] | MEM_ex_type[`TYPE_PME] //exp19 add
                                        ?    alu_result :
                           res_from_mem ? mem_ld_result : alu_result;
    //by swt end

    //bus
    assign MEM_to_WB_bus = {mem_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, mem_tlbhit, mem_tlbhit_index,//exp18 add 10bit
                            MEM_csr_we, MEM_csr_num, MEM_csr_wmask, MEM_csr_wvalue, inst_ertn, MEM_ex_type,//exp19 MEM_ex_type add 9bit
                            final_result,
                            gr_we, dest,
                            MEM_pc, MEM_inst};
    assign MEM_write = gr_we & MEM_valid;
    wire MEM_load;
    assign MEM_load = is_load & MEM_valid;
    assign MEM_wr_bus = {MEM_write,MEM_load, dest, final_result};


//change exp12
    assign MEM_ex = (|MEM_ex_type) & MEM_valid;
    assign MEM_to_csr_bus = {MEM_csr_we & MEM_valid, MEM_ertn, inst_tlbsrch & MEM_valid, MEM_csr_num};
    assign MEM_ertn = MEM_valid & inst_ertn;

endmodule