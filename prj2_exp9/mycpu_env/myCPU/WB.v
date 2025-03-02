module WB(
    input  wire        clk,
    input  wire        resetn,
    //from MEM
    output wire WB_allow_in,
    input wire MEM_to_WB_valid,
    input wire [101:0] MEM_to_WB_bus,
    //to ID
    output wire [37:0] WB_to_ID_bus,
    //for DEBUG
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
    );

    //inside MEM
    reg WB_valid;
    wire WB_ready_go;
    assign WB_ready_go = 1'b1;
    assign WB_allow_in = WB_ready_go | ~WB_valid;//ÓÐÇø±ð
    wire [31:0] WB_inst;
    wire [31:0] WB_pc;

    always @(posedge clk)begin
        if(~resetn)begin
            WB_valid <= 1'b0;
        end
        else if(WB_allow_in)begin
            WB_valid <= MEM_to_WB_valid;
        end
    end  

    reg [101:0] MEM_to_WB_bus_valid;
    always @(posedge clk)begin
        if(MEM_to_WB_valid & WB_allow_in)begin
            MEM_to_WB_bus_valid <= MEM_to_WB_bus;
        end
    end
    
    //bus
    wire [31:0] final_result;
    wire        gr_we;
    wire [ 4:0] dest;
    assign {final_result,
            gr_we, dest,
            WB_pc, WB_inst} = MEM_to_WB_bus_valid;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    assign rf_we    = gr_we && WB_valid;
    assign rf_waddr = dest;
    assign rf_wdata = final_result;
    // debug info generate
    assign debug_wb_pc       = WB_pc;
    assign debug_wb_rf_we   = {4{rf_we}};
    assign debug_wb_rf_wnum  = dest;
    assign debug_wb_rf_wdata = final_result;
    
    //bus
    assign WB_to_ID_bus = {rf_we, rf_waddr, rf_wdata};
endmodule
