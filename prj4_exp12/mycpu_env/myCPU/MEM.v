module MEM(
    input  wire        clk,
    input  wire        resetn,
    //from EXE
    output wire MEM_allow_in,
    input wire EXE_to_MEM_valid,
    input wire [188:0] EXE_to_MEM_bus,
    //to WB
    output wire MEM_to_WB_valid,
    input wire WB_allow_in,
    output wire [187:0] MEM_to_WB_bus,
    //to data sram interface
    input  wire [31:0] data_sram_rdata,
    
    output wire[37:0] MEM_wr_bus,

    //csr
    output wire MEM_ex,
    output wire MEM_ertn,
    output wire [15:0] MEM_to_csr_bus,

    input wire wb_ex,
    input wire ertn_flush
);
    //inside MEM
    reg MEM_valid;
    wire MEM_ready_go;
    assign MEM_ready_go = 1'b1;
    
    wire [31:0] MEM_inst;
    wire [31:0] MEM_pc;

    //load inst by swt start
    assign inst_ld_b  = MEM_inst[31:22] == 10'b0010100000;
    assign inst_ld_h  = MEM_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = MEM_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = MEM_inst[31:22] == 10'b0010101001;
    assign inst_ld_w  = MEM_inst[31:22] == 10'b0010100010;
    //by swt end

    assign MEM_to_WB_valid = MEM_ready_go & MEM_valid;
    assign MEM_allow_in = MEM_to_WB_valid & WB_allow_in | ~MEM_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_valid <= 1'b0;
        end
        else if (wb_ex | ertn_flush) begin//change exp12
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

    assign {MEM_csr_we, MEM_csr_num, MEM_csr_wmask, MEM_csr_wvalue,
            inst_ertn, EXE_ex_type,
            alu_result,
            res_from_mem, gr_we, dest, 
            MEM_pc, MEM_inst} = EXE_to_MEM_bus_valid;
    assign MEM_ex_type = EXE_ex_type;


    //load by swt start
    wire    [ 1:0]  vaddr;
    wire    [31:0]  word;
    wire    [15:0]  half;
    wire    [ 7:0]  byte;
    wire    [31:0]  half_xtnd;
    wire    [31:0]  byte_xtnd;
    wire    [31:0] mem_ld_result;
    wire    [31:0] final_result;
    
    assign  vaddr = alu_result[1:0];
    assign  word  = data_sram_rdata;
    assign  half  = vaddr[1] ? word[31:16] : word[15:0];
    assign  byte  = vaddr[1] & vaddr[0] ? word[31:24] :
                    vaddr[1] &~vaddr[0] ? word[23:16] :
                   ~vaddr[1] & vaddr[0] ? word[15: 8] :
                                          word[ 7: 0] ;
    assign  half_xtnd = {32{inst_ld_h}} & {{16{half[15]}}, half} | {32{inst_ld_hu}} & {16'b0, half};
    assign  byte_xtnd = {32{inst_ld_b}} & {{24{byte[ 7]}}, byte} | {32{inst_ld_bu}} & {24'b0, byte};

    assign  mem_ld_result = {32{inst_ld_b | inst_ld_bu}} & byte_xtnd |
                            {32{inst_ld_h | inst_ld_hu}} & half_xtnd |
                            {32{inst_ld_w             }} & word      ;

    assign final_result = res_from_mem ? mem_ld_result : alu_result;
    //by swt end

    //bus
    assign MEM_to_WB_bus = {MEM_csr_we, MEM_csr_num, MEM_csr_wmask, MEM_csr_wvalue, inst_ertn, MEM_ex_type,
                            final_result,
                            gr_we, dest,
                            MEM_pc, MEM_inst};
    assign MEM_write = gr_we & MEM_valid;
    assign MEM_wr_bus = {MEM_write, dest, final_result};


//change exp12
    assign MEM_ex = (|MEM_ex_type) & MEM_valid;
    assign MEM_to_csr_bus = {MEM_csr_we & MEM_valid, MEM_ertn, MEM_csr_num};
    assign MEM_ertn = MEM_valid & inst_ertn;
endmodule