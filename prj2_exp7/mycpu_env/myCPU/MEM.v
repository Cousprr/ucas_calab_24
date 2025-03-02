module MEM(
    input  wire        clk,
    input  wire        resetn,
    //from EXE
    output wire MEM_allow_in,
    input wire EXE_to_MEM_valid,
    input wire [102:0] EXE_to_MEM_bus,
    //to WB
    output wire MEM_to_WB_valid,
    input wire WB_allow_in,
    output wire [101:0] MEM_to_WB_bus,
    //to data sram interface
    input  wire [31:0] data_sram_rdata
);
    //inside MEM
    reg MEM_valid;
    wire MEM_ready_go;
    assign MEM_ready_go = 1'b1;
    
    wire [31:0] MEM_inst;
    wire [31:0] MEM_pc;
    assign MEM_to_WB_valid = MEM_ready_go & MEM_valid;
    assign MEM_allow_in = MEM_ready_go & WB_allow_in | ~MEM_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_valid <= 1'b0;
        end
        else if(MEM_allow_in)begin
            MEM_valid <= EXE_to_MEM_valid;
        end
    end  

    reg [102:0] EXE_to_MEM_bus_valid;
    always @(posedge clk)begin
        if(EXE_to_MEM_valid & MEM_allow_in)begin
            EXE_to_MEM_bus_valid <= EXE_to_MEM_bus;
        end
    end
    
    //bus
    wire    [ 31:0] alu_result;
    wire            res_from_mem;
    wire            gr_we;
    wire    [  4:0] dest;
    assign {alu_result,
           res_from_mem, gr_we, dest, 
           MEM_pc, MEM_inst} = EXE_to_MEM_bus_valid;
           
    wire [31:0] final_result;
    wire [31:0] mem_result;
    assign mem_result   = data_sram_rdata;
    assign final_result = res_from_mem ? mem_result : alu_result;
    
    //bus
    assign MEM_to_WB_bus = {final_result,
                            gr_we, dest,
                            MEM_pc, MEM_inst};
endmodule