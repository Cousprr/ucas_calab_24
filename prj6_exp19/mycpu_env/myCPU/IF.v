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

module IF(
    input  wire        clk,
    input  wire        resetn,
    //to ID
    input wire ID_allow_in,//ID正常读入数据
    output wire IF_to_ID_valid,//IF正常工作，输出正确结果
    output wire [78:0] IF_to_ID_bus,//IF_EXC_TYPE & pc & instruction  //exp19 add 9bit
    input wire  [33:0] ID_to_IF_bus,//br_stall & br_taken & br_target
    
    //to 指令寄存器
    output wire [31:0] inst_sram_addr,//该次请求的地址
    output wire [31:0] inst_sram_wdata,//该次请求写的数据
    input  wire [31:0] inst_sram_rdata,//该次请求返回的数据
    output wire        inst_sram_req,//请求信号，置1时表示有读写请求
    output wire        inst_sram_wr,//写使能信号，置1时表示该次请求为写
    output wire [1 :0] inst_sram_size,//该次请求传输的字节数，0：1byte,1：2bytes,2：4bytes
    output wire [3 :0] inst_sram_wstrb,//equal as we
    input wire         inst_sram_addr_ok,//表示该次请求的地址传输 OK，读：地址传输完成，写：地址和数据均传输完成
    input wire         inst_sram_data_ok,//该次请求的数据 OK，读：希望读的数据返回，写：数据写入完成
    
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
    wire pre_ready_go;//取值地址请求
    reg pre_valid;//预取指令有效
    wire pre_if_valid;//pre传给IF的指令有效
    wire fs_to_valid;//cancel掉pre请求；异常和中断要清空流水线
    reg IF_valid;//IF工作有效
    wire IF_allow_in;//IF正常读入数据
    wire IF_ready_go;//IF工作有效，可进入下个阶段
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
    assign  pf_nextpc = flush                ? flush_pc      : //exp19 change     flush:当前周期要求清空流水线
                         flush_reg            ? flush_pc_reg  : //exp19 change     flush_reg:前面流水线中产生的清空需求被延迟处理(寄存)
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
    //中断返回、中断陷入和跳转的地址
    reg                             br_reg;
    reg     [31:0]                  br_target_reg;
    reg                             stall_reg;//exp16
    //控制信号
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
    
    //地址信息
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
    assign inst_sram_addr = (csr_crmd_da & ~csr_crmd_pg) ? pf_nextpc :     //直接地址翻译  da（直接地址翻译使能）=1，pg（映射地址翻译使能）=0
                             pf_dmw0_hit                  ? pf_dmw0_paddr : //映射地址翻译-直接映射
                             pf_dmw1_hit                  ? pf_dmw1_paddr : //映射地址翻译-直接映射
                                                            pf_tlb_paddr;   //映射地址翻译-页表映射  exp19 change
    assign  inst_sram_size = 2'h2;
    assign  inst_sram_wstrb = 4'b0;
    assign  inst_sram_wdata = 32'b0;
    assign  inst_sram_wr = 1'b0;

    //inst_cancel flush用于避免陷入时出现pc和指令不相同的情况
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
    //虚实地址转换
    wire    pf_dmw0_hit;
    wire    pf_dmw1_hit;
    wire    [31:0]  pf_dmw0_paddr;
    wire    [31:0]  pf_dmw1_paddr;
    wire    [31:0]  pf_tlb_paddr;
    wire    use_tlb;
    assign pf_dmw0_hit = (pf_nextpc[31:29] == csr_dmw0_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw0_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw0_plv3);
    assign pf_dmw1_hit = (pf_nextpc[31:29] == csr_dmw1_vseg) && ((csr_crmd_plv == 2'd0) && csr_dmw1_plv0 || (csr_crmd_plv == 2'd3) && csr_dmw1_plv3);
    //pf_dmw0/1_hit：检查地址是否命中直接映射窗口DMW0/1
    //vseg:直接映射窗口的虚地址的[31:29]位   plv:特权等级  dmw0/1_plv0/3为1:在对应特权等级下可使用该窗口的配置进行直接地址映射翻译
    assign pf_dmw0_paddr = {csr_dmw0_pseg, pf_nextpc[28:0]};//pseg:直接映射窗口的物理地址的[31:29]位
    assign pf_dmw1_paddr = {csr_dmw1_pseg, pf_nextpc[28:0]};
    //pf_dmw0/1_paddr：直接映射窗口命中时计算的物理地址。
    assign pf_tlb_paddr = (s0_ps == 6'd21) ? {s0_ppn[19:9], pf_nextpc[20:0]} : {s0_ppn, pf_nextpc[11:0]};
    //pf_tlb_paddr：通过TLB计算的物理地址。根据页表大小(s0_ps)进行拼接。s0_ppn:物理页号
    assign use_tlb = ~csr_crmd_da & csr_crmd_pg & ~pf_dmw0_hit & ~pf_dmw1_hit;//da=0, pg=1, pf_dmw0_hit=0, pf_dmw1_hit=0
    //指示是否需要通过TLB进行地址转换。da（直接地址翻译使能）=0，pg（映射地址翻译使能）=1，直接映射未命中dmw0/1_hit=0
    assign {s0_vppn,s0_va_bit12}= pf_nextpc[31:12];//vppn：访存虚地址第31~13位；va_bit12：访存虚地址第12位
//exp19 add end

    //中断和异常
    wire [14:0] IF_exc_type;//exp19 add 9bit
    assign IF_exc_type[`TYPE_ADEF]  = ((|IF_pc[1:0])|(IF_pc[31] & csr_crmd_plv == 2'd3)) & ~pf_dmw0_hit & ~pf_dmw1_hit;//取指地址错例外。IF_pc非对齐或用户态不合法访问，且地址未命中DMW窗口
    //IF_pc[31] & csr_crmd_plv == 2'd3：所有特权指令仅在PLV0特权等级下才能访问。
    //assign IF_exc_type[`TYPE_ADEF] = |IF_pc[1:0];
    assign IF_exc_type[`TYPE_TLBRF] = use_tlb & ~s0_found;//TLB重填例外。需要通过TLB进行地址转换，且没有找到对应TLB表项，即TLB没命中
    assign IF_exc_type[`TYPE_PIF]   = use_tlb & s0_found & ~s0_v;//取指操作页无效例外。在TLB中找到了匹配项但是匹配页表项的V=0    s0_v：有效位
    assign IF_exc_type[`TYPE_PPIF]  = use_tlb & s0_found & s0_v & (csr_crmd_plv > s0_plv);//页特权等级不合规例外。访存操作的虚地址在TLB中找到了匹配且V=1的项，但是访问的特权等级不合规
                                                                                            //特权等级不合规：该页表项的csr_crmd_plv(当前特权等级)值大于页表项中的PLV(特权等级)
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

    //缓存器buffer
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
