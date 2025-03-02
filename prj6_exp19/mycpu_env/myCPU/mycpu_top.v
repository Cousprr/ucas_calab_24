module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,
    // read requeset
    // master->slave
    output [ 3:0]   arid,
    output [31:0]   araddr,
    output [ 7:0]   arlen,
    output [ 2:0]   arsize,
    output [ 1:0]   arburst,
    output [ 1:0]   arlock,
    output [ 3:0]   arcache,
    output [ 2:0]   arprot,
    output          arvalid,
    // slave->master
    input           arready,
    // read response
    // slave->master
    input  [ 3:0]   rid,
    input  [31:0]   rdata,
    input  [ 1:0]   rresp,
    input           rlast,
    input           rvalid,
    // master->slave
    output          rready,
    // write request
    // master->slave
    output [ 3:0]   awid,
    output [31:0]   awaddr,
    output [ 7:0]   awlen,
    output [ 2:0]   awsize,
    output [ 1:0]   awburst,
    output [ 1:0]   awlock,
    output [ 3:0]   awcache,
    output [ 2:0]   awprot,
    output          awvalid,
    // slave->master
    input           awready,
    // write data
    // master->slave
    output  [ 3:0]  wid,
    output  [31:0]  wdata,
    output  [ 3:0]  wstrb,
    output          wlast,
    output          wvalid,
    // slave->master
    input           wready,
    // write response
    // slave->master
    input  [ 3:0]   bid,
    input  [ 1:0]   bresp,
    input           bvalid,
    // master->slave
    output          bready,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);



    wire ID_allow_in;
    wire IF_to_ID_valid;
    wire [78:0] IF_to_ID_bus;//exp19 add 9bit
    wire [33:0] ID_to_IF_bus;//34
    wire EXE_allow_in;
    wire ID_to_EXE_valid;
    wire [359:0] ID_to_EXE_bus;//exp19 add 9bit
    wire [37:0] WB_to_ID_bus;
    wire EXE_to_MEM_valid;
    wire MEM_allow_in;
    wire [209:0]EXE_to_MEM_bus;//exp19 add 9bit
    wire MEM_to_WB_valid;
    wire WB_allow_in;
    //wire MEM_to_WB_bus;
    wire [206:0] MEM_to_WB_bus;//exp19 add 9bit
    wire [38:0]EXE_wr_bus;
    wire [38:0]MEM_wr_bus;
    wire csr_we;             //写使能
    wire [13:0] csr_num;     //寄存器号(写)
    wire [31:0] csr_wmask;    //写掩码
    wire [31:0] csr_wvalue;   //写数据
    wire [13:0] csr_raddr;    //读地址
    wire [31:0] csr_rvalue;  //读数据
    wire [31:0] ex_entry;    //中断程序入口地址
    wire [31:0] ex_exit;     //中断程序退出地址
    wire ertn_flush;          //ertn指令执行的有效信号
    wire has_int;            //中断有效信号
    wire wb_ex;               //异常处理触发信号
    wire [5:0] wb_ecode;
    wire [8:0] wb_esubcode;
    wire [31:0] WB_pc;
    wire MEM_ex;
    wire MEM_ertn;
    wire [16:0] MEM_to_csr_bus;
    wire [16:0] EXE_to_csr_bus;
    wire [16:0] WB_to_csr_bus;
    wire [31:0] wb_badvaddr;
    wire csr_has_int;
    wire ldst_cancel;
    wire            inst_sram_req;
    wire            inst_sram_wr;
    wire  [ 1:0]    inst_sram_size;
    wire  [31:0]    inst_sram_addr;
    wire  [ 3:0]    inst_sram_wstrb;
    wire  [31:0]    inst_sram_wdata;
    wire            inst_sram_addr_ok;
    wire            inst_sram_data_ok;
    wire [31:0]     inst_sram_rdata;
    wire            data_sram_req;
    wire            data_sram_wr;
    wire  [ 1:0]    data_sram_size;
    wire  [31:0]    data_sram_addr;
    wire  [ 3:0]    data_sram_wstrb;
    wire  [31:0]    data_sram_wdata;
    wire            data_sram_addr_ok;
    wire            data_sram_data_ok;
    wire [31:0]     data_sram_rdata;

    wire       tlbrd_we;
    wire       tlbsrch_we;
    wire       tlb_hit;
    wire [ 3:0]tlb_hit_index;
    wire [ 3:0]csr_tlbidx_index;
    wire [18:0]csr_tlbehi_vppn;
    wire [9:0] csr_asid_asid;
    wire [18:0]s0_vppn;
    wire       s0_va_bit12;
    wire [ 9:0]s0_asid;
    wire       s0_found;
    wire [ 3:0]s0_index;
    wire [19:0]s0_ppn;
    wire [ 5:0]s0_ps;
    wire [ 1:0]s0_plv;
    wire [ 1:0]s0_mat;
    wire       s0_d;
    wire       s0_v;
    wire [18:0]s1_vppn;
    wire       s1_va_bit12;
    wire [ 9:0]s1_asid;
    wire       s1_found;
    wire [ 3:0]s1_index;
    wire [19:0]s1_ppn;
    wire [ 5:0]s1_ps;
    wire [ 1:0]s1_plv;
    wire [ 1:0]s1_mat;
    wire       s1_d;
    wire       s1_v;
    wire [ 4:0]invtlb_op;
    wire       invtlb_valid;
    wire       we;
    wire [ 3:0]w_index;
    wire       w_e;
    wire [18:0]w_vppn;
    wire [ 5:0]w_ps;
    wire [ 9:0]w_asid;
    wire       w_g;
    wire [19:0]w_ppn0;
    wire [ 1:0]w_plv0;
    wire [ 1:0]w_mat0;
    wire       w_d0;
    wire       w_v0;
    wire [19:0]w_ppn1;
    wire [ 1:0]w_plv1;
    wire [ 1:0]w_mat1;
    wire       w_d1;
    wire       w_v1;
    wire [ 3:0]r_index;
    wire       r_e;
    wire [18:0]r_vppn;
    wire [ 5:0]r_ps;
    wire [ 9:0]r_asid;
    wire       r_g;
    wire [19:0]r_ppn0;
    wire [ 1:0]r_plv0;
    wire [ 1:0]r_mat0;
    wire       r_d0;
    wire       r_v0;
    wire [19:0]r_ppn1;
    wire [ 1:0]r_plv1;
    wire [ 1:0]r_mat1;
    wire       r_d1;
    wire       r_v1;
    assign s0_asid = csr_asid_asid;
    
    wire [14:0]                         WB_ex_type;//exp19 add 9bit    

    wire [ 1:0]                         csr_crmd_plv;
    wire                                csr_crmd_da;
    wire                                csr_crmd_pg;
    wire                                csr_dmw0_plv0;
    wire                                csr_dmw0_plv3;
    wire [ 1:0]                         csr_dmw0_mat;
    wire [ 2:0]                         csr_dmw0_pseg;
    wire [ 2:0]                         csr_dmw0_vseg;
    wire                                csr_dmw1_plv0;
    wire                                csr_dmw1_plv3;
    wire [ 1:0]                         csr_dmw1_mat;
    wire [ 2:0]                         csr_dmw1_pseg;
    wire [ 2:0]                         csr_dmw1_vseg;

    wire                                flush;
    wire    [31:0]                      flush_pc;
    wire                                refetch;    


    bridge my_bridge(
        .aclk               (aclk      ),
        .aresetn            (aresetn   ),

        .arid               (arid      ),
        .araddr             (araddr    ),
        .arlen              (arlen     ),
        .arsize             (arsize    ),
        .arburst            (arburst   ),
        .arlock             (arlock    ),
        .arcache            (arcache   ),
        .arprot             (arprot    ),
        .arvalid            (arvalid   ),
        .arready            (arready   ),
                    
        .rid                (rid       ),
        .rdata              (rdata     ),
        .rresp              (rresp     ),
        .rlast              (rlast     ),
        .rvalid             (rvalid    ),
        .rready             (rready    ),
                
        .awid               (awid      ),
        .awaddr             (awaddr    ),
        .awlen              (awlen     ),
        .awsize             (awsize    ),
        .awburst            (awburst   ),
        .awlock             (awlock    ),
        .awcache            (awcache   ),
        .awprot             (awprot    ),
        .awvalid            (awvalid   ),
        .awready            (awready   ),
        
        .wid                (wid       ),
        .wdata              (wdata     ),
        .wstrb              (wstrb     ),
        .wlast              (wlast     ),
        .wvalid             (wvalid    ),
        .wready             (wready    ),
        
        .bid                (bid       ),
        .bresp              (bresp     ),
        .bvalid             (bvalid    ),
        .bready             (bready    ),
        .inst_sram_req      (inst_sram_req    ),
        .inst_sram_wr       (inst_sram_wr     ),
        .inst_sram_size     (inst_sram_size   ),
        .inst_sram_wstrb    (inst_sram_wstrb  ),
        .inst_sram_addr     (inst_sram_addr   ),
        .inst_sram_wdata    (inst_sram_wdata  ),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata  ),
        .data_sram_req      (data_sram_req    ),
        .data_sram_wr       (data_sram_wr     ),
        .data_sram_size     (data_sram_size   ),
        .data_sram_addr     (data_sram_addr   ),
        .data_sram_wstrb    (data_sram_wstrb  ),
        .data_sram_wdata    (data_sram_wdata  ),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata  )
    );


    IF u_IF(
        .clk(aclk),
        .resetn(aresetn),
        .ID_allow_in(ID_allow_in),
        .IF_to_ID_valid(IF_to_ID_valid),
        .IF_to_ID_bus(IF_to_ID_bus),//pc & instruction
        .ID_to_IF_bus(ID_to_IF_bus),//br_takan & br_target
        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .wb_ex(wb_ex),
        .ertn_flush(ertn_flush),
        .ex_entry(ex_entry),
        .ex_exit(ex_exit),
    
        .flush              (flush),
        .flush_pc           (flush_pc),
        
        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_crmd_plv       (csr_crmd_plv),
        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),
        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg),
        
        .s0_ppn             (s0_ppn),
        .s0_ps              (s0_ps),        
        .s0_found           (s0_found),
        .s0_v               (s0_v),
        .s0_plv             (s0_plv),
        .s0_vppn            (s0_vppn),
        .s0_va_bit12        (s0_va_bit12)
    );
 
    ID u_ID(
        .clk(aclk),
        .resetn(aresetn),
        .IF_to_ID_valid(IF_to_ID_valid),//IF正常工作，输出正确结果
        .ID_allow_in(ID_allow_in),//ID正常读入数据
        .IF_to_ID_bus(IF_to_ID_bus),//pc & instruction
        .ID_to_IF_bus(ID_to_IF_bus),//br_takan & br_target
        .EXE_allow_in(EXE_allow_in),
        .ID_to_EXE_valid(ID_to_EXE_valid),
        .ID_to_EXE_bus(ID_to_EXE_bus),
        .WB_to_ID_bus(WB_to_ID_bus),
        .EXE_wr_bus(EXE_wr_bus),
        .MEM_wr_bus(MEM_wr_bus),
        .csr_rvalue(csr_rvalue),
        .csr_raddr(csr_raddr),
        .EXE_to_csr_bus(EXE_to_csr_bus),
        .MEM_to_csr_bus(MEM_to_csr_bus),
        .WB_to_csr_bus(WB_to_csr_bus),
        .csr_has_int(csr_has_int),
        .wb_ex(wb_ex),
        .flush(flush)//exp19 add
    );
    
    EXE u_EXE(
        .clk(aclk),
        .resetn(aresetn),
        .EXE_allow_in(EXE_allow_in),
        .ID_to_EXE_valid(ID_to_EXE_valid),
        .ID_to_EXE_bus(ID_to_EXE_bus),
        .EXE_to_MEM_valid(EXE_to_MEM_valid),
        .MEM_allow_in(MEM_allow_in),
        .EXE_to_MEM_bus(EXE_to_MEM_bus),
        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),
        .EXE_wr_bus(EXE_wr_bus),
        .EXE_to_csr_bus(EXE_to_csr_bus),
        .wb_ex(wb_ex),
        .flush(flush),//exp19 add
        .ertn_flush(ertn_flush),//exp19 delete
        .MEM_ex(MEM_ex),
        .MEM_ertn(MEM_ertn),
        .ldst_cancel(ldst_cancel),
        .s1_vppn(s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid(s1_asid),
        .s1_found(s1_found),
        .s1_index(s1_index),
        .s1_ppn(s1_ppn),
        .s1_ps(s1_ps),
        .s1_plv(s1_plv),
        .s1_mat(s1_mat),
        .s1_d(s1_d),
        .s1_v(s1_v),
        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),
        .csr_asid_asid(csr_asid_asid),
        .csr_tlbehi_vppn(csr_tlbehi_vppn),

        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_crmd_plv       (csr_crmd_plv),

        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),

        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg)
    );
    
    MEM u_MEM(
        .clk(aclk),
        .resetn(aresetn),
        .MEM_allow_in(MEM_allow_in),
        .EXE_to_MEM_valid(EXE_to_MEM_valid),
        .EXE_to_MEM_bus(EXE_to_MEM_bus),
        .MEM_to_WB_valid(MEM_to_WB_valid),
        .WB_allow_in(WB_allow_in),
        .MEM_to_WB_bus(MEM_to_WB_bus),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_data_ok(data_sram_data_ok),
        .MEM_wr_bus(MEM_wr_bus),
        .MEM_ex(MEM_ex),
        .MEM_ertn(MEM_ertn),
        .MEM_to_csr_bus(MEM_to_csr_bus),
        .wb_ex(wb_ex),
        .flush(flush),//exp19 add
        .ertn_flush(ertn_flush),//exp19 delete
        .ldst_cancel(ldst_cancel)
    );
    
    WB u_WB(
        .clk(aclk),
        .resetn(aresetn),
        .WB_allow_in(WB_allow_in),
        .MEM_to_WB_valid(MEM_to_WB_valid),
        .MEM_to_WB_bus(MEM_to_WB_bus),
        .WB_to_ID_bus(WB_to_ID_bus),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),
        .csr_we(csr_we),              //写使能
        .csr_num(csr_num),      //寄存器号(写)
        .csr_wmask(csr_wmask),    //写掩码
        .csr_wvalue(csr_wvalue),   //写数据
        .wb_ex(wb_ex),               //异常处理触发信号
        .wb_ecode(wb_ecode),
        .wb_esubcode(wb_esubcode),
        .WB_pc(WB_pc),
        .ertn_flush(ertn_flush),
        .WB_to_csr_bus(WB_to_csr_bus),
        .wb_badvaddr(wb_badvaddr),
        .refetch(refetch),
        .r_index(r_index),
        .tlbrd_we(tlbrd_we),
        .csr_tlbidx_index(csr_tlbidx_index),
        .tlbwr_we(tlbwr_we),
        .tlbfill_we(tlbfill_we),
        .w_index(w_index),
        .tlb_we(we),//tlbwr_we | tlbfill_we
        .tlb_hit(tlb_hit),
        .tlbsrch_we(tlbsrch_we),
        .tlb_hit_index(tlb_hit_index),
        .WB_ex_type(WB_ex_type),//exp19 add
        .flush(flush)//exp19 add
    );
    
    csr u_csr(
        .clk(aclk),
        .resetn(aresetn),
        .csr_we(csr_we),              //写使能
        .csr_num(csr_num),      //寄存器号(写)
        .csr_wmask(csr_wmask),    //写掩码
        .csr_wvalue(csr_wvalue),   //写数据
        .csr_raddr(csr_raddr),    //读地址
        .csr_rvalue(csr_rvalue),  //读数据
        .ex_entry(ex_entry),    //中断程序入口地址
        .ex_exit(ex_exit),     //中断程序退出地址
        .ertn_flush(ertn_flush),          //ertn指令执行的有效信号
        .csr_has_int(csr_has_int),            //中断有效信号
        .wb_ex(wb_ex),               //异常处理触发信号
        .wb_ecode(wb_ecode),
        .wb_esubcode(wb_esubcode),
        .WB_pc(WB_pc),
        .wb_badvaddr(wb_badvaddr),
        .csr_asid_asid(csr_asid_asid),
        .csr_tlbehi_vppn(csr_tlbehi_vppn),
        .csr_tlbidx_index(csr_tlbidx_index),
        .tlbrd_we(tlbrd_we),
        .tlbsrch_we(tlbsrch_we),
        .tlbsrch_hit(tlb_hit),
        .tlb_hit_index(tlb_hit_index),
        .r_tlb_e(r_e),
        .r_tlb_ps(r_ps),
        .r_tlb_vppn(r_vppn),
        .r_tlb_asid(r_asid),
        .r_tlb_g(r_g),
        .r_tlb_ppn0(r_ppn0),
        .r_tlb_plv0(r_plv0),
        .r_tlb_mat0(r_mat0),
        .r_tlb_d0(r_d0),
        .r_tlb_v0(r_v0),
        .r_tlb_ppn1(r_ppn1),
        .r_tlb_plv1(r_plv1),
        .r_tlb_mat1(r_mat1),
        .r_tlb_d1(r_d1),
        .r_tlb_v1(r_v1),
        .w_tlb_e(w_e),
        .w_tlb_ps(w_ps),
        .w_tlb_vppn(w_vppn),
        .w_tlb_asid(w_asid),
        .w_tlb_g(w_g),
        .w_tlb_ppn0(w_ppn0),
        .w_tlb_plv0(w_plv0),
        .w_tlb_mat0(w_mat0),
        .w_tlb_d0(w_d0),
        .w_tlb_v0(w_v0),
        .w_tlb_ppn1(w_ppn1),
        .w_tlb_plv1(w_plv1),
        .w_tlb_mat1(w_mat1),
        .w_tlb_d1(w_d1),
        .w_tlb_v1(w_v1),
        .WB_ex_type        (WB_ex_type),    

        .refetch            (refetch),
        .flush              (flush),
        .flush_pc           (flush_pc),

        .csr_crmd_plv       (csr_crmd_plv),
        .csr_crmd_da        (csr_crmd_da),
        .csr_crmd_pg        (csr_crmd_pg),
        .csr_dmw0_plv0      (csr_dmw0_plv0),
        .csr_dmw0_plv3      (csr_dmw0_plv3),
        .csr_dmw0_mat       (csr_dmw0_mat),
        .csr_dmw0_pseg      (csr_dmw0_pseg),
        .csr_dmw0_vseg      (csr_dmw0_vseg),
        .csr_dmw1_plv0      (csr_dmw1_plv0),
        .csr_dmw1_plv3      (csr_dmw1_plv3),
        .csr_dmw1_mat       (csr_dmw1_mat),
        .csr_dmw1_pseg      (csr_dmw1_pseg),
        .csr_dmw1_vseg      (csr_dmw1_vseg)
    );

    tlb u_tlb(
        .clk(aclk),
        .s0_vppn(s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid(s0_asid),
        .s0_found(s0_found),
        .s0_index(s0_index),
        .s0_ppn(s0_ppn),
        .s0_ps(s0_ps),
        .s0_plv(s0_plv),
        .s0_mat(s0_mat),
        .s0_d(s0_d),
        .s0_v(s0_v),
        .s1_vppn(s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid(s1_asid),
        .s1_found(s1_found),
        .s1_index(s1_index),
        .s1_ppn(s1_ppn),
        .s1_ps(s1_ps),
        .s1_plv(s1_plv),
        .s1_mat(s1_mat),
        .s1_d(s1_d),
        .s1_v(s1_v),
        .invtlb_valid(invtlb_valid),
        .invtlb_op(invtlb_op),
        .we(we),
        .w_index(w_index),
        .w_e(w_e),
        .w_vppn(w_vppn),
        .w_ps(w_ps),
        .w_asid(w_asid),
        .w_g(w_g),
        .w_ppn0(w_ppn0),
        .w_plv0(w_plv0),
        .w_mat0(w_mat0),
        .w_d0(w_d0),
        .w_v0(w_v0),
        .w_ppn1(w_ppn1),
        .w_plv1(w_plv1),
        .w_mat1(w_mat1),
        .w_d1(w_d1),
        .w_v1(w_v1),
        .r_index(r_index),
        .r_e(r_e),
        .r_vppn(r_vppn),
        .r_ps(r_ps),
        .r_asid(r_asid),
        .r_g(r_g),
        .r_ppn0(r_ppn0),
        .r_plv0(r_plv0),
        .r_mat0(r_mat0),
        .r_d0(r_d0),
        .r_v0(r_v0),
        .r_ppn1(r_ppn1),
        .r_plv1(r_plv1),
        .r_mat1(r_mat1),
        .r_d1(r_d1),
        .r_v1(r_v1)
    );
//wire        load_op;

endmodule
