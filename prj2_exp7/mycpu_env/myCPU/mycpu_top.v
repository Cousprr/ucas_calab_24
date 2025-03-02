module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire ID_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    wire IF_valid;
    wire IF_to_ID_valid;
    wire ID_to_EXE_valid;
    wire EXE_to_MEM_valid;
    wire MEM_to_WB_valid;
    wire [63:0] IF_to_ID_bus;
    wire [32:0] ID_to_IF_bus;

    wire [179:0] ID_to_EXE_bus;
    wire [102:0] EXE_to_MEM_bus;
    wire [101:0] MEM_to_WB_bus;
    wire [37:0] WB_to_ID_bus;

    
    IF u_IF(
    .clk(clk),
    .resetn(resetn),
    .ID_allow_in(ID_allow_in),
    .IF_to_ID_valid(IF_to_ID_valid),
    .IF_to_ID_bus(IF_to_ID_bus),
    .ID_to_IF_bus(ID_to_IF_bus),
    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
    );
 
    ID u_ID(
    .clk(clk),
    .resetn(resetn),
    .IF_to_ID_valid(IF_to_ID_valid),
    .ID_allow_in(ID_allow_in),
    .IF_to_ID_bus(IF_to_ID_bus),
    .ID_to_IF_bus(ID_to_IF_bus),
    .EXE_allow_in(EXE_allow_in),
    .ID_to_EXE_valid(ID_to_EXE_valid),
    .ID_to_EXE_bus(ID_to_EXE_bus),
    .WB_to_ID_bus(WB_to_ID_bus)
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
    .data_sram_wdata(data_sram_wdata)
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
    .data_sram_rdata(data_sram_rdata)
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
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

endmodule