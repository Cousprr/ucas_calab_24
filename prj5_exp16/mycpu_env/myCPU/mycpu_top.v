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
    wire [69:0] IF_to_ID_bus;//70
    wire [33:0] ID_to_IF_bus;//34
    wire EXE_allow_in;
    wire ID_to_EXE_valid;
    wire [307:0] ID_to_EXE_bus;
    wire [37:0] WB_to_ID_bus;
    wire EXE_to_MEM_valid;
    wire MEM_allow_in;
    wire [190:0]EXE_to_MEM_bus;
    wire MEM_to_WB_valid;
    wire WB_allow_in;
    //wire MEM_to_WB_bus;
    wire [187:0] MEM_to_WB_bus;
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
    wire [15:0] MEM_to_csr_bus;
    wire [15:0] EXE_to_csr_bus;
    wire [15:0] WB_to_csr_bus;
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



bridge my_bridge(
        .aclk                (aclk       ),
        .aresetn             (aresetn    ),

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
        .inst_sram_req      (inst_sram_req  ),
        .inst_sram_wr       (inst_sram_wr   ),
        .inst_sram_size     (inst_sram_size ),
        .inst_sram_wstrb    (inst_sram_wstrb),
        .inst_sram_addr     (inst_sram_addr ),
        .inst_sram_wdata    (inst_sram_wdata),
        .inst_sram_addr_ok  (inst_sram_addr_ok),
        .inst_sram_data_ok  (inst_sram_data_ok),
        .inst_sram_rdata    (inst_sram_rdata),
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
    .ex_exit(ex_exit)
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
    .wb_ex(wb_ex)
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
    .ertn_flush(ertn_flush),
    .MEM_ex(MEM_ex),
    .MEM_ertn(MEM_ertn),
    .ldst_cancel(ldst_cancel)
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
    .ertn_flush(ertn_flush),
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
    .wb_badvaddr(wb_badvaddr)
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
    .wb_badvaddr(wb_badvaddr)
    );
//wire        load_op;

endmodule
