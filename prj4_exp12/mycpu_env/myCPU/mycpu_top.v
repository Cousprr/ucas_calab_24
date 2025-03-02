module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [3 :0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [3 :0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
    
);
//reg         reset;
//always @(posedge clk) reset <= ~resetn;

//reg         valid;
//always @(posedge clk) begin
//    if (reset) begin
//        valid <= 1'b0;
//    end
//    else begin
//        valid <= 1'b1;
//    end
//end

    wire ID_allow_in;
    wire IF_to_ID_valid;
    wire [63:0] IF_to_ID_bus;
    wire [32:0] ID_to_IF_bus;
    wire EXE_allow_in;
    wire ID_to_EXE_valid;
    wire [186:0] ID_to_EXE_bus;
    wire [37:0] WB_to_ID_bus;
    wire EXE_to_MEM_valid;
    wire MEM_allow_in;
    wire [102:0]EXE_to_MEM_bus;
    wire MEM_to_WB_valid;
    wire WB_allow_in;
    //wire MEM_to_WB_bus;
    wire [101:0] MEM_to_WB_bus;
    wire [38:0]EXE_wr_bus;
    wire [37:0]MEM_wr_bus;
    wire csr_we;             //дʹ��
    wire [13:0] csr_num;     //�Ĵ�����(д)
    wire [31:0] csr_wmask;    //д����
    wire [31:0] csr_wvalue;   //д����
    wire [13:0] csr_raddr;    //����ַ
    wire [31:0] csr_rvalue;  //������
    wire [31:0] ex_entry;    //�жϳ�����ڵ�ַ
    wire [31:0] ex_exit;     //�жϳ����˳���ַ
    wire ertn_flush;          //ertnָ��ִ�е���Ч�ź�
    wire has_int;            //�ж���Ч�ź�
    wire wb_ex;               //�쳣�������ź�
    wire [5:0] wb_ecode;
    wire [8:0] wb_esubcode;
    wire [31:0] WB_pc;
    wire MEM_ex;
    wire MEM_ertn;
    wire [15:0] MEM_to_csr_bus;
    wire [15:0] EXE_to_csr_bus;
    wire [15:0] WB_to_csr_bus;

    IF u_IF(
    .clk(clk),
    .resetn(resetn),
    .ID_allow_in(ID_allow_in),
    .IF_to_ID_valid(IF_to_ID_valid),
    .IF_to_ID_bus(IF_to_ID_bus),//pc & instruction
    .ID_to_IF_bus(ID_to_IF_bus),//br_takan & br_target
    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata),
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush),
    .ex_entry(ex_entry),
    .ex_exit(ex_exit)
    );
 
    ID u_ID(
    .clk(clk),
    .resetn(resetn),
    .IF_to_ID_valid(IF_to_ID_valid),//IF���������������ȷ���
    .ID_allow_in(ID_allow_in),//ID������������
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
    .wb_ex(wb_ex)

    );
    
    EXE u_EXE(
    .clk(clk),
    .resetn(resetn),
    .EXE_allow_in(EXE_allow_in),
    .ID_to_EXE_valid(ID_to_EXE_valid),
    .ID_to_EXE_bus(ID_to_EXE_bus),
    .EXE_to_MEM_valid(EXE_to_MEM_valid),
    .MEM_allow_in(MEM_allow_in),
    .EXE_to_MEM_bus(EXE_to_MEM_bus),
    .data_sram_en(data_sram_en),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .EXE_wr_bus(EXE_wr_bus),
    .EXE_to_csr_bus(EXE_to_csr_bus),
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush),
    .MEM_ex(MEM_ex),
    .MEM_ertn(MEM_ertn)
    );
    
    MEM u_MEM(
    .clk(clk),
    .resetn(resetn),
    .MEM_allow_in(MEM_allow_in),
    .EXE_to_MEM_valid(EXE_to_MEM_valid),
    .EXE_to_MEM_bus(EXE_to_MEM_bus),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .WB_allow_in(WB_allow_in),
    .MEM_to_WB_bus(MEM_to_WB_bus),
    .data_sram_rdata(data_sram_rdata),
    .MEM_wr_bus(MEM_wr_bus),
    .MEM_ex(MEM_ex),
    .MEM_ertn(MEM_ertn),
    .MEM_to_csr_bus(MEM_to_csr_bus),
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush)
    );
    WB u_WB(
    .clk(clk),
    .resetn(resetn),
    .WB_allow_in(WB_allow_in),
    .MEM_to_WB_valid(MEM_to_WB_valid),
    .MEM_to_WB_bus(MEM_to_WB_bus),
    .WB_to_ID_bus(WB_to_ID_bus),
    .debug_wb_pc(debug_wb_pc),
    .debug_wb_rf_we(debug_wb_rf_we),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .csr_we(csr_we),              //дʹ��
    .csr_num(csr_num),      //�Ĵ�����(д)
    .csr_wmask(csr_wmask),    //д����
    .csr_wvalue(csr_wvalue),   //д����
    .wb_ex(wb_ex),               //�쳣�������ź�
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .WB_pc(WB_pc),
    .ertn_flush(ertn_flush),
    .WB_to_csr_bus(WB_to_csr_bus)
    );
    
    csr u_csr(
    .clk(clk),
    .resetn(resetn),
    .csr_we(csr_we),              //дʹ��
    .csr_num(csr_num),      //�Ĵ�����(д)
    .csr_wmask(csr_wmask),    //д����
    .csr_wvalue(csr_wvalue),   //д����
    .csr_raddr(csr_raddr),    //����ַ
    .csr_rvalue(csr_rvalue),  //������
    .ex_entry(ex_entry),    //�жϳ�����ڵ�ַ
    .ex_exit(ex_exit),     //�жϳ����˳���ַ
    .ertn_flush(ertn_flush),          //ertnָ��ִ�е���Ч�ź�
    .has_int(has_int),            //�ж���Ч�ź�
    .wb_ex(wb_ex),               //�쳣�������ź�
    .wb_ecode(wb_ecode),
    .wb_esubcode(wb_esubcode),
    .WB_pc(WB_pc)
    );
//wire        load_op;

endmodule
