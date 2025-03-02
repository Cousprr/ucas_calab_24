//exc types    
    `define TYPE_SYS    0//ϵͳ��������
    `define TYPE_ADEF   1//ȡָ��ַ������
    `define TYPE_ALE    2//��ַ�Ƕ�������
    `define TYPE_BRK    3//�ϵ�����
    `define TYPE_INE    4//ָ���������
    `define TYPE_INT    5//�ж�
    //exp19 add 
    `define TYPE_ADEM    6//�ô�ָ���ַ������
    `define TYPE_TLBRF   7//TLB�������� TLBR_fetch,from IF
    `define TYPE_PIL     8//load����ҳ��Ч����
    `define TYPE_PIS     9//store����ҳ��Ч����
    `define TYPE_PIF     10//ȡָ����ҳ��Ч����
    `define TYPE_PME     11//ҳ�޸�����
    `define TYPE_PPIF    12//ҳ��Ȩ�ȼ����Ϲ����� PPI_fetch,from IF
    `define TYPE_TLBRM   13//TLB�������� TLBR_memory,from EXE
    `define TYPE_PPIM    14//ҳ��Ȩ�ȼ����Ϲ����� PPI_memory,from EXE

module IF(
    input  wire        clk,
    input  wire        resetn,
    //to ID
    input wire ID_allow_in,//ID������������
    output wire IF_to_ID_valid,//IF���������������ȷ���
    output wire [78:0] IF_to_ID_bus,//IF_EXC_TYPE & pc & instruction  //exp19 add 9bit
    input wire  [33:0] ID_to_IF_bus,//br_stall & br_taken & br_target
    
    //to ָ��Ĵ���
    output wire [31:0] inst_sram_addr,//�ô�����ĵ�ַ
    output wire [31:0] inst_sram_wdata,//�ô�����д������
    input  wire [31:0] inst_sram_rdata,//�ô����󷵻ص�����
    output wire        inst_sram_req,//�����źţ���1ʱ��ʾ�ж�д����
    output wire        inst_sram_wr,//дʹ���źţ���1ʱ��ʾ�ô�����Ϊд
    output wire [1 :0] inst_sram_size,//�ô���������ֽ�����0��1byte,1��2bytes,2��4bytes
    output wire [3 :0] inst_sram_wstrb,//equal as we
    input wire         inst_sram_addr_ok,//��ʾ�ô�����ĵ�ַ���� OK��������ַ������ɣ�д����ַ�����ݾ��������
    input wire         inst_sram_data_ok,//�ô���������� OK������ϣ���������ݷ��أ�д������д�����
    
    //csr
    input wire wb_ex,
    input wire ertn_flush,
    input [31:0] ex_entry,
    input [31:0] ex_exit,
    
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
    
    input wire [ 5:0] s0_ps,
    input wire [19:0] s0_ppn,
    input wire s0_found,
    input wire s0_v,
    input wire [1:0] s0_plv,
    output wire [18:0] s0_vppn,
    output wire s0_va_bit12,
        
    input  wire flush,
    input  wire [31:0] flush_pc
    );
    
    //for pc
    reg [31:0] IF_pc;
    //wire [31:0] IF_nextpc;
    //wire [31:0] IF_seq_pc;
    //for instruction
    wire [31:0] IF_inst;
    //if branch
    wire br_taken;
    wire br_stall;
    wire [31:0] br_target;
    //for buffer
    reg         buffer_valid;
    reg         inst_cancel;
    reg  [31:0] buffer;
//change exp14
    wire pre_ready_go;//ȡֵ��ַ����
    reg pre_valid;//Ԥȡָ����Ч
    wire pre_if_valid;//pre����IF��ָ����Ч
    wire fs_to_valid;//cancel��pre�����쳣���ж�Ҫ�����ˮ��
    reg IF_valid;//IF������Ч
    wire IF_allow_in;//IF������������
    wire IF_ready_go;//IF������Ч���ɽ����¸��׶�
    //for pre_IF
    
    
    assign {br_stall, br_taken, br_target} = ID_to_IF_bus;

     always @(posedge clk) begin
        if(~resetn)begin
            pre_valid <= 1'b0;
        end
        else begin
            pre_valid <= 1'b1;//pre_allow_in always 1'b1
        end
    end
    assign pre_if_valid = pre_valid & pre_ready_go;  
    assign pre_ready_go = inst_sram_req & inst_sram_addr_ok
                        // & ~(wb_ex||ertn_flush||br_stall||((ertn_reg ||exc_reg||stall_reg) & inst_cancel));//exp16
                           & ~(flush || br_stall||((flush_reg || stall_reg) & inst_cancel));//exp19 change
      
    //for pc choose
    wire    [31:0]                  pf_seqpc;
    wire    [31:0]                  pf_nextpc;
    reg     [31:0]                  pf_pc;
    assign  pf_nextpc = flush                ? flush_pc      : //exp19 change     flush:��ǰ����Ҫ�������ˮ��
                         flush_reg            ? flush_pc_reg  : //exp19 change     flush_reg:ǰ����ˮ���в�������������ӳٴ���(�Ĵ�)
                         br_reg               ? br_target_reg :
                         br_taken & ~br_stall ? br_target     :
                                                pf_seqpc;
    assign  pf_seqpc = pf_pc + 3'h4;
    
    always @(posedge clk) begin
        if(~resetn)begin
            pf_pc <= 32'h1bfffffc;
        end
        else if(pre_ready_go & IF_allow_in)begin
            pf_pc <= pf_nextpc;
        end
    end
    //�жϷ��ء��ж��������ת�ĵ�ַ
    reg                             br_reg;
    reg     [31:0]                  br_target_reg;
    reg                             stall_reg;//exp16
    //�����ź�
    always @(posedge clk) begin
        if(~resetn)begin
            br_reg <= 1'b0;
            stall_reg <= 1'b0;//exp16
        end
        else if(br_stall)begin
            stall_reg <= 1'b1;//exp16
        end
        else if(~br_stall & br_taken)begin
            br_reg <= 1'b1;
        end
        else if(inst_sram_addr_ok & IF_allow_in & ~inst_cancel)begin//exp15
            br_reg <= 1'b0;
            stall_reg <= 1'b0;//exp16
        end
    end

    //exp19 change    
    reg  flush_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            flush_reg <= 1'b0;
        end else if (flush) begin
            flush_reg <= 1'b1;
        end else if (inst_sram_addr_ok & IF_allow_in & ~inst_cancel) begin
            flush_reg <= 1'b0;
        end
    end   
    
    //��ַ��Ϣ
    always @(posedge clk) begin
        if(~resetn)begin
            br_target_reg <= 32'b0;
        end
        else if(~br_stall & br_taken)begin
            br_target_reg <= br_target;
        end
        else if(inst_sram_addr_ok & IF_allow_in & ~inst_cancel)begin
            br_target_reg <= 32'b0;
        end
    end

    //exp19 change    
    reg [31:0] flush_pc_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            flush_pc_reg <= 32'b0;
        end
        else if (flush) begin
            flush_pc_reg <= flush_pc;
        end
        else if (inst_sram_addr_ok & IF_allow_in & ~inst_cancel) begin
            flush_pc_reg <= 32'b0;
        end
    end                   
    
    //instruction
    assign  inst_sram_req = pre_valid & IF_allow_in & ~inst_cancel;
    //assign  inst_sram_addr = pf_nextpc;
    assign inst_sram_addr = (csr_crmd_da & ~csr_crmd_pg) ? pf_nextpc :     //ֱ�ӵ�ַ����  da��ֱ�ӵ�ַ����ʹ�ܣ�=1��pg��ӳ���ַ����ʹ�ܣ�=0
                             pf_dmw0_hit                  ? pf_dmw0_paddr : //ӳ���ַ����-ֱ��ӳ��
                             pf_dmw1_hit                  ? pf_dmw1_paddr : //ӳ���ַ����-ֱ��ӳ��
                                                            pf_tlb_paddr;   //ӳ���ַ����-ҳ��ӳ��  exp19 change
    assign  inst_sram_size = 2'h2;
    assign  inst_sram_wstrb = 4'b0;
    assign  inst_sram_wdata = 32'b0;
    assign  inst_sram_wr = 1'b0;

    //inst_cancel flush���ڱ�������ʱ����pc��ָ���ͬ�����
    always @(posedge clk) begin
        if(~resetn)begin
            inst_cancel <= 1'b0;
        end
        //else if(((br_taken & ~br_stall) | wb_ex | ertn_flush) & ~IF_ready_go & ~IF_allow_in)begin
        else if(inst_sram_req && (flush | (br_stall & inst_sram_addr_ok)))begin//exp19 change flush   //exp15
            inst_cancel <= 1'b1;
        end
        else if(inst_sram_data_ok)begin
            inst_cancel <= 1'b0;
        end
    end

//exp19 add start
    //��ʵ��ַת��
    wire    pf_dmw0_hit;
    wire    pf_dmw1_hit;
    wire    [31:0]  pf_dmw0_paddr;
    wire    [31:0]  pf_dmw1_paddr;
    wire    [31:0]  pf_tlb_paddr;
    wire    use_tlb;
    assign pf_dmw0_hit = (pf_nextpc[31:29] == csr_dmw0_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw0_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw0_plv3);
    assign pf_dmw1_hit = (pf_nextpc[31:29] == csr_dmw1_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw1_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw1_plv3);
    //pf_dmw0/1_hit������ַ�Ƿ�����ֱ��ӳ�䴰��DMW0/1
    //vseg:ֱ��ӳ�䴰�ڵ����ַ��[31:29]λ   plv:��Ȩ�ȼ�  dmw0/1_plv0/3Ϊ1:�ڶ�Ӧ��Ȩ�ȼ��¿�ʹ�øô��ڵ����ý���ֱ�ӵ�ַӳ�䷭��
    assign pf_dmw0_paddr = {csr_dmw0_pseg, pf_nextpc[28:0]};//pseg:ֱ��ӳ�䴰�ڵ������ַ��[31:29]λ
    assign pf_dmw1_paddr = {csr_dmw1_pseg, pf_nextpc[28:0]};
    //pf_dmw0/1_paddr��ֱ��ӳ�䴰������ʱ����������ַ��
    assign pf_tlb_paddr = (s0_ps == 6'd21) ? {s0_ppn[19:9], pf_nextpc[20:0]} : {s0_ppn, pf_nextpc[11:0]};
    //pf_tlb_paddr��ͨ��TLB����������ַ������ҳ���С(s0_ps)����ƴ�ӡ�s0_ppn:����ҳ��
    assign use_tlb = ~csr_crmd_da & csr_crmd_pg & ~pf_dmw0_hit & ~pf_dmw1_hit;//da=0, pg=1, pf_dmw0_hit=0, pf_dmw1_hit=0
    //ָʾ�Ƿ���Ҫͨ��TLB���е�ַת����da��ֱ�ӵ�ַ����ʹ�ܣ�=0��pg��ӳ���ַ����ʹ�ܣ�=1��ֱ��ӳ��δ����dmw0/1_hit=0
    assign {s0_vppn,s0_va_bit12}= pf_nextpc[31:12];//vppn���ô����ַ��31~13λ��va_bit12���ô����ַ��12λ
//exp19 add end

    //�жϺ��쳣
    wire [14:0] IF_exc_type;//exp19 add 9bit
    assign IF_exc_type[`TYPE_ADEF]  = ((|IF_pc[1:0])|(IF_pc[31] & csr_crmd_plv == 2'd3)) & ~pf_dmw0_hit & ~pf_dmw1_hit;//ȡָ��ַ�����⡣IF_pc�Ƕ�����û�̬���Ϸ����ʣ��ҵ�ַδ����DMW����
    //IF_pc[31] & csr_crmd_plv == 2'd3��������Ȩָ�����PLV0��Ȩ�ȼ��²��ܷ��ʡ�
    //assign IF_exc_type[`TYPE_ADEF] = |IF_pc[1:0];
    assign IF_exc_type[`TYPE_TLBRF] = use_tlb & ~s0_found;//TLB�������⡣��Ҫͨ��TLB���е�ַת������û���ҵ���ӦTLB�����TLBû����
    assign IF_exc_type[`TYPE_PIF]   = use_tlb & s0_found & ~s0_v;//ȡָ����ҳ��Ч���⡣��TLB���ҵ���ƥ�����ƥ��ҳ�����V=0    s0_v����Чλ
    assign IF_exc_type[`TYPE_PPIF]  = use_tlb & s0_found & s0_v & (csr_crmd_plv > s0_plv);//ҳ��Ȩ�ȼ����Ϲ����⡣�ô���������ַ��TLB���ҵ���ƥ����V=1������Ƿ��ʵ���Ȩ�ȼ����Ϲ�
                                                                                            //��Ȩ�ȼ����Ϲ棺��ҳ�����csr_crmd_plv(��ǰ��Ȩ�ȼ�)ֵ����ҳ�����е�PLV(��Ȩ�ȼ�)
    assign IF_exc_type[`TYPE_SYS]   = 1'b0;
    assign IF_exc_type[`TYPE_ALE]   = 1'b0;
    assign IF_exc_type[`TYPE_BRK]   = 1'b0;
    assign IF_exc_type[`TYPE_INE]   = 1'b0;
    assign IF_exc_type[`TYPE_INT]   = 1'b0;
    assign IF_exc_type[`TYPE_PPIM]  = 1'b0;
    assign IF_exc_type[`TYPE_PME]   = 1'b0;
    assign IF_exc_type[`TYPE_PIL]   = 1'b0;
    assign IF_exc_type[`TYPE_PIS]   = 1'b0;
    assign IF_exc_type[`TYPE_ADEM]  = 1'b0;
    assign IF_exc_type[`TYPE_TLBRM] = 1'b0;

    //assign  IF_inst = inst_sram_rdata;
    
//for IF
    assign IF_ready_go = inst_sram_data_ok & IF_valid | buffer_valid;
    assign IF_allow_in = IF_ready_go & ID_allow_in | ~IF_valid;
    assign IF_to_ID_valid = IF_ready_go & IF_valid & ~is_ertn_or_exc ;
    always @(posedge clk) begin
         if(~resetn)begin
            IF_valid <= 1'b0;
        end
        else if(IF_allow_in)begin
            IF_valid <= pre_if_valid;
        end
    end
    
//exp15
//exp19 change
    reg if_flush_reg;
    always @(posedge clk) begin
        if(~resetn)begin
            if_flush_reg <= 1'b0;
        end
        else if (flush) begin
            if_flush_reg <= 1'b1;
        end
        else if (IF_allow_in & pre_if_valid)begin
            if_flush_reg <= 1'b0;
        end
    end                     

    wire is_ertn_or_exc;
//    assign is_ertn_or_exc = wb_ex | ertn_flush | if_ertn_reg | if_exc_reg;
    assign is_ertn_or_exc = flush | if_flush_reg;//exp19 change
//exp15 end

    always @(posedge clk) begin
        if(~resetn)begin
            IF_pc <= 32'b0;
        end
        else if(pre_if_valid & IF_allow_in)begin
            IF_pc <= pf_nextpc;
        end
    end

/*exp12
    assign IF_to_ID_bus = {IF_EXC_TYPE ,IF_pc , IF_inst};
    assign {br_stall, br_taken , br_target} = ID_to_IF_bus;
    assign IF_seq_pc = IF_pc + 3'h4;
    assign IF_nextpc = IF_nextpc_ready_go & (br_taken ? br_target : IF_seq_pc);
*/

    //������buffer
    assign IF_inst = buffer_valid ? buffer : inst_sram_rdata;

    always @(posedge clk) begin
        if(~resetn)begin
            buffer_valid <= 1'b0;
        end
        else if(inst_sram_data_ok & ~buffer_valid & ~is_ertn_or_exc & ~ID_allow_in)begin
            buffer_valid <= 1'b1;
        end
        else if(ID_allow_in | is_ertn_or_exc)begin//exp16
            buffer_valid <= 1'b0;
        end
    end
    always @(posedge clk) begin
        if(~resetn)begin
            buffer <= 32'b0;
        end
        else if(inst_sram_data_ok & ~buffer_valid & ~is_ertn_or_exc & ~ID_allow_in)begin
            buffer <= inst_sram_rdata;
        end
        else if(ID_allow_in | is_ertn_or_exc) begin//exp16
            buffer <= 32'b0;
        end
    end

    assign IF_to_ID_bus = {IF_exc_type, IF_pc, IF_inst};//exp19 IF_exc_type add 9bit

endmodule
