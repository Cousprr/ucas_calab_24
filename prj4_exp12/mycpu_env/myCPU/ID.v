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

module ID(
    input  wire        clk,
    input  wire        resetn,
    //from IF
    input wire IF_to_ID_valid,//IF正常工作，输出正确结果
    output wire ID_allow_in,//ID正常读入数据
    input wire [63:0] IF_to_ID_bus,//pc & instruction
    output wire [32:0] ID_to_IF_bus,//br_takan & br_target
    //to EXE
    input wire EXE_allow_in,
    output wire ID_to_EXE_valid,
    output wire [305:0] ID_to_EXE_bus,
    //from WB
    input wire [37:0] WB_to_ID_bus,
    //判断阻塞
    input wire [38:0]EXE_wr_bus,
    input wire [37:0]MEM_wr_bus,
    //csr
    input wire [31:0] csr_rvalue,
    output wire [13:0] csr_raddr,
    input wire [15:0] EXE_to_csr_bus,
    input wire [15:0] MEM_to_csr_bus,
    input wire [15:0] WB_to_csr_bus,
    input wire wb_ex

    );
   //inside ID
    reg ID_valid;//ID工作有效
    wire ID_ready_go;//ID工作有效，可进入下个阶段
    wire [31:0] ID_inst;
    wire [31:0] ID_pc;
    wire br_taken;
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

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    
    wire inst_syscall;
    wire inst_csrrd;
    wire inst_csrwr;
    wire inst_csrxchg;
    wire inst_ertn;

    //阻塞
    wire MEM_write;
    wire [4:0]MEM_dest;
    wire [31:0]MEM_final_result;
    wire EXE_write;
    wire EXE_load;
    wire [31:0]EXE_alu_result;
    wire [4:0]EXE_dest;
    wire addr1_valid;
    wire addr2_valid;
 
    assign{EXE_write,EXE_load,EXE_dest, EXE_alu_result} = EXE_wr_bus;
    assign{MEM_write, MEM_dest, MEM_final_result}= MEM_wr_bus;
    
     assign addr1_valid =   inst_add_w | inst_sub_w | inst_slt | inst_addi_w | inst_sltu | 
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

    assign {EXE_csr_we, EXE_ertn, EXE_csr_num} = EXE_to_csr_bus;
    assign {MEM_csr_we, MEM_ertn, EXE_csr_num} = MEM_to_csr_bus;
    assign {WB_csr_we, ertn_flush, WB_csr_num} = WB_to_csr_bus;
    
    wire conflict_csr_write;
    wire conflict_csr_ertn;
    assign conflict_csr_write = EXE_csr_we & (ID_csr_raddr == EXE_csr_num) & (|EXE_csr_num)|
                            MEM_csr_we & (ID_csr_raddr == MEM_csr_num) & (|MEM_csr_num)|
                            WB_csr_we & (ID_csr_raddr == WB_csr_num) & (|WB_csr_num);
    
    assign conflict_csr_ertn =  EXE_ertn & (ID_csr_raddr==`CSR_CRMD)|
                                MEM_ertn & (ID_csr_raddr==`CSR_CRMD)|
                                ertn_flush & (ID_csr_raddr==`CSR_CRMD)|
                                inst_ertn & ((EXE_csr_num == `CSR_ERA)|(EXE_csr_num == `CSR_PRMD))|
                                inst_ertn & ((MEM_csr_num == `CSR_ERA)|(MEM_csr_num == `CSR_PRMD))|
                                inst_ertn & ((WB_csr_num == `CSR_ERA)|(WB_csr_num == `CSR_PRMD));
                        
    wire conflict_csr;
    assign conflict_csr = ID_csr_re  & (conflict_csr_write | conflict_csr_ertn);


    
//change end

    wire conflict_EXE; 
    assign conflict_EXE = EXE_load & (|EXE_dest) & ((EXE_dest == rf_raddr1) & addr1_valid | (EXE_dest == rf_raddr2) & addr2_valid);
    assign ID_ready_go = ~(conflict_EXE | conflict_csr);//change exp12
    assign ID_to_EXE_valid = ID_ready_go & ID_valid;
    assign ID_allow_in = ID_ready_go & EXE_allow_in | ~ID_valid;


    always @(posedge clk)begin
        if(~resetn)begin
            ID_valid <= 1'b0;
        end
        else if(br_taken_cancel) begin
           ID_valid <= 1'b0;
        end
//change exp12
        else if (wb_ex | ertn_flush) begin
            ID_valid <= 1'b0;
        end
//change end
        else if(ID_allow_in) begin
           ID_valid <= IF_to_ID_valid;        
        end
    end     
   
    reg [63:0] IF_to_ID_bus_valid;
    always @(posedge clk)begin
        if(IF_to_ID_valid & ID_allow_in)begin
            IF_to_ID_bus_valid <= IF_to_ID_bus;
        end
    end
    //bus
    assign {ID_pc , ID_inst} = IF_to_ID_bus_valid;

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
                        & ~inst_syscall & ~inst_ertn; //change exp12
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;//stb sth
assign dest          = dst_is_r1 ? 5'd1 : rd;

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
    assign rj_less_rd =($signed(rj_value) < $signed(rkd_value));   //有符号比较rj_value是否小于rkd_value，用于blt和bge                                     //change 6
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
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ID_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);
assign br_taken_cancel = br_taken & ID_ready_go;

assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

//change esp12
assign ID_csr_we = inst_csrwr | inst_csrxchg;
    assign ID_csr_re = inst_csrrd | inst_csrwr | inst_csrxchg;
    assign ID_csr_num = ID_inst[23:10];
    assign ID_csr_raddr = ID_inst[23:10];
    assign csr_raddr = ID_csr_raddr;

    assign ID_csr_wvalue = rkd_value;
    assign ID_csr_rvalue = csr_rvalue;
    assign ID_csr_wmask = inst_csrxchg ? rj_value : csr_mask;
    assign csr_mask =       {32{ID_csr_num == `CSR_CRMD  }} & `CSR_MASK_CRMD   |
                            {32{ID_csr_num == `CSR_PRMD  }} & `CSR_MASK_PRMD   |
                            {32{ID_csr_num == `CSR_ESTAT }} & `CSR_MASK_ESTAT  |
                            {32{ID_csr_num == `CSR_ERA   }} & `CSR_MASK_ERA    |
                            {32{ID_csr_num == `CSR_EENTRY}} & `CSR_MASK_EENTRY |
                            {32{ID_csr_num == `CSR_SAVE0 ||ID_csr_num == `CSR_SAVE1 || ID_csr_num == `CSR_SAVE2 || ID_csr_num == `CSR_SAVE3 }} & `CSR_MASK_SAVE;
    
    wire [5:0] ID_exc_type;
    assign ID_exc_type = {5'b0, inst_syscall};


//to EXE and IF
    assign ID_to_EXE_bus ={ ID_csr_we, ID_csr_re, ID_csr_num, ID_csr_wmask, ID_csr_wvalue, ID_csr_rvalue,//112bit
                            inst_ertn, ID_exc_type,//7bit
                            alu_op, alu_src1, alu_src2, 
                            res_from_mem, gr_we, mem_we, dest,
                            rkd_value,
                            ID_pc, ID_inst};

    assign ID_to_IF_bus = {br_taken_cancel, br_target};



endmodule
