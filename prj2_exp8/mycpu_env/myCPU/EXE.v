module EXE(
    input  wire        clk,
    input  wire        resetn,
    //from ID
    output wire EXE_allow_in,
    input wire ID_to_EXE_valid,
    input wire [179:0] ID_to_EXE_bus,
    //to MEM
    output wire EXE_to_MEM_valid,
    input wire MEM_allow_in,
    output wire [102:0] EXE_to_MEM_bus,
    // to data sram interface
    output wire        data_sram_en,
    output wire [3 :0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    //conflict
    output wire [5:0] EXE_wr_bus
    );
    //inside EXE
    reg EXE_valid;
    wire EXE_ready_go;
    assign EXE_ready_go = 1'b1;

    wire [31:0] EXE_inst;
    wire [31:0] EXE_pc;
    assign EXE_to_MEM_valid = EXE_ready_go & EXE_valid;
    assign EXE_allow_in = EXE_ready_go & MEM_allow_in | ~EXE_valid;

    always @(posedge clk)begin
        if(~resetn)begin
            EXE_valid <= 1'b0;
        end
        else if(EXE_allow_in)begin
            EXE_valid <= ID_to_EXE_valid;
        end
    end  

    reg [179:0] ID_to_EXE_bus_valid;
    always @(posedge clk)begin
        if(ID_to_EXE_valid & EXE_allow_in)begin
            ID_to_EXE_bus_valid <= ID_to_EXE_bus;
        end
    end
    //bus
    wire    [11:0]  alu_op;
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
    alu u_alu(
     .alu_op     (alu_op    ),
     .alu_src1   (alu_src1  ),
     .alu_src2   (alu_src2  ),
     .alu_result (alu_result)
     ); 
    assign data_sram_en = 1'b1;
    assign data_sram_we    = {4{mem_we}};
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = rkd_value;
    
    assign EXE_to_MEM_bus ={alu_result,
                           res_from_mem, gr_we, dest, 
                           EXE_pc, EXE_inst};
    assign EXE_wr_bus = {gr_we & EXE_valid, dest};

endmodule
