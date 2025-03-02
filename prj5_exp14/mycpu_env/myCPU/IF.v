//exc types    
    `define TYPE_SYS    0
    `define TYPE_ADEF   1
    `define TYPE_ALE    2
    `define TYPE_BRK    3
    `define TYPE_INE    4
    `define TYPE_INT    5

module IF(
    input  wire        clk,
    input  wire        resetn,
    //to ID
    input wire ID_allow_in,//ID正常读入数据
    output wire IF_to_ID_valid,//IF正常工作，输出正确结果
    output wire [69:0] IF_to_ID_bus,//IF_EXC_TYPE & pc & instruction
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
    input [31:0] ex_exit
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
    assign pre_ready_go = inst_sram_req & inst_sram_addr_ok;
    assign pre_if_valid = pre_valid & pre_ready_go;    
    
    assign {br_stall, br_taken, br_target} = ID_to_IF_bus;

     always @(posedge clk) begin
        if(~resetn)begin
            pre_valid <= 1'b0;
        end
        else begin
            pre_valid <= 1'b1;//pre_allow_in always 1'b1
        end
    end
    //for pc choose
    wire    [31:0]                  pf_seqpc;
    wire    [31:0]                  pf_nextpc;
    reg     [31:0]                  pf_pc;
    assign  pf_nextpc = wb_ex      ? ex_entry :
                        exc_reg    ? entry_reg :
                        ertn_flush ? ex_exit :
                        ertn_reg   ? exit_reg :
                        br_reg     ? br_target_reg :
                        br_taken & ~br_stall ? br_target :
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
    reg                             exc_reg;
    reg     [31:0]                  entry_reg;
    reg                             ertn_reg;
    reg     [31:0]                  exit_reg;
    reg                             br_reg;
    reg     [31:0]                  br_target_reg;
    //控制信号
    always @(posedge clk) begin
        if(~resetn | pre_ready_go & IF_allow_in)begin
            br_reg <= 1'b0;
        end
        else if(~br_stall & br_taken)begin
            br_reg <= 1'b1;
        end
    end
    always @(posedge clk) begin
        if(~resetn | pre_ready_go & IF_allow_in)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end
        else if(wb_ex)begin
            exc_reg <= 1'b1;
        end
        else if(ertn_flush)begin
            ertn_reg <= 1'b1;
        end
    end
    //地址信息
    always @(posedge clk) begin
        if(~resetn | pre_ready_go & IF_allow_in)begin
            br_target_reg <= 32'b0;
        end
        else if(~br_stall & br_taken)begin
            br_target_reg <= br_target;
        end
    end
    always @(posedge clk) begin
        if(~resetn | pre_ready_go & IF_allow_in)begin
            entry_reg <= 32'b0;
            exit_reg <= 32'b0;
        end
        else if(wb_ex)begin
            entry_reg <= ex_entry;
        end
        else if(ertn_flush)begin
            exit_reg <= ex_exit;
        end
    end
    //for IF
     
    assign IF_ready_go = inst_sram_data_ok & IF_valid | buffer_valid;
    assign IF_allow_in = IF_ready_go & ID_allow_in | ~IF_valid;
    assign IF_to_ID_valid = IF_ready_go & IF_valid & ~inst_cancel & ~(wb_ex | ertn_flush |(br_taken & ~br_stall));

    always @(posedge clk) begin
         if(~resetn)begin
            IF_valid <= 1'b0;
        end
        else if(IF_allow_in)begin
            IF_valid <= pre_if_valid;
        end
    end
    
    always @(posedge clk) begin
        if (~resetn) begin
            IF_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
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
    //中断和异常
    wire [5:0] IF_exc_type;
    assign IF_exc_type[`TYPE_ADEF] = |IF_pc[1:0];
    assign IF_exc_type[`TYPE_SYS]  = 1'b0;
    assign IF_exc_type[`TYPE_ALE]  = 1'b0;
    assign IF_exc_type[`TYPE_BRK]  = 1'b0;
    assign IF_exc_type[`TYPE_INE]  = 1'b0;
    assign IF_exc_type[`TYPE_INT]  = 1'b0;

    //缓存器buffer
   // reg         buffer_valid;
   // reg         inst_cancel;
   // reg  [31:0] buffer;
    assign IF_inst = buffer_valid ? buffer : inst_sram_rdata;
    always @(posedge clk) begin
        if(~resetn)begin
            inst_cancel <= 1'b0;
        end
        else if(((br_taken & ~br_stall) | wb_ex | ertn_flush) & ~IF_ready_go & ~IF_allow_in)begin
            inst_cancel <= 1'b1;
        end
        else if(inst_sram_data_ok)begin
            inst_cancel <= 1'b0;
        end
    end
    always @(posedge clk) begin
        if(~resetn)begin
            buffer_valid <= 1'b0;
        end
        else if(inst_sram_data_ok & ~buffer_valid & ~inst_cancel & ~ID_allow_in)begin
            buffer_valid <= 1'b1;
        end
        else if(ID_allow_in | ertn_flush | wb_ex)begin
            buffer_valid <= 1'b0;
        end
    end
    always @(posedge clk) begin
        if(~resetn)begin
            buffer <= 32'b0;
        end
        else if(inst_sram_data_ok & ~buffer_valid & ~inst_cancel & ~ID_allow_in)begin
            buffer <= inst_sram_rdata;
        end
        else if(ID_allow_in | ertn_flush | wb_ex) begin
            buffer <= 32'b0;
        end
    end

    //instruction
    assign  inst_sram_req = pre_valid & IF_allow_in & ~br_stall;
    assign  inst_sram_addr = pf_nextpc;
    assign  inst_sram_size = 2'h2;
    assign  inst_sram_wstrb = 4'b0;
    assign  inst_sram_wdata = 32'b0;
    assign  inst_sram_wr = 1'b0;
    //assign  IF_inst = inst_sram_rdata;
    
    assign IF_to_ID_bus = {IF_exc_type, IF_pc, IF_inst};
endmodule
