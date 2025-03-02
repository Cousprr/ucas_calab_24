module EXE(
    input  wire        clk,
    input  wire        resetn,
    //from ID
    output wire EXE_allow_in,
    input wire ID_to_EXE_valid,
    input wire [186:0] ID_to_EXE_bus,//��λ��
    //to MEM
    output wire EXE_to_MEM_valid,
    input wire MEM_allow_in,
    output wire [102:0] EXE_to_MEM_bus,
    // to data sram interface
    output wire        data_sram_en,
    output wire [3 :0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    //�ж����� EXEд�ź�
    output wire  [38:0]EXE_wr_bus
    );

    wire    [18:0]  alu_op;//������ǰ
    
    //�з��ų�
    wire [31:0] div_src1;//�з��ų� ������
    wire [31:0] div_src2;//�з��ų� ����
    wire div_src1_ready;
    wire div_src2_ready;
    wire div_src1_valid;
    wire div_src2_valid;
    reg div_src1_flag;//Ϊ1ʱ��ʾ�ɹ����͡�����������ɺ�����
    reg div_src2_flag;
    wire [63:0] div_res;//�з��ų� ���
    wire [31:0] div_res_remainder;//����
    wire [31:0] div_res_quotient;//��
    wire div_out_valid;//�з��ų� ����ֵ��Ч
    
    //�޷��ų�
    wire [31:0] divu_src1;//�޷��ų� ������
    wire [31:0] divu_src2;//�޷��ų� ����
    wire divu_src1_ready;
    wire divu_src2_ready;
    wire divu_src1_valid;
    wire divu_src2_valid;
    reg divu_src1_flag;//Ϊ1ʱ��ʾ�ɹ����͡�����������ɺ�����
    reg divu_src2_flag;
    wire [63:0] divu_res;//�޷��ų� ���
    wire [31:0] divu_res_remainder;//����
    wire [31:0] divu_res_quotient;//��
    wire divu_out_valid;//�޷��ų� ����ֵ��Ч
    
    //inside EXE
    reg EXE_valid;
    wire EXE_ready_go;
    //assign EXE_ready_go = 1'b1;    
    assign EXE_ready_go = (alu_op[15] | alu_op[17]) & div_out_valid | //�з��ų�+�������׼����
                          (alu_op[16] | alu_op[18]) & divu_out_valid | //�޷��ų�+�������׼����
                          (~(alu_op[15] | alu_op[16] | alu_op[17] | alu_op[18]));//�ǳ�������Ϊ1
    
    wire [31:0] EXE_inst;
    wire [31:0] EXE_pc;
    assign EXE_to_MEM_valid = EXE_ready_go & EXE_valid;
    assign EXE_allow_in = EXE_to_MEM_valid & MEM_allow_in | ~EXE_valid;
    
    always @(posedge clk)begin
        if(~resetn)begin
            EXE_valid <= 1'b0;
        end
        else if(EXE_allow_in)begin
            //EXE_valid <= 1'b1;
            EXE_valid <= ID_to_EXE_valid;
        end
    end  

    //reg [63:0] ID_to_EXE_bus_valid;����3 λ�����
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
    
    assign{alu_op, alu_src1, alu_src2, 
           res_from_mem, gr_we, mem_we, dest,
           rkd_value,
           EXE_pc, EXE_inst} = ID_to_EXE_bus_valid;
   
    wire [31:0] alu_result;
    wire [31:0] exe_result;//exp10 added
    alu u_alu(
     .alu_op     (alu_op    ),
     .alu_src1   (alu_src1  ),//�޸�����
     .alu_src2   (alu_src2  ),
     .alu_result (alu_result)
     ); 
    assign data_sram_en = 1'b1;//added
    //assign data_sram_we    = 4{mem_we};
    assign data_sram_we    = {4{mem_we}};
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = rkd_value;
    
    assign EXE_to_MEM_bus ={exe_result,
                           res_from_mem, gr_we, dest, 
                           EXE_pc, EXE_inst};//alu_result ��Ϊ exe_result 
//�����exp7�Ķ�
    wire EXE_write;
    assign EXE_write = EXE_valid & gr_we;
    wire EXE_load;
    assign EXE_load = EXE_valid & res_from_mem;
    assign EXE_wr_bus = {EXE_write,EXE_load,dest, exe_result};//alu_result ��Ϊ exe_result 

//exp10 �������    
//by wjr start
//�з��ų�
    //flag�źű�ʾ�Ƿ��Ѹ������������˲�������ȷ�������������ظ����յ�ͬһ��������
    always @(posedge  clk) begin
        if (~resetn) begin
            div_src1_flag <= 1'b0;
        end
        else if (div_src1_valid & div_src1_ready) begin
            div_src1_flag <= 1'b1;//�������Ѿ������˵�һ��������
        end
        else if (EXE_ready_go & MEM_allow_in) begin
            div_src1_flag <= 1'b0;//��������׼�����Ͳ�������������һ�γ�������
        end
    end
    assign div_src1_valid = (alu_op[15] | alu_op[17]) & EXE_valid & ~div_src1_flag;//����������źš���Ҫִ�г��������Ҳ�����δ����ʱ����1
    
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
    assign div_res = {div_res_remainder, div_res_quotient};

//�޷��ų�    
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
    assign divu_res = {divu_res_remainder, divu_res_quotient};
    
    assign exe_result = alu_op[15] ? div_res_remainder :
                        alu_op[17] ? div_res_quotient :
                        alu_op[16] ? divu_res_remainder :
                        alu_op[18] ? divu_res_quotient :
                                     alu_result;
    
//by wjr end

endmodule
