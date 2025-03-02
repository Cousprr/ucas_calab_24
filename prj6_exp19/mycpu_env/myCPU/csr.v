    `define CSR_CRMD    14'h000
    `define CSR_PRMD    14'h001
    `define CSR_ESTAT   14'h005
    `define CSR_ERA     14'h006
    `define CSR_EENTRY  14'h00c
    `define CSR_SAVE0   14'h030
    `define CSR_SAVE1   14'h031
    `define CSR_SAVE2   14'h032
    `define CSR_SAVE3   14'h033
    `define CSR_ECFG    14'h004
    `define CSR_BADV    14'h007
    `define CSR_TID     14'h040
    `define CSR_TCFG    14'h041
    `define CSR_TVAL    14'h042
    `define CSR_TICLR   14'h044
    //exp19
    `define CSR_DMW0    14'h180
    `define CSR_DMW1    14'h181
    
    `define CSR_CRMD_PLV 1:0
    `define CSR_PRMD_PPLV 1:0
    `define CSR_CRMD_PIE 2
    `define CSR_PRMD_PIE 2
    `define CSR_ECFG_LIE 12:0
    `define CSR_ESTAT_IS10 1:0
    `define CSR_ERA_PC  31:0
    `define CSR_EENTRY_VA 31:6
    `define CSR_SAVE_DATA 31:0
    
    //exp13
    `define CSR_TICLR_CLR    0//CLR���λ��Χ
    `define CSR_TCFG_EN      0//EN���λ��Χ
    `define CSR_TCFG_PERIOD  1//PERIODIC���λ��Χ
    `define CSR_TCFG_INITVAL 31:2//[31:n]ֻ����д����n��ȷ��������λ��Ϊ[31:2]����ǰ��д0
    `define CSR_TID_TID     31:0//TID���λ��Χ
    //exp19
    //DMW0DMW1
    `define CSR_DMW_PLV0    0
    `define CSR_DMW_PLV3    3
    `define CSR_DMW_MAT     5:4
    `define CSR_DMW_PSEG    27:25
    `define CSR_DMW_VSEG    31:29
    //CRMD
    `define CSR_CRMD_IE     2
    `define CSR_CRMD_DA     3
    `define CSR_CRMD_PG     4
    `define CSR_CRMD_DATF   6:5
    `define CSR_CRMD_DATM   8:7
    
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
    `define EXC_ECODE_PPI   6'h07//PLV?

//esubcodes
    `define EXC_ESUBCODE_ADEF   9'h000
    //exp19
    `define EXC_ESUBCODE_ADEM   9'h001
    
    //tlb
    `define CSR_TLBIDX_INDEX 3:0
    `define CSR_TLBIDX_PS 29:24
    `define CSR_TLBIDX_NE 31
    `define CSR_TLBEHI_VPPN 31:13
    `define CSR_TLBELO_V 0
    `define CSR_TLBELO_D 1
    `define CSR_TLBELO_PLV 3:2
    `define CSR_TLBELO_MAT 5:4
    `define CSR_TLBELO_G 6
    `define CSR_TLBELO_PPN 31:8
    `define CSR_ASID_ASID 9:0
    `define CSR_TLBRENTRY_PA 31:6
    
    `define CSR_TLBIDX          14'h010
    `define CSR_TLBEHI          14'h011
    `define CSR_TLBELO0         14'h012
    `define CSR_TLBELO1         14'h013
    `define CSR_ASID            14'h018
    `define CSR_TLBRENTRY       14'h088

module csr(
    input wire clk,
    input wire resetn,

    //��ʹ��ʡ��
    input wire csr_we,              //дʹ��
    input wire [13:0] csr_num,      //�Ĵ�����(д)
    input wire [31:0] csr_wmask,    //д����
    input wire [31:0] csr_wvalue,   //д����

    input wire [13:0] csr_raddr,    //����ַ
    output wire [31:0] csr_rvalue,  //������

    output wire [31:0] ex_entry,    //�жϳ�����ڵ�ַ
    output wire [31:0] ex_exit,     //�жϳ����˳���ַ

    input wire ertn_flush,          //ertnָ��ִ�е���Ч�ź�
    output wire csr_has_int,            //�ж���Ч�ź�

    input wire wb_ex,               //�쳣�������ź�
    input wire [5:0] wb_ecode,
    input wire [8:0] wb_esubcode,
    input wire [31:0] WB_pc,
    input wire [31:0] wb_badvaddr,//WB��csrģ�鴫�ݳ���ķô�"��"��ַ
    
    output reg [3:0] csr_tlbidx_index, //tlb����ֵ
    output reg [18:0] csr_tlbehi_vppn, //tlb vppn
    output reg [9:0] csr_asid_asid,    //tlb asid

    input wire tlbrd_we,
    input wire tlbsrch_we,
    input wire tlbsrch_hit,
    input wire [3:0] tlb_hit_index,
    
    input wire r_tlb_e,
    input wire [5:0] r_tlb_ps,
    input wire [18:0] r_tlb_vppn,
    input wire [9:0] r_tlb_asid,
    input wire r_tlb_g,

    input wire [19:0] r_tlb_ppn0,
    input wire [1:0] r_tlb_plv0,
    input wire [1:0] r_tlb_mat0,
    input wire r_tlb_d0,
    input wire r_tlb_v0,
    input wire [19:0] r_tlb_ppn1,
    input wire [1:0] r_tlb_plv1,
    input wire [1:0] r_tlb_mat1,
    input wire r_tlb_d1,
    input wire r_tlb_v1,

    output wire w_tlb_e,
    output wire [5:0] w_tlb_ps,
    output wire [18:0] w_tlb_vppn,
    output wire [9:0] w_tlb_asid,
    output wire [1:0] w_tlb_g,

    output wire [19:0]w_tlb_ppn0,
    output wire [1:0] w_tlb_plv0,
    output wire [1:0] w_tlb_mat0,
    output wire w_tlb_d0,
    output wire w_tlb_v0,
    output wire [19:0]w_tlb_ppn1,
    output wire [1:0] w_tlb_plv1,
    output wire [1:0] w_tlb_mat1,
    output wire w_tlb_d1,
    output wire w_tlb_v1,

    input  [14:0]   WB_ex_type,//exp19 add 9bit
    input           refetch,
    output          flush,
    output [31:0]   flush_pc,

    output reg [ 1:0] csr_crmd_plv,//��ǰ��Ȩ�ȼ�
    output reg        csr_crmd_da,//ֱ�ӵ�ַ����ģʽ��ʹ��
    output reg        csr_crmd_pg,//ӳ���ַ����ģʽ��ʹ��
    
    output reg        csr_dmw0_plv0,//����Ȩ�ȼ� PLV0 �¿���ʹ�øô��ڵ����ý���ֱ��ӳ���ַ����
    output reg        csr_dmw0_plv3,//����Ȩ�ȼ� PLV3 �¿���ʹ�øô��ڵ����ý���ֱ��ӳ���ַ����
    output reg [ 1:0] csr_dmw0_mat, //���ַ���ڸ�ӳ�䴰���·ô�����Ĵ洢��������
    output reg [ 2:0] csr_dmw0_pseg,//ֱ��ӳ�䴰��-�����ַ��[31:29]λ
    output reg [ 2:0] csr_dmw0_vseg,//ֱ��ӳ�䴰��-���ַ��[31:29]λ

    output reg        csr_dmw1_plv0,//����Ȩ�ȼ� PLV0 �¿���ʹ�øô��ڵ����ý���ֱ��ӳ���ַ����
    output reg        csr_dmw1_plv3,//����Ȩ�ȼ� PLV3 �¿���ʹ�øô��ڵ����ý���ֱ��ӳ���ַ����
    output reg [ 1:0] csr_dmw1_mat, //���ַ���ڸ�ӳ�䴰���·ô�����Ĵ洢��������
    output reg [ 2:0] csr_dmw1_pseg,//ֱ��ӳ�䴰��-�����ַ��[31:29]λ
    output reg [ 2:0] csr_dmw1_vseg //ֱ��ӳ�䴰��-���ַ��[31:29]λ
);

    assign flush = wb_ex | refetch | ertn_flush;//exp19   �����ˮ�ߣ����쳣���������ȡָ�����ı�־
    assign flush_pc = wb_ex       ? ex_entry :         //�жϳ�����ڵ�ַ    wb_ex:�쳣�������ź�
                       refetch     ? (WB_pc + 32'h4) : //refetch:֧���ض����������ȡָ�refetch������ָ����ܵ���csr��д��ͻ����Ҫ�ڵ���WB��ʱ����ˮ�����  ѡ����һ��
                      /*ertn_flush*/ ex_exit;          //�жϳ����˳���ַ    ertn_flush:"�����⴦����"ָ��ִ�е���Ч�ź�
                                             //exp19 change   ��תĿ���ַ������һ�׶δ��ĸ���ַ����ȡָ

//CRMD
    //CRMD-PLV
    reg [1:0] csr_crmd_plv;
    reg [1:0] csr_prmd_pplv;
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_plv <= 2'b0;
        else if (wb_ex)
            csr_crmd_plv <= 2'b0;
        else if (ertn_flush)
            csr_crmd_plv <= csr_prmd_pplv;
        else if (csr_we && csr_num ==`CSR_CRMD)
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]| ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
    end

    //CRMD-IE
    reg csr_crmd_ie;
    reg csr_prmd_pie;
    always @(posedge clk) begin
        if (~resetn)
            csr_crmd_ie <= 1'b0;
        else if (wb_ex)
            csr_crmd_ie <= 1'b0;
        else if (ertn_flush)
            csr_crmd_ie <= csr_prmd_pie;
        else if (csr_we && csr_num ==`CSR_CRMD)
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_PIE]&csr_wvalue[`CSR_CRMD_PIE]| ~csr_wmask[`CSR_CRMD_PIE]&csr_crmd_ie;
    end

//exp16 change start
    reg csr_crmd_da;
    reg csr_crmd_pg;
    reg [1:0] csr_crmd_datf;//ֱ�ӵ�ַ����ģʽʱ��ȡָ�����Ĵ洢�������͡�
    reg [1:0] csr_crmd_datm;//ֱ�ӵ�ַ����ģʽʱ��load �� store �����Ĵ洢�������͡�
    //assign csr_crmd_da = 1'b1;
    //assign csr_crmd_pg = 1'b0;
    //assign csr_crmd_datf = 2'b00;
    //assign csr_crmd_datm = 2'b00;
//exp16 change end

//exp19 change start
    //CRMD-DA,CRMD-PG
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
        end 
        else if (wb_ex && wb_ecode == `EXC_ECODE_TLBR) begin//wb_ex:�쳣�������ź�
            csr_crmd_da <= 1'b1;//ֱ�ӵ�ַ����ģʽ��ʹ�ܡ������� TLB ��������ʱ��Ӳ����������Ϊ1��
            csr_crmd_pg <= 1'b0;//ӳ���ַ����ģʽ��ʹ�ܡ������� TLB ��������ʱ��Ӳ����������Ϊ0��
        end 
        else if (ertn_flush && csr_estat_ecode == `EXC_ECODE_TLBR) begin//ertn_flush:"�����⴦����"ָ��ִ�е���Ч�ź�
            csr_crmd_da <= 1'b0;//��ִ�� ERTN ָ������⴦����򷵻�ʱ����� csr_estat_ecode=0x3F����Ӳ����������Ϊ 0��
            csr_crmd_pg <= 1'b1;//��ִ�� ERTN ָ������⴦����򷵻�ʱ����� csr_estat_ecode=0x3F����Ӳ����������Ϊ 1��
        end 
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wvalue[`CSR_CRMD_DA] | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wvalue[`CSR_CRMD_PG] | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
        end
    end

    //CRMD-DATF,CRMD-DATM
    always @(posedge clk) begin
        if (~resetn) begin
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end 
        else if (csr_we && csr_num == `CSR_CRMD) begin
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF] & csr_wvalue[`CSR_CRMD_DATF] | ~csr_wmask[`CSR_CRMD_DATF] & csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM] & csr_wvalue[`CSR_CRMD_DATM] | ~csr_wmask[`CSR_CRMD_DATM] & csr_crmd_datm;
        end
    end
//exp19 change end
    
    wire [31:0] csr_crmd_rvalue;
    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    
//PRMD  
    
    //PRMD-PPLV,PIE
    always @(posedge clk) begin
        if (~resetn) begin
            csr_prmd_pplv <= 2'b0;
            csr_prmd_pie <= 1'b0;
        end
        else if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_num ==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV] | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE] | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
        end
    end
    wire [31:0] csr_prmd_rvalue;
    assign  csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};

//for exp13
//ECFG
    //ECFG-LIE
    reg     [12:0]  csr_ecfg_lie;
    always @(posedge clk) begin
        if (~resetn)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num ==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&csr_wvalue[`CSR_ECFG_LIE] | ~csr_wmask[`CSR_ECFG_LIE]&csr_ecfg_lie;
    end
    wire [31:0] csr_ecfg_rvalue;
    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie[12:11], 1'b0, csr_ecfg_lie[9:0]};


//ESTAT
    //ESTAT-IS
    reg [12:0] csr_estat_is;
    always @(posedge clk) begin
        if (~resetn)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num ==`CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10] | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
        csr_estat_is[9:2] <= 8'b0;
        //csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[12] <= 1'b0;
        csr_estat_is[10] <= 1'b0;
        //if(~resetn)
        //    csr_estat_is[11] <= 1'b0;
        //else                                   //exp16 change
        if (csr_tcfg_en && timer_cnt[31:0] == 32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && (csr_num == `CSR_TICLR) && (csr_wmask[`CSR_TICLR_CLR]) && (csr_wvalue[`CSR_TICLR_CLR]))
            csr_estat_is[11] <= 1'b0;//���ͨ����CLRд1����estatis��ʮһλ����
        
        
        //csr_estat_is[12] <= ipi_int_in;
    end
    
    //ESTAT-Ecode Esubcode
    reg     [ 5:0]  csr_estat_ecode;
    reg     [ 8:0]  csr_estat_esubcode;
    always @(posedge clk) begin
        if (~resetn) begin
            csr_estat_ecode <= 6'b0;
            csr_estat_esubcode <= 9'b0;
        end 
        else if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
    
    wire [31:0] csr_estat_rvalue;
    assign csr_estat_rvalue = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is };


//ERA
    //ERA-PC
    reg [31:0] csr_era_pc;
    always @(posedge clk) begin
        if (~resetn)
            csr_era_pc <= 32'h0;
        else if (wb_ex)
            csr_era_pc <= WB_pc;
        else if (csr_we && csr_num ==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC] | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
    
    wire [31:0] csr_era_rvalue;
    assign  csr_era_rvalue = csr_era_pc;

//EENTRY
    //EENTRY-VA
    reg [25:0] csr_eentry_va;
    always @(posedge clk) begin
        if (~resetn)
            csr_eentry_va <= 26'h0;
        else if (csr_we && csr_num ==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA] | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end

    wire [31:0] csr_eentry_rvalue;
    assign  csr_eentry_rvalue = { csr_eentry_va, 6'b0 };


//SAVE 0-3
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    wire [31:0] csr_save0_rvalue;
    wire [31:0] csr_save1_rvalue;
    wire [31:0] csr_save2_rvalue;
    wire [31:0] csr_save3_rvalue;
    always @(posedge clk) begin
        if (~resetn) begin
            csr_save0_data <= 32'h0;
            csr_save1_data <= 32'h0;
            csr_save2_data <= 32'h0;
            csr_save3_data <= 32'h0;
        end
        else begin
            if (csr_we && csr_num ==`CSR_SAVE0)
                csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
            if (csr_we && csr_num ==`CSR_SAVE1)
                csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
            if (csr_we && csr_num ==`CSR_SAVE2)
                csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
            if (csr_we && csr_num ==`CSR_SAVE3)
                csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA] | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
        end
    end
    assign { csr_save0_rvalue, csr_save1_rvalue, csr_save2_rvalue, csr_save3_rvalue } = { csr_save0_data,  csr_save1_data,  csr_save2_data,  csr_save3_data };

    
//exp13 add start
    //TCFG
    reg         csr_tcfg_en;
    reg         csr_tcfg_periodic;
    reg  [29:0] csr_tcfg_initval;
    wire [31:0] csr_tcfg_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tcfg_en <= 1'b0;
            //csr_tcfg_periodic <= 1'b0;//exp16
            //csr_tcfg_initval <= 30'b0;//exp16
        end 
        else if (csr_we && csr_num == `CSR_TCFG) begin
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wvalue[`CSR_TCFG_EN] | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wvalue[`CSR_TCFG_PERIOD] | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
            csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wvalue[`CSR_TCFG_INITVAL] | ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
        end
    end
    assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    //TVAL
    wire [31:0] tcfg_next_data;
    wire [31:0] csr_tval_rvalue;
    reg  [31:0] timer_cnt;
    assign      tcfg_next_data = csr_wmask & csr_wvalue |~csr_wmask & csr_tcfg_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            timer_cnt <= 32'hffffffff;
        end 
        else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_data[`CSR_TCFG_EN]) begin
            timer_cnt <= {tcfg_next_data[`CSR_TCFG_INITVAL], 2'b0};
        end 
        else if (csr_tcfg_en && timer_cnt != 32'hffffffff) begin
            if (timer_cnt == 32'b0 && csr_tcfg_periodic) begin
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            end 
            else begin
                timer_cnt <= timer_cnt - 1'b1;
            end
        end
    end
    assign csr_tval_rvalue = timer_cnt;
    
    //TICLR
    wire    [31:0] csr_ticlr_rvalue;
    assign  csr_ticlr_rvalue = 32'b0;

    //TID
    reg     [31:0] csr_tid_tid;
    wire    [31:0] csr_tid_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tid_tid <= 32'b0;
        end else if (csr_we && csr_num == `CSR_TID) begin
            csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wvalue[`CSR_TID_TID]
                       | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
        end
    end
    assign  csr_tid_rvalue = csr_tid_tid;
    
    //exp19 add
    assign  exc_pc = WB_ex_type[`TYPE_PIF] | WB_ex_type[`TYPE_PPIF] | 
                     WB_ex_type[`TYPE_ADEF]| WB_ex_type[`TYPE_TLBRF]; //ȡָ�׶μ���������
    assign  exc_data = WB_ex_type[`TYPE_ALE]  | WB_ex_type[`TYPE_PPIM] | 
                       WB_ex_type[`TYPE_PIL]  | WB_ex_type[`TYPE_PIS]   | 
                       WB_ex_type[`TYPE_TLBRM]| WB_ex_type[`TYPE_PME]   | 
                       WB_ex_type[`TYPE_ADEM];                         //�ô�׶μ���������
    
    //BADV
    reg  [31:0] csr_badv_vaddr;
    wire [31:0] csr_badv_rvalue;
    //wire wb_exc_addr_err;
    //assign wb_exc_addr_err = wb_ecode==`EXC_ECODE_ADE || wb_ecode==`EXC_ECODE_ALE;//�ж��Ƿ��ǵ�ַ�����������(ADEF/ALE)
    always @(posedge clk) begin
        if (~resetn) begin
            csr_badv_vaddr <= 32'b0;
        end 
    /*
        else if (wb_ex && wb_exc_addr_err) begin
            csr_badv_vaddr <= (wb_ecode==`EXC_ECODE_ADE && wb_esubcode==`EXC_ESUBCODE_ADEF) ? WB_pc : wb_badvaddr;//ADEF����:��¼�����PCֵ��ALE����:��¼����ķô�"��"��ַ
        end
    */
    //exp19 add start
        else if (wb_ex && exc_pc) begin//exc_pc��ȡָ�׶μ���������
            csr_badv_vaddr <= WB_pc;
        end 
        else if (wb_ex && exc_data) begin//exc_data:ִ�н׶μ���������
            csr_badv_vaddr <= wb_badvaddr;//��¼����ķô����ַ
        end
    //exp19 add end
    end

    assign csr_badv_rvalue = csr_badv_vaddr;
//exp13 add end

//TLB EXP18
    //TLBIDX
    reg [5:0] csr_tlbidx_ps;
    reg       csr_tlbidx_ne;
    wire [31:0] csr_tlbidx_rvalue;
    always @(posedge clk) begin
        if (~resetn) begin
            csr_tlbidx_ps <= 6'b0;
        end
        else if(tlbrd_we) begin
            csr_tlbidx_ps <= r_tlb_e ? r_tlb_ps : 6'b0;
        end
        else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wvalue[`CSR_TLBIDX_PS] | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            csr_tlbidx_ne <= 1'b0;
        end
        else if (tlbrd_we) begin
            csr_tlbidx_ne <= ~r_tlb_e;
        end
        else if (tlbsrch_we) begin
            csr_tlbidx_ne <= ~tlbsrch_hit;
        end
        else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wvalue[`CSR_TLBIDX_NE] | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
        end
    end
    always @(posedge clk) begin
        if (~resetn) begin
            csr_tlbidx_index <= 4'b0;
        end 
        else if (tlbsrch_we) begin
            csr_tlbidx_index <= tlbsrch_hit ? tlb_hit_index : csr_tlbidx_index;
        end 
        else if (csr_we && csr_num == `CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX] & csr_wvalue[`CSR_TLBIDX_INDEX] | ~csr_wmask[`CSR_TLBIDX_INDEX] & csr_tlbidx_index;
        end
    end
    assign w_tlb_e = ~csr_tlbidx_ne;
    assign w_tlb_ps = csr_tlbidx_ps;
    assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};

    //TLBEHI
    wire [31:0] csr_tlbehi_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbehi_vppn <= 19'b0;
        end
        else if (tlbrd_we) begin
            csr_tlbehi_vppn <= r_tlb_e ? r_tlb_vppn : 19'b0;
        end
    //exp19 add start
        else if (wb_ex && exc_pc && ~WB_ex_type[`TYPE_ADEF]) begin //����"ȡָ��ַ������"�����ȡָ�׶μ���������
            csr_tlbehi_vppn <= WB_pc[31:13];
        end 
        else if (wb_ex && exc_data && ~WB_ex_type[`TYPE_ALE] && ~WB_ex_type[`TYPE_ADEM]) begin //����"��ַ�Ƕ�������"��"�ô�ָ���ַ������"�����ִ�н׶μ���������
            csr_tlbehi_vppn <= wb_badvaddr[31:13];//��¼������������ַ��[31:13]λ
        end
    //exp19 add end 
        else if (csr_we && csr_num == `CSR_TLBEHI) begin
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wvalue[`CSR_TLBEHI_VPPN] | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
        end
    end
    assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
    assign w_tlb_vppn = csr_tlbehi_vppn;

    //TLBELO 0&1
    reg         csr_tlbelo0_v;
    reg         csr_tlbelo0_d;
    reg  [ 1:0] csr_tlbelo0_plv;
    reg  [ 1:0] csr_tlbelo0_mat;
    reg         csr_tlbelo0_g;
    reg  [23:0] csr_tlbelo0_ppn;
    wire [31:0] csr_tlbelo0_rvalue;
    reg         csr_tlbelo1_v;
    reg         csr_tlbelo1_d;
    reg  [ 1:0] csr_tlbelo1_plv;
    reg  [ 1:0] csr_tlbelo1_mat;
    reg         csr_tlbelo1_g;
    reg  [23:0] csr_tlbelo1_ppn;
    wire [31:0] csr_tlbelo1_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbelo0_v   <= 1'b0;
            csr_tlbelo0_d   <= 1'b0;
            csr_tlbelo0_plv <= 2'b0;
            csr_tlbelo0_mat <= 2'b0;
            csr_tlbelo0_g   <= 1'b0;
            csr_tlbelo0_ppn <= 24'b0;
        end 
        else if (tlbrd_we) begin
            csr_tlbelo0_v   <= r_tlb_e ? r_tlb_v0 : 1'b0;
            csr_tlbelo0_d   <= r_tlb_e ? r_tlb_d0 : 1'b0;
            csr_tlbelo0_plv <= r_tlb_e ? r_tlb_plv0 : 2'b0;
            csr_tlbelo0_mat <= r_tlb_e ? r_tlb_mat0 : 2'b0;
            csr_tlbelo0_g   <= r_tlb_e ? r_tlb_g : 1'b0;
            csr_tlbelo0_ppn <= r_tlb_e ? {4'b0, r_tlb_ppn0} : 24'b0;
        end 
        else if (csr_we && csr_num == `CSR_TLBELO0) begin
            csr_tlbelo0_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   | ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo0_v;
            csr_tlbelo0_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   | ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo0_d;
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo0_plv;
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo0_mat;
            csr_tlbelo0_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   | ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo0_g;
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo0_ppn;
        end
    end
    assign csr_tlbelo0_rvalue = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
    assign w_tlb_ppn0 = csr_tlbelo0_ppn[19:0];
    assign w_tlb_plv0 = csr_tlbelo0_plv;
    assign w_tlb_mat0 = csr_tlbelo0_mat;
    assign w_tlb_d0 = csr_tlbelo0_d;
    assign w_tlb_v0 = csr_tlbelo0_v;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbelo1_v   <= 1'b0;
            csr_tlbelo1_d   <= 1'b0;
            csr_tlbelo1_plv <= 2'b0;
            csr_tlbelo1_mat <= 2'b0;
            csr_tlbelo1_g   <= 1'b0;
            csr_tlbelo1_ppn <= 24'b0;
        end 
        else 
        if (tlbrd_we) begin
            csr_tlbelo1_v   <= r_tlb_e ? r_tlb_v1 : 1'b0;
            csr_tlbelo1_d   <= r_tlb_e ? r_tlb_d1 : 1'b0;
            csr_tlbelo1_plv <= r_tlb_e ? r_tlb_plv1 : 2'b0;
            csr_tlbelo1_mat <= r_tlb_e ? r_tlb_mat1 : 2'b0;
            csr_tlbelo1_g   <= r_tlb_e ? r_tlb_g : 1'b0;
            csr_tlbelo1_ppn <= r_tlb_e ? {4'b0, r_tlb_ppn1} : 24'b0;
        end 
        else if (csr_we&&csr_num == `CSR_TLBELO1) begin
            csr_tlbelo1_v   <= csr_wmask[`CSR_TLBELO_V]   & csr_wvalue[`CSR_TLBELO_V]   | ~csr_wmask[`CSR_TLBELO_V]   & csr_tlbelo1_v;
            csr_tlbelo1_d   <= csr_wmask[`CSR_TLBELO_D]   & csr_wvalue[`CSR_TLBELO_D]   | ~csr_wmask[`CSR_TLBELO_D]   & csr_tlbelo1_d;
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO_PLV] & csr_wvalue[`CSR_TLBELO_PLV] | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo1_plv;
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO_MAT] & csr_wvalue[`CSR_TLBELO_MAT] | ~csr_wmask[`CSR_TLBELO_MAT] & csr_tlbelo1_mat;
            csr_tlbelo1_g   <= csr_wmask[`CSR_TLBELO_G]   & csr_wvalue[`CSR_TLBELO_G]   | ~csr_wmask[`CSR_TLBELO_G]   & csr_tlbelo1_g;
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO_PPN] & csr_wvalue[`CSR_TLBELO_PPN] | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo1_ppn;
        end
    end
    assign csr_tlbelo1_rvalue = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
    assign w_tlb_g = csr_tlbelo0_g & csr_tlbelo1_g;
    assign w_tlb_ppn1 = csr_tlbelo1_ppn[19:0];
    assign w_tlb_plv1 = csr_tlbelo1_plv;
    assign w_tlb_mat1 = csr_tlbelo1_mat;
    assign w_tlb_d1 = csr_tlbelo1_d;
    assign w_tlb_v1 = csr_tlbelo1_v;

    //ASID
    wire [31:0] csr_asid_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_asid_asid <= 10'b0;
        end 
        else if (tlbrd_we) begin
            csr_asid_asid <= r_tlb_e ? r_tlb_asid : 10'b0;
        end 
        else if (csr_we && csr_num == `CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wvalue[`CSR_ASID_ASID] | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
        end
    end
    assign csr_asid_rvalue = {8'b0,8'd10,6'b0,csr_asid_asid};
    assign w_tlb_asid = csr_asid_asid;

    //TLBENTRY
    reg  [25:0] csr_tlbrentry_pa;
    wire [31:0] csr_tlbrentry_rvalue;
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_tlbrentry_pa <= 26'b0;
        end 
        else if (csr_we && csr_num == `CSR_TLBRENTRY) begin
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA] & csr_wvalue[`CSR_TLBRENTRY_PA] | ~csr_wmask[`CSR_TLBRENTRY_PA] & csr_tlbrentry_pa;
        end
    end
    assign csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'b0};

//exp19 add start
    //DMW0~DMW1 
    wire [31:0] csr_dmw0_rvalue;
    wire [31:0] csr_dmw1_rvalue;

    always @ (posedge clk) begin
        if (~resetn) begin
            csr_dmw0_plv0 <= 1'b0;
            csr_dmw0_plv3 <= 1'b0;
            csr_dmw0_mat  <= 2'b0;
            csr_dmw0_pseg <= 3'b0;
            csr_dmw0_vseg <= 3'b0;
        end 
        else if (csr_we && csr_num == `CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0] | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3] | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw0_plv3;
            csr_dmw0_mat  <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]  | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG] | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG] | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw0_vseg;
        end
    end
    
    always @ (posedge clk) begin
        if (~resetn) begin
            csr_dmw1_plv0 <= 1'b0;
            csr_dmw1_plv3 <= 1'b0;
            csr_dmw1_mat  <= 2'b0;
            csr_dmw1_pseg <= 3'b0;
            csr_dmw1_vseg <= 3'b0;
        end
        else if (csr_we && csr_num == `CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[`CSR_DMW_PLV0] & csr_wvalue[`CSR_DMW_PLV0] | ~csr_wmask[`CSR_DMW_PLV0] & csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[`CSR_DMW_PLV3] & csr_wvalue[`CSR_DMW_PLV3] | ~csr_wmask[`CSR_DMW_PLV3] & csr_dmw1_plv3;
            csr_dmw1_mat  <= csr_wmask[`CSR_DMW_MAT]  & csr_wvalue[`CSR_DMW_MAT]  | ~csr_wmask[`CSR_DMW_MAT] & csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[`CSR_DMW_PSEG] & csr_wvalue[`CSR_DMW_PSEG] | ~csr_wmask[`CSR_DMW_PSEG] & csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[`CSR_DMW_VSEG] & csr_wvalue[`CSR_DMW_VSEG] | ~csr_wmask[`CSR_DMW_VSEG] & csr_dmw1_vseg;
        end
    end

    assign csr_dmw0_rvalue = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg, 19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
    assign csr_dmw1_rvalue = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg, 19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
//exp19 add end


    //assign ex_entry  = csr_eentry_rvalue;
    assign ex_entry = (wb_ex && wb_ecode == `EXC_ECODE_TLBR)? csr_tlbrentry_rvalue : csr_eentry_rvalue;//exp19 TLB����������������csr_tlbrentry�����������������csr_eentry_rvalue
    assign ex_exit  = csr_era_rvalue;

    assign csr_has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);//���������ڲ��ж����յ��жϵı�־�ź�

    assign csr_rvalue = {32{csr_raddr == `CSR_CRMD  }} & csr_crmd_rvalue    |
                        {32{csr_raddr == `CSR_PRMD  }} & csr_prmd_rvalue    |
                        {32{csr_raddr == `CSR_ESTAT }} & csr_estat_rvalue   |
                        {32{csr_raddr == `CSR_ERA   }} & csr_era_rvalue     |
                        {32{csr_raddr == `CSR_EENTRY}} & csr_eentry_rvalue  |
                        {32{csr_raddr == `CSR_SAVE0 }} & csr_save0_rvalue   |
                        {32{csr_raddr == `CSR_SAVE1 }} & csr_save1_rvalue   |
                        {32{csr_raddr == `CSR_SAVE2 }} & csr_save2_rvalue   |
                        {32{csr_raddr == `CSR_SAVE3 }} & csr_save3_rvalue   | 
                        {32{csr_raddr == `CSR_ECFG  }} & csr_ecfg_rvalue    |
                        //exp13 add
                        {32{csr_raddr == `CSR_BADV  }} & csr_badv_rvalue    |
                        {32{csr_raddr == `CSR_TID   }} & csr_tid_rvalue     |
                        {32{csr_raddr == `CSR_TCFG  }} & csr_tcfg_rvalue    |
                        {32{csr_raddr == `CSR_TVAL  }} & csr_tval_rvalue    |
                        {32{csr_raddr == `CSR_TICLR }} & csr_ticlr_rvalue   |
                        {32{csr_raddr == `CSR_TLBIDX}} & csr_tlbidx_rvalue  |
                        {32{csr_raddr == `CSR_TLBEHI}} & csr_tlbehi_rvalue  |
                        {32{csr_raddr == `CSR_TLBELO0}} & csr_tlbelo0_rvalue|
                        {32{csr_raddr == `CSR_TLBELO1}} & csr_tlbelo1_rvalue|
                        {32{csr_raddr == `CSR_ASID  }} & csr_asid_rvalue    |
                        {32{csr_raddr == `CSR_TLBRENTRY}} & csr_tlbrentry_rvalue|
                        //exp19 add                        
                        {32{csr_raddr == `CSR_DMW0  }}  & csr_dmw0_rvalue   |
                        {32{csr_raddr == `CSR_DMW1  }}  & csr_dmw1_rvalue   ;

endmodule