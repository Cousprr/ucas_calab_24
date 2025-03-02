    `define CSR_CRMD    14'h000
    `define CSR_PRMD    14'h001
    `define CSR_ESTAT   14'h005
    `define CSR_ERA     14'h006
    `define CSR_EENTRY  14'h00c
    `define CSR_SAVE0   14'h030
    `define CSR_SAVE1   14'h031
    `define CSR_SAVE2   14'h032
    `define CSR_SAVE3   14'h033
    `define CSR_MASK_CRMD   32'h0000_0007   // only plv, ie
    `define CSR_MASK_PRMD   32'h0000_0007
    `define CSR_MASK_ESTAT  32'h0000_0003   // only SIS RW
    `define CSR_MASK_ERA    32'hffff_ffff
    `define CSR_MASK_EENTRY 32'hffff_ffc0
    `define CSR_MASK_SAVE   32'hffff_ffff

//exp13 csr
    `define CSR_ECFG    14'h004
    `define CSR_BADV    14'h007
    `define CSR_TID     14'h040
    `define CSR_TCFG    14'h041
    `define CSR_TVAL    14'h042
    `define CSR_TICLR   14'h044
    //exp19
    `define CSR_DMW0    14'h180
    `define CSR_DMW1    14'h181

    `define CSR_MASK_ECFG   32'h0000_1fff
    `define CSR_MASK_TID    32'hffff_ffff
    `define CSR_MASK_TCFG   32'hffff_ffff
    `define CSR_MASK_TICLR  32'h0000_0001
    `define CSR_MASK_BADV   32'hffff_ffff
    //exp19
    `define CSR_MASK_DMW    32'hee00_0039//只有[31:29] [27:25] [5:3] [0]位可写

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

    //tlb
    `define CSR_TLBIDX          14'h010
    `define CSR_TLBEHI          14'h011
    `define CSR_TLBELO0         14'h012
    `define CSR_TLBELO1         14'h013
    `define CSR_ASID            14'h018
    `define CSR_TLBRENTRY       14'h088
    `define CSR_MASK_TLBIDX     32'hbf00_000f
    `define CSR_MASK_TLBEHI     32'hffff_e000
    `define CSR_MASK_TLBELO     32'hffff_ff7f
    `define CSR_MASK_ASID       32'h0000_03ff
    `define CSR_MASK_TLBRENTRY  32'hffff_ffc0


module ID(
    input  wire        clk,
    input  wire        resetn,
    //from IF
    input wire IF_to_ID_valid,//IF正常工作，输出正确结果
    output wire ID_allow_in,//ID正常读入数据
    input wire [78:0] IF_to_ID_bus,//pc & instruction  //exp19 add 9bit
    output wire [33:0] ID_to_IF_bus,//br_stall & br_taken & br_target
    //to EXE
    input wire EXE_allow_in,
    output wire ID_to_EXE_valid,
    output wire [359:0] ID_to_EXE_bus,//exp19 add 9bit
    //from WB
    input wire [37:0] WB_to_ID_bus,
    //判断阻塞
    input wire [38:0]EXE_wr_bus,
    input wire [38:0]MEM_wr_bus,
    //csr
    input wire [31:0] csr_rvalue,
    output wire [13:0] csr_raddr,
    input wire [16:0] EXE_to_csr_bus,
    input wire [16:0] MEM_to_csr_bus,
    input wire [16:0] WB_to_csr_bus,
    input wire wb_ex,
    input wire csr_has_int,

    input wire flush

    );
   //inside ID
    reg ID_valid;//ID工作有效
    wire ID_ready_go;//ID工作有效，可进入下个阶段
    wire [31:0] ID_inst;
    wire [31:0] ID_pc;
    wire br_taken;
    wire br_stall;
    wire [31:0] br_target;
    //处理控制
    wire br_taken_cancel;
    //assign ID_ready_go = 1'b1;

    wire [31:0] rj_value;
    wire [31:0] rkd_value;

    //提到前面
    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;
    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;
    wire        inst_pcaddu12i;
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_b;
    wire        inst_st_h;
    wire        is_b;
    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;

    wire inst_syscall;
    wire inst_csrrd;
    wire inst_csrwr;
    wire inst_csrxchg;
    wire inst_ertn;

    wire inst_break;
    wire inst_rdcntid_w;
    wire inst_rdcntvl_w;
    wire inst_rdcntvh_w;

    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire inst_invtlb;

    wire id_refetch;
    wire [4:0] invtlb_op;
    assign invtlb_op = rd;
    //阻塞
    wire MEM_write;
    wire [4:0]MEM_dest;
    wire [31:0]MEM_final_result;
    wire EXE_write;
    wire EXE_load;
    wire MEM_load;
    wire [31:0]EXE_alu_result;
    wire [4:0]EXE_dest;
    wire addr1_valid;
    wire addr2_valid;

    assign{EXE_write,EXE_load,EXE_dest, EXE_alu_result} = EXE_wr_bus;
    assign{MEM_write, MEM_load, MEM_dest, MEM_final_result}= MEM_wr_bus;

    //中断和异常标志   exp19 改位宽
    wire [14:0] ID_exc_type;//exp19 add 9bit
    wire [14:0] IF_exc_type;//exp19 add 9bit
    //assign ID_exc_type = {5'b0, inst_syscall};

//exp13 add start
    wire inst_all;
    assign inst_all = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                    inst_nor | inst_and | inst_or | inst_xor | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w |
                    inst_srl_w | inst_sra_w | inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_pcaddu12i | inst_ld_w |
                    inst_st_w | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_lu12i_w | inst_mul_w | inst_mulh_w|
                    inst_mulh_wu | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu |
                    inst_st_b | inst_st_h | inst_syscall | inst_csrrd | inst_csrwr | inst_csrxchg | inst_ertn | inst_break |
                    inst_rdcntid_w | inst_rdcntvl_w | inst_rdcntvh_w | inst_mod_w | inst_mod_wu | inst_div_w | inst_div_wu |
                    inst_invtlb | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_tlbsrch;

    //ID_exc_type的每一位分别代表一种中断和异常
    assign  ID_exc_type[`TYPE_SYS] = inst_syscall;
    assign  ID_exc_type[`TYPE_ADEF] = IF_exc_type[`TYPE_ADEF];
    assign  ID_exc_type[`TYPE_ALE] = 1'b0;
    assign  ID_exc_type[`TYPE_BRK] = inst_break;
    assign  ID_exc_type[`TYPE_INE] = ~(ID_exc_type[`TYPE_ADEF]) & (~inst_all | (inst_invtlb && (invtlb_op > 5'b00110)));//不发生取指地址错的前提下，不是目前已实现的任意一条指令
    assign  ID_exc_type[`TYPE_INT] = csr_has_int;//中断
//exp13 add end
//exp19 add 9bit
    assign ID_exc_type[`TYPE_ADEM]  = IF_exc_type[`TYPE_ADEM];
    assign ID_exc_type[`TYPE_TLBRF] = IF_exc_type[`TYPE_TLBRF];
    assign ID_exc_type[`TYPE_TLBRM] = IF_exc_type[`TYPE_TLBRM];
    assign ID_exc_type[`TYPE_PIL]   = IF_exc_type[`TYPE_PIL];
    assign ID_exc_type[`TYPE_PIS]   = IF_exc_type[`TYPE_PIS];
    assign ID_exc_type[`TYPE_PIF]   = IF_exc_type[`TYPE_PIF];
    assign ID_exc_type[`TYPE_PME]   = IF_exc_type[`TYPE_PME];
    assign ID_exc_type[`TYPE_PPIF]  = IF_exc_type[`TYPE_PPIF];
    assign ID_exc_type[`TYPE_PPIM]  = IF_exc_type[`TYPE_PPIM];


     assign addr1_valid =   ~ID_exc_type[`TYPE_INE] & ~(inst_b | inst_bl | inst_csrrd | inst_csrwr | inst_syscall | inst_ertn | 
                             inst_break | inst_rdcntid_w | inst_rdcntvh_w | inst_rdcntvl_w);//change exp13 取反，所以需要确保不是"指令不存在"例外
                            /*inst_add_w | inst_sub_w | inst_slt | inst_addi_w | inst_sltu | 
                            inst_nor | inst_and | inst_or | inst_xor | inst_srli_w |
                            inst_slli_w | inst_srai_w |
                            inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w |
                            inst_bne  | inst_beq | inst_jirl |
                            inst_slti | inst_sltui | inst_andi | inst_ori |inst_xori |
                            inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                            inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu | 
                            inst_st_b | inst_st_h |
                            inst_blt | inst_bge | inst_bltu | inst_bgeu |
                            inst_csrxchg;//change exp12
                            */
    assign addr2_valid =    inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | 
                            inst_or | inst_nor | inst_xor | inst_st_w | inst_beq | inst_bne |
                            inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu |
                            inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu | 
                            inst_st_b | inst_st_h |
                            inst_blt | inst_bge | inst_bltu | inst_bgeu|
                            inst_csrwr | inst_csrxchg;//change exp12
//change exp12
    wire ID_csr_we;
    wire ID_csr_re;
    wire [13:0] ID_csr_num;
    wire [13:0] ID_csr_raddr;
    wire [31:0] ID_csr_wvalue;
    wire [31:0] ID_csr_rvalue;
    wire [31:0] ID_csr_wmask;
    wire [31:0] csr_mask;
    wire EXE_csr_we;
    wire EXE_ertn;
    wire [13:0] EXE_csr_num;
    wire MEM_csr_we;
    wire MEM_ertn;
    wire [13:0] MEM_csr_num;
    wire WB_csr_we;
    wire ertn_flush;
    wire [13:0] WB_csr_num;

    wire EXE_tlbsrch;
    wire MEM_tlbsrch;
    wire WB_tlbsrch;

    assign {EXE_csr_we, EXE_ertn, EXE_tlbsrch, EXE_csr_num} = EXE_to_csr_bus;
    assign {MEM_csr_we, MEM_ertn, MEM_tlbsrch, MEM_csr_num} = MEM_to_csr_bus;
    assign {WB_csr_we, ertn_flush, WB_tlbsrch, WB_csr_num} = WB_to_csr_bus;
    //todo:
    wire conflict_csr_write;
    wire conflict_csr_ertn;
    wire conflict_csr_tlbsrch;
    assign conflict_csr_write = EXE_csr_we & (ID_csr_raddr == EXE_csr_num) & (|EXE_csr_num)|
                                MEM_csr_we & (ID_csr_raddr == MEM_csr_num) & (|MEM_csr_num)|
                                WB_csr_we  & (ID_csr_raddr == WB_csr_num) & (|WB_csr_num);
    
    assign conflict_csr_ertn = (EXE_ertn)&(EXE_csr_num==`CSR_ERA|EXE_csr_num==`CSR_PRMD|csr_raddr==`CSR_CRMD)|
                                (MEM_ertn)&(MEM_csr_num==`CSR_ERA|MEM_csr_num==`CSR_PRMD|csr_raddr==`CSR_CRMD)|
                                (ertn_flush)&(WB_csr_num==`CSR_ERA|WB_csr_num==`CSR_PRMD|csr_raddr==`CSR_CRMD);
    
    assign conflict_csr_tlbsrch = EXE_tlbsrch & (csr_raddr == `CSR_TLBIDX) |
                                  MEM_tlbsrch & (csr_raddr == `CSR_TLBIDX) |
                                  WB_tlbsrch  & (csr_raddr == `CSR_TLBIDX) |
                                  inst_tlbsrch & (EXE_csr_num ==`CSR_ASID | EXE_csr_num == `CSR_TLBEHI) |
                                  inst_tlbsrch & (MEM_csr_num ==`CSR_ASID | MEM_csr_num == `CSR_TLBEHI);
    
    wire conflict_csr;
    assign conflict_csr = ID_csr_re  & (conflict_csr_write | conflict_csr_ertn | conflict_csr_tlbsrch);

//change end

    wire conflict_EXE; 
    assign conflict_EXE = EXE_load & (|EXE_dest) & ((EXE_dest == rf_raddr1) & addr1_valid | (EXE_dest == rf_raddr2) & addr2_valid);
    wire conflict_MEM;
    assign conflict_MEM = MEM_load & (|MEM_dest) & ((MEM_dest == rf_raddr1) & addr1_valid | (MEM_dest == rf_raddr2) & addr2_valid);
    assign ID_ready_go = ~(conflict_EXE | conflict_csr | conflict_MEM);//change exp12
    
    assign ID_allow_in = ID_ready_go & EXE_allow_in | ~ID_valid;

//exp15
//exp19 change
    reg flush_reg;  
    always @(posedge clk ) begin
        if(~resetn)begin
            flush_reg <= 1'b0;
        end
        else if (flush) begin
            flush_reg <= 1'b1;
        end
        else if (IF_to_ID_valid & ID_allow_in)begin
            flush_reg <= 1'b0;
        end
    end                     

    wire is_ertn_exc;
//    assign is_ertn_exc = (wb_ex | ertn_flush | ex_reg | ertn_reg);
    assign is_ertn_exc = flush | flush_reg;//exp19 change    

    assign ID_to_EXE_valid = ID_ready_go & ID_valid & ~is_ertn_exc;

    always @(posedge clk)begin
        if(~resetn)begin
            ID_valid <= 1'b0;
        end
        else if(ID_allow_in) begin
           ID_valid <= IF_to_ID_valid;        
        end
    end     
   
    reg [78:0] IF_to_ID_bus_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            IF_to_ID_bus_valid <= 79'b0;
        end
        else if(IF_to_ID_valid & ID_allow_in)begin
            IF_to_ID_bus_valid <= IF_to_ID_bus;
        end
    end
    //bus
    assign {IF_exc_type, ID_pc , ID_inst} = IF_to_ID_bus_valid;//exp19 IF_exc_type add 9bit

//译码
wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;



wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;


wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [18:0] alu_op;
wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [4: 0] dest;

wire [31:0] imm;
wire [31:0] br_offs;

wire [31:0] jirl_offs;
wire        src_reg_is_rd;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;


assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];

assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];

assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];
assign is_b = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_bl | inst_jirl | inst_b;
//by dxl start
assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ID_inst[25];
//by dxl end

//by swt start
assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
//by swt end

//by wjr start
assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
//by wjr end

//exp11 by wjr start
    assign inst_blt    = op_31_26_d[6'h18];
    assign inst_bge    = op_31_26_d[6'h19];
    assign inst_bltu   = op_31_26_d[6'h1a];
    assign inst_bgeu   = op_31_26_d[6'h1b];
//exp11 by wjr end

//exp11 by swt start
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
//exp11 by swt end

//exp11 by dxl start
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
//exp11 by dxl end


//change exp12
assign inst_syscall= op_31_26_d[6'b000000] & op_25_22_d[4'b0000] & op_21_20_d[2'b10] & op_19_15_d[5'b10110];
assign inst_csrrd  = (ID_inst[31:24]==8'b00000100) & (rj==5'b00000);
assign inst_csrwr  = (ID_inst[31:24]==8'b00000100) & (rj==5'b00001);
assign inst_csrxchg= (ID_inst[31:24]==8'b00000100) & (rj[4:1]!=4'b0);
assign inst_ertn   = ID_inst[31:10]==22'b00000_11001_00100_00011_10;
//change exp12 end

//change exp13 start
    assign inst_break     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b10] & op_19_15_d[5'h14];
    assign inst_rdcntid_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rd == 5'h00;
    assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h18 & rj == 5'h00;
    assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'b00] & op_19_15_d[5'h00] & rk == 5'h19 & rj == 5'h00;
//change exp13 end

//exp18 start
assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0a;
assign inst_tlbrd   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0b;
assign inst_tlbwr   = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0c;
assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & rk == 5'h0d;
assign inst_invtlb  = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];
assign id_refetch = inst_tlbfill | inst_tlbwr | inst_tlbrd;
//exp18 end

assign alu_op[ 0] = inst_add_w | inst_addi_w 
                    | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu
                    | inst_st_w | inst_st_b | inst_st_h //stb sth
                    | inst_jirl | inst_bl | inst_pcaddu12i;//pcaddu12i
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;//slti
assign alu_op[ 3] = inst_sltu | inst_sltui;//sltui
assign alu_op[ 4] = inst_and | inst_andi;//andi
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;//ori
assign alu_op[ 7] = inst_xor | inst_xori;//xori
assign alu_op[ 8] = inst_slli_w | inst_sll_w;//sll
assign alu_op[ 9] = inst_srli_w | inst_srl_w;//srl
assign alu_op[10] = inst_srai_w | inst_sra_w;//sra
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;//div.w
assign alu_op[16] = inst_div_wu;//div.wu
assign alu_op[17] = inst_mod_w;//mod.w
assign alu_op[18] = inst_mod_wu;//mod.wu

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h;//stb sth
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;//pcaddu12i
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

//by dxl start
wire need_ZeroExtend;
assign need_ZeroExtend = inst_andi | inst_ori | inst_xori;
//by dxl end

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             need_ZeroExtend ? {20'b0, i12[11:0]}   ://andi ori xori
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;//slti sltui

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | 
                        inst_blt  | inst_bge | inst_bltu | inst_bgeu
                        | inst_st_b  | inst_st_h |//stb sth
                        inst_csrwr | inst_csrxchg ;//change exp12

assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu  |
                       inst_ld_hu  |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_slti   |//slti
                       inst_sltui  |//sltui
                       inst_andi   |//
                       inst_ori    |//
                       inst_xori   |//
                       inst_pcaddu12i;//

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu
                        & ~inst_st_b & ~inst_st_h //stb sth
                        & ~inst_syscall & ~inst_ertn //change exp12
                        & ~inst_break & ~ID_exc_type[`TYPE_INE]//change exp13
                        & ~inst_tlbrd & ~inst_tlbwr & ~inst_tlbfill & ~inst_tlbsrch & ~inst_invtlb;//change exp18
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;//stb sth
assign dest          = dst_is_r1 ? 5'd1 : inst_rdcntid_w ? rj : rd;//change exp13

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

//WB to ID
assign {rf_we, rf_waddr, rf_wdata} = WB_to_ID_bus;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );
wire EXE_bypass_1;
wire EXE_bypass_2;
wire test;
assign test = (|EXE_dest) & (EXE_dest == rf_raddr1);
assign EXE_bypass_1 = EXE_write & test & addr1_valid;
//assign EXE_bypass_1 = EXE_write & (EXE_dest == rf_raddr2) & addr2_valid;
assign EXE_bypass_2 =(|EXE_dest) &  EXE_write & (EXE_dest == rf_raddr2) & addr2_valid;
wire MEM_bypass_1;
wire MEM_bypass_2;
assign MEM_bypass_1 =(|MEM_dest) &  MEM_write & (MEM_dest == rf_raddr1) & addr1_valid;
assign MEM_bypass_2 = (|MEM_dest) & MEM_write & (MEM_dest == rf_raddr2) & addr2_valid;
wire RF_bypass_1;
wire RF_bypass_2;
assign RF_bypass_1 =(|rf_waddr)& rf_we & (rf_waddr == rf_raddr1) & addr1_valid;
assign RF_bypass_2 =(|rf_waddr)& rf_we & (rf_waddr == rf_raddr2) & addr2_valid;

assign rj_value  = EXE_bypass_1? EXE_alu_result:(MEM_bypass_1? MEM_final_result:(RF_bypass_1?rf_wdata:rf_rdata1));
assign rkd_value = EXE_bypass_2? EXE_alu_result:(MEM_bypass_2? MEM_final_result:(RF_bypass_2? rf_wdata : rf_rdata2));

wire rj_eq_rd;
wire rj_less_rd;
wire rj_lessu_rd;
assign rj_eq_rd = (rj_value == rkd_value);
//exp11 by wjr start
    assign rj_less_rd =($signed(rj_value) < $signed(rkd_value));   //有符号比较rj_value是否小于rkd_value，用于blt和bge
    assign rj_lessu_rd =($unsigned(rj_value) < $unsigned(rkd_value)); //无符号比较rj_value是否小于rkd_value，用于bltu和bgeu
//exp11 by wjr end
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt && rj_less_rd//
                   || inst_bltu && rj_lessu_rd//
                   || inst_bge && !rj_less_rd//
                   || inst_bgeu && !rj_lessu_rd// 
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && ID_valid;
assign br_stall = !ID_ready_go && is_b;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ID_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign br_taken_cancel = br_taken & ID_ready_go;

assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

//change exp12
    assign ID_csr_we = inst_csrwr | inst_csrxchg;
    assign ID_csr_re = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid_w;//change exp13
    assign ID_csr_num = ID_inst[23:10];
    assign ID_csr_raddr = inst_rdcntid_w ? `CSR_TID : ID_inst[23:10];//change exp13  rdcntid指令的读地址为TID控制状态寄存器
    assign csr_raddr = ID_csr_raddr;

    assign ID_csr_wvalue = rkd_value;
    assign ID_csr_rvalue = csr_rvalue;
    assign ID_csr_wmask = inst_csrxchg ? rj_value : csr_mask;
    assign csr_mask = {32{ID_csr_num == `CSR_CRMD  }} & `CSR_MASK_CRMD   |
                       {32{ID_csr_num == `CSR_PRMD  }} & `CSR_MASK_PRMD   |
                       {32{ID_csr_num == `CSR_ESTAT }} & `CSR_MASK_ESTAT  |
                       {32{ID_csr_num == `CSR_ERA   }} & `CSR_MASK_ERA    |
                       {32{ID_csr_num == `CSR_EENTRY}} & `CSR_MASK_EENTRY |
                       {32{ID_csr_num == `CSR_SAVE0 ||ID_csr_num == `CSR_SAVE1 || ID_csr_num == `CSR_SAVE2 || ID_csr_num == `CSR_SAVE3 }} & `CSR_MASK_SAVE | 
                       //exp13 start
                       {32{ID_csr_num == `CSR_ECFG  }} & `CSR_MASK_ECFG   |
                       {32{ID_csr_num == `CSR_BADV  }} & `CSR_MASK_BADV   |
                       {32{ID_csr_num == `CSR_TID   }} & `CSR_MASK_TID    |
                       {32{ID_csr_num == `CSR_TCFG  }} & `CSR_MASK_TCFG   |
                       {32{ID_csr_num == `CSR_TICLR }} & `CSR_MASK_TICLR  |
                       //exp13 end
                       //exp18 start
                       {32{ID_csr_num == `CSR_TLBIDX}} & `CSR_MASK_TLBIDX |
                       {32{ID_csr_num == `CSR_TLBEHI}} & `CSR_MASK_TLBEHI |
                       {32{ID_csr_num == `CSR_TLBELO0 || ID_csr_num == `CSR_TLBELO1}} & `CSR_MASK_TLBELO |
                       {32{ID_csr_num == `CSR_ASID  }} & `CSR_MASK_ASID   |
                       {32{ID_csr_num == `CSR_TLBRENTRY}} & `CSR_MASK_TLBRENTRY |
                       //exp18 end
                       //exp19 add                            
                       {32{ID_csr_num == `CSR_DMW0  || ID_csr_num == `CSR_DMW1  }} & `CSR_MASK_DMW;

//to EXE and IF
    assign ID_to_EXE_bus = {id_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, invtlb_op, rj_value,//exp18 add 43bit
                            inst_rdcntvl_w, inst_rdcntvh_w,//exp13 add 2bit
                            ID_csr_we, ID_csr_re, ID_csr_num, ID_csr_wmask, ID_csr_wvalue, ID_csr_rvalue,//112bit
                            inst_ertn, ID_exc_type,//7bit  //exp19 ID_exc_type add 9bit
                            alu_op, alu_src1, alu_src2, 
                            res_from_mem, gr_we, mem_we, dest,
                            rkd_value,
                            ID_pc, ID_inst};

    assign ID_to_IF_bus = { br_stall, br_taken_cancel, br_target};

endmodule
