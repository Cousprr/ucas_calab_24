module IF(
    input  wire        clk,
    input  wire        resetn,
    //to ID
    input wire ID_allow_in,//ID正常读入数据
    output wire IF_to_ID_valid,//IF正常工作，输出正确结果
    output wire [63:0] IF_to_ID_bus,//pc & instruction
    input wire [32:0] ID_to_IF_bus,//br_takan & br_target
    
    //to 指令寄存器
    output wire        inst_sram_en,
    output wire [3 :0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata
    );
    
    //inside IF
    reg IF_valid;//IF工作有效
    wire IF_allow_in;//IF正常读入数据
    wire IF_ready_go;//IF工作有效，可进入下个阶段
    
    //for pc
    reg [31:0] IF_pc;
    wire [31:0] IF_nextpc;
    wire [31:0] IF_seq_pc;
    //for instruction
    wire [31:0] IF_inst;
    //if branch
    wire br_taken;
    wire [31:0] br_target;
    
    assign IF_ready_go = 1'b1;
    assign IF_allow_in = IF_ready_go & ID_allow_in | ~IF_valid; //reset 或者 当前指令可以去ID
    assign IF_to_ID_valid = IF_ready_go & IF_valid;
    always @(posedge clk) begin
        IF_valid <= resetn;
    end
  
    assign IF_to_ID_bus = {IF_pc , IF_inst};
    
    assign {br_taken , br_target} = ID_to_IF_bus;
    assign IF_seq_pc = IF_pc + 3'h4;
    assign IF_nextpc = br_taken ? br_target : IF_seq_pc;

    always @(posedge clk) begin
        if (~resetn) begin
            IF_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
        end
        //else begin
        else if(IF_allow_in)begin
            IF_pc <= IF_nextpc;
        end
    end
    
    //instruction
    assign inst_sram_en = IF_allow_in;
    assign  inst_sram_addr = IF_nextpc;
    assign  inst_sram_we = 4'b0;
    assign  inst_sram_wdata = 32'b0;
    assign  IF_inst = inst_sram_rdata;
    
    //assign IF_to_ID_bus = {IF_pc , IF_inst};    
    
endmodule
