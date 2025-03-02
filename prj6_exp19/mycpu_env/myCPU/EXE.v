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

module EXE(
    input  wire        clk,
    input  wire        resetn,
    //from ID
    output wire EXE_allow_in,
    input wire ID_to_EXE_valid,
    input wire [359:0] ID_to_EXE_bus,//exp19 add 9bit
    //to MEM
    output wire EXE_to_MEM_valid,
    input wire MEM_allow_in,
    output wire [209:0] EXE_to_MEM_bus,//exp19 add 9bit
    // to data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [1 :0] data_sram_size,
    output wire [31:0] data_sram_addr,
    output wire [3 :0] data_sram_wstrb,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    //判断阻塞 EXE写信号
    output wire  [38:0]EXE_wr_bus,

    //csr
    output [16:0] EXE_to_csr_bus,
    input wb_ex,
    input ertn_flush,
    input MEM_ex,
    input MEM_ertn,
    input ldst_cancel,

    output [18:0] s1_vppn,
    output s1_va_bit12,
    output [9:0] s1_asid,
    input s1_found,
    input [3:0] s1_index,
    input [19:0] s1_ppn,
    input [5:0] s1_ps,
    input [1:0] s1_plv,
    input [1:0] s1_mat,
    input s1_d,
    input s1_v,
    output invtlb_valid,
    output [4:0] invtlb_op,
    input [9:0] csr_asid_asid,
    input [18:0] csr_tlbehi_vppn,
    
    input       csr_crmd_da,
    input       csr_crmd_pg,
    input [1:0] csr_crmd_plv,
    input       csr_dmw0_plv0,
    input       csr_dmw0_plv3,
    input [1:0] csr_dmw0_mat,
    input [2:0] csr_dmw0_pseg,
    input [2:0] csr_dmw0_vseg,
    input       csr_dmw1_plv0,
    input       csr_dmw1_plv3,
    input [1:0] csr_dmw1_mat,
    input [2:0] csr_dmw1_pseg,
    input [2:0] csr_dmw1_vseg,
    
    input wire flush
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
    assign EXE_ready_go    = (is_load || mem_we)? (((data_sram_req & data_sram_addr_ok) | ls_cancel)) : //exp16 delete " || addr_ok_reg"
                             ((alu_op[15] | alu_op[17]) & div_out_valid | 
                             (alu_op[16] | alu_op[18]) & divu_out_valid |
                             (~(alu_op[15]|alu_op[16]|alu_op[17]|alu_op[18])));
    
    wire [31:0] EXE_inst;
    wire [31:0] EXE_pc;
    assign EXE_to_MEM_valid =~is_ertn_exc & EXE_ready_go & EXE_valid;
    assign EXE_allow_in = EXE_ready_go & MEM_allow_in | ~EXE_valid;
    
    always @(posedge clk)begin
        if(~resetn)begin
            EXE_valid <= 1'b0;
        end
        else if(EXE_allow_in)begin
            EXE_valid <= ID_to_EXE_valid;
        end
    end  

    reg [359:0] ID_to_EXE_bus_valid;//exp19 add 9bit
    always @(posedge clk)begin
        if(~resetn)begin
            ID_to_EXE_bus_valid <= 360'b0;
        end
        else if(ID_to_EXE_valid & EXE_allow_in)begin
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
    wire [14:0] EXE_ex_type;//exp19 add 9bit
    wire [14:0] ID_ex_type;//exp19 add 9bit
    wire inst_ertn;
    //exp13 add
    wire inst_rdcntvl_w;
    wire inst_rdcntvh_w;

    wire exe_refetch;
    wire inst_tlbsrch;
    wire inst_tlbrd;
    wire inst_tlbwr;
    wire inst_tlbfill;
    wire inst_invtlb;
    wire [4:0] invtlb_op;
    wire [31:0] rj_value;

//change exp12
    assign{exe_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, inst_invtlb, invtlb_op, rj_value,//exp18 add 43bit
            inst_rdcntvl_w, inst_rdcntvh_w,//exp13 add 2bit
            EXE_csr_we, EXE_csr_re, EXE_csr_num, EXE_csr_wmask, EXE_csr_wvalue, EXE_csr_rvalue,//112bit
            inst_ertn, ID_ex_type,//exp19 ID_ex_type add 9bit    //change exp12 and exp13
            alu_op, alu_src1, alu_src2, 
            res_from_mem, gr_we, mem_we, dest,
            rkd_value,
            EXE_pc, EXE_inst} = ID_to_EXE_bus_valid;

    assign EXE_ex = (|EXE_ex_type) & EXE_valid; 
    assign EXE_ertn = inst_ertn & EXE_valid;
    assign EXE_to_csr_bus = { EXE_csr_we & EXE_valid, EXE_ertn, inst_tlbsrch & EXE_valid, EXE_csr_num};
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

//exp19 add start
//主bus连接
    wire exe_dmw0_hit;
    wire exe_dmw1_hit;
    wire [31:0] exe_dmw0_paddr;
    wire [31:0] exe_dmw1_paddr;
    wire [31:0] exe_tlb_paddr;
    wire use_tlb;
    assign exe_dmw0_hit = (alu_result[31:29] == csr_dmw0_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw0_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw0_plv3);
    assign exe_dmw1_hit = (alu_result[31:29] == csr_dmw1_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw1_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw1_plv3);
    //exe_dmw0/1_hit：检查地址是否命中直接映射窗口DMW0/1
    //vseg:直接映射窗口的虚地址的[31:29]位   plv:特权等级  dmw0/1_plv0/3为1:在对应特权等级下可使用该窗口的配置进行直接地址映射翻译
    assign exe_dmw0_paddr = {csr_dmw0_pseg, alu_result[28:0]};//pseg:直接映射窗口的物理地址的[31:29]位
    assign exe_dmw1_paddr = {csr_dmw1_pseg, alu_result[28:0]};
    //exe_dmw0/1_paddr：直接映射窗口命中时计算的物理地址。
    assign exe_tlb_paddr = (s1_ps == 6'd21) ? {s1_ppn[19:9], alu_result[20:0]} : {s1_ppn, alu_result[11:0]};
    //exe_tlb_paddr：通过TLB计算的物理地址。根据页表大小(s0_ps)进行拼接。s1_ppn:物理页号
    assign use_tlb = ~csr_crmd_da & csr_crmd_pg & ~exe_dmw0_hit & ~exe_dmw1_hit;//da=0, pg=1, pf_dmw0_hit=0, pf_dmw1_hit=0
    //指示是否需要通过TLB进行地址转换。da（直接地址翻译使能）=0，pg（映射地址翻译使能）=1，直接映射未命中dmw0/1_hit=0
//exp19 add end

    //change exp14
    wire ls_cancel;
    assign ls_cancel = is_ertn_exc | ldst_cancel | (|EXE_ex_type);
    assign data_sram_req = (is_load || mem_we) && EXE_valid && ~is_ertn_exc && MEM_allow_in && ~ls_cancel;//exp16 change "~addr_ok_reg" to "MEM_allow_in"
    //assign data_sram_addr  = alu_result;
    assign data_sram_addr = (csr_crmd_da & ~csr_crmd_pg) ? alu_result :     //直接地址翻译  da（直接地址翻译使能）=1，pg（映射地址翻译使能）=0
                             exe_dmw0_hit                 ? exe_dmw0_paddr : //映射地址翻译-直接映射
                             exe_dmw1_hit                 ? exe_dmw1_paddr : //映射地址翻译-直接映射
                                                            exe_tlb_paddr;   //映射地址翻译-页表映射  exp19 change
    assign data_sram_wr = EXE_valid & mem_we;
    assign data_sram_size = inst_st_h ? 2'h1 : inst_st_w ? 2'h2 : 2'h0;
    assign data_sram_wstrb = inst_st_b ? (4'b0001<<alu_result[1:0]) :
                             inst_st_h ? (4'b0011<<{alu_result[1],1'b0}) :
                             inst_st_w ? 4'b1111       : 4'b0;
    assign data_sram_wdata =    {32{inst_st_w}} & rkd_value |
                                {32{inst_st_h}} & {2{rkd_value[15:0]}} |
                                {32{inst_st_b}} & {4{rkd_value[7:0]}};//考虑写使能
//store by dxl end

//exp14 add excontrol
    reg flush_reg;
    wire is_load;
    assign is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
  
//exp19 change    
    always @(posedge clk ) begin
        if(~resetn)begin
            flush_reg <= 1'b0;
        end
        else if (flush) begin
            flush_reg <= 1'b1;
        end
        else if (ID_to_EXE_valid & EXE_allow_in)begin
            flush_reg <= 1'b0;
        end
    end                     

    wire is_ertn_exc;
//    assign is_ertn_exc = wb_ex | ertn_flush | ex_reg | ertn_reg;
    assign is_ertn_exc = flush | flush_reg;//exp19 change

//exp13 add start
    wire inst_ld_b;
    wire inst_ld_h;
    wire inst_ld_bu;
    wire inst_ld_hu;
    wire inst_ld_w;
    assign inst_ld_b  = EXE_inst[31:22] == 10'b0010100000;
    assign inst_ld_h  = EXE_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = EXE_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = EXE_inst[31:22] == 10'b0010101001;
    assign inst_ld_w  = EXE_inst[31:22] == 10'b0010100010;

    assign  EXE_ex_type[`TYPE_SYS] = ID_ex_type[`TYPE_SYS];
    assign  EXE_ex_type[`TYPE_ADEF] = ID_ex_type[`TYPE_ADEF];
    assign  EXE_ex_type[`TYPE_ALE] = EXE_valid & ((inst_ld_h | inst_ld_hu | inst_st_h) & alu_result[0] | (inst_ld_w | inst_st_w) & (|alu_result[1:0]));
    //还有LL/SC指令&(|alu_result[1:0])，但目前还没有实现这两个指令
    assign  EXE_ex_type[`TYPE_BRK] = ID_ex_type[`TYPE_BRK];
    assign  EXE_ex_type[`TYPE_INE] = ID_ex_type[`TYPE_INE];
    assign  EXE_ex_type[`TYPE_INT] = ID_ex_type[`TYPE_INT];
//exp13 add end
//exp19 add 9bit
    assign EXE_ex_type[`TYPE_TLBRF] = ID_ex_type[`TYPE_TLBRF];
    assign EXE_ex_type[`TYPE_PPIF]  = ID_ex_type[`TYPE_PPIF];
    assign EXE_ex_type[`TYPE_PIF ]  = ID_ex_type[`TYPE_PIF ];
    assign EXE_ex_type[`TYPE_ADEM]  = (is_load || mem_we) & alu_result[31] & (csr_crmd_plv == 2'd3) & ~exe_dmw0_hit & ~exe_dmw1_hit;//访存指令地址错例外   是st指令且用户态不合法访问，且地址未命中DMW窗口
    //alu_result[31] & csr_crmd_plv == 2'd3：所有特权指令仅在PLV0特权等级下才能访问。
    assign EXE_ex_type[`TYPE_TLBRM] = (is_load || mem_we) & use_tlb & ~s1_found;//TLB重填例外。是ld/st指令，需要通过TLB进行地址转换，且没有找到对应TLB表项，即TLB没命中
    assign EXE_ex_type[`TYPE_PIL]   = is_load & use_tlb & s1_found & ~s1_v;//load操作页无效例外。是ld指令，在TLB中找到了匹配项但是匹配页表项的V=0    s1_v：有效位
    assign EXE_ex_type[`TYPE_PIS]   = mem_we & use_tlb & s1_found & ~s1_v;//store操作页无效例外。是st指令，在TLB中找到了匹配项但是匹配页表项的V=0    s1_v：有效位
    assign EXE_ex_type[`TYPE_PPIM]  = (is_load || mem_we) & use_tlb & s1_found & s1_v & (csr_crmd_plv > s1_plv);//页特权等级不合规例外。访存操作的虚地址在TLB中找到了匹配且V=1的项，但是访问的特权等级不合规
                                                                                                                  //特权等级不合规：该页表项的csr_crmd_plv(当前特权等级)值大于页表项中的PLV(特权等级)
    assign EXE_ex_type[`TYPE_PME]   = mem_we & use_tlb & s1_found & s1_v & ((csr_crmd_plv < s1_plv)|(csr_crmd_plv == s1_plv)) & ~s1_d;//页修改例外。是st指令，在TLB中找到了匹配且V=1且特权等级合规的项，但是该页表项的D位为0    s1_d：脏位
    //(is_load || mem_we) :是ld/st指令。is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w; mem_we = inst_st_w | inst_st_b | inst_st_h;


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
    
//exp13 add start
reg [63:0] countor;
always @ (posedge clk) begin
    if (~resetn)
        countor <= 64'b0;
    else
        countor <= countor + 64'b1;
end
//exp13 add end
    
    assign exe_result =inst_rdcntvh_w ? countor[63:32] ://exp13 add
                        inst_rdcntvl_w ? countor[31:0] ://exp13 add
                        EXE_csr_re ? EXE_csr_rvalue://change exp12
                        alu_op[15] ? div_res_remainder :
                        alu_op[17] ? div_res_quotient :
                        alu_op[16] ? divu_res_remainder :
                        alu_op[18] ? divu_res_quotient :
                                     alu_result;
    
//by wjr end

wire exe_tlbhit;
wire [3:0] exe_tlbhit_index;
assign exe_tlbhit = s1_found;
assign exe_tlbhit_index = s1_index;

//change exp14
assign EXE_to_MEM_bus ={exe_refetch, inst_tlbsrch, inst_tlbrd, inst_tlbwr, inst_tlbfill, exe_tlbhit, exe_tlbhit_index,//exp18 add 10bit
                        EXE_csr_we, EXE_csr_num, EXE_csr_wmask, EXE_csr_wvalue,//112bit
                        inst_ertn, EXE_ex_type,//exp19 EXE_ex_type add 9bit
                        exe_result,
                        res_from_mem, gr_we, dest, 
                        EXE_pc, EXE_inst,ls_cancel,mem_we};
//相较于exp7改动
    wire EXE_write;
    assign EXE_write = EXE_valid & gr_we;
    wire EXE_load;
    assign EXE_load = EXE_valid & res_from_mem;
    assign EXE_wr_bus = {EXE_write,EXE_load,dest, exe_result};//alu_result 改为 exe_result  

    //tlb
    assign {s1_vppn,s1_va_bit12} = (is_load || mem_we) ? alu_result[31:12] : invtlb_valid ? rkd_value[31:12] : {csr_tlbehi_vppn, 1'b0};
    assign s1_asid = invtlb_valid ? rj_value[9:0] : csr_asid_asid;
    assign invtlb_valid = inst_invtlb;

endmodule
