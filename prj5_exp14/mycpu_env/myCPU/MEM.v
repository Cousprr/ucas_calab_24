    `define TYPE_ALE    2

module MEM(
    input  wire         clk,
    input  wire         resetn,
    //from EXE
    output wire         MEM_allow_in,
    input  wire         EXE_to_MEM_valid,
    input  wire [190:0] EXE_to_MEM_bus,
    //to WB
    output wire         MEM_to_WB_valid,
    input  wire         WB_allow_in,
    output wire [187:0] MEM_to_WB_bus,
    //to data sram interface
    input  wire [ 31:0] data_sram_rdata,
    input  wire         data_sram_data_ok,
    output wire [ 37:0] MEM_wr_bus,

    //csr
    output wire MEM_ex,
    output wire MEM_ertn,
    output wire [15:0] MEM_to_csr_bus,
    output wire ldst_cancel,
    input wire wb_ex,
    input wire ertn_flush
);

    //load inst by swt start
    assign inst_ld_b  = MEM_inst[31:22] == 10'b0010100000;
    assign inst_ld_h  = MEM_inst[31:22] == 10'b0010100001;
    assign inst_ld_bu = MEM_inst[31:22] == 10'b0010101000;
    assign inst_ld_hu = MEM_inst[31:22] == 10'b0010101001;
    assign inst_ld_w  = MEM_inst[31:22] == 10'b0010100010;
    assign is_load = inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_ld_w;
    //by swt end

    //inside MEM
    reg MEM_valid;
    wire MEM_ready_go;
    wire [31:0] MEM_inst;
    wire [31:0] MEM_pc;

    assign MEM_ready_go = (is_load | mem_we) ?
        (|MEM_ex_type) | ls_cancel | data_sram_data_ok : 1'b1;
    assign MEM_to_WB_valid = MEM_ready_go & MEM_valid & ~is_ertn_exc;
    assign MEM_allow_in = MEM_ready_go & WB_allow_in | ~MEM_valid;
    always @(posedge clk)begin
        if(~resetn)begin
            MEM_valid <= 1'b0;
        end
        else if(MEM_allow_in)begin
            MEM_valid <= EXE_to_MEM_valid;
        end
    end  
   
    reg [190:0] EXE_to_MEM_bus_valid;
    always @(posedge clk)begin
        if(EXE_to_MEM_valid & MEM_allow_in)begin
            EXE_to_MEM_bus_valid <= EXE_to_MEM_bus;
        end
    end
    
    //bus
    wire [31:0] alu_result;
    wire        res_from_mem;
    wire        gr_we;
    wire [ 4:0] dest;
    wire        MEM_csr_we;
    wire [13:0] MEM_csr_num;
    wire [31:0] MEM_csr_wmask;
    wire [31:0] MEM_csr_wvalue;
    wire        inst_ertn;
    wire [ 5:0] EXE_ex_type;
    wire [ 5:0] MEM_ex_type;
    wire        ls_cancel;
    wire        mem_we;

    assign {MEM_csr_we, MEM_csr_num, MEM_csr_wmask, MEM_csr_wvalue,
            inst_ertn, EXE_ex_type,
            alu_result,
            res_from_mem, gr_we, dest, 
            MEM_pc, MEM_inst, ls_cancel, mem_we} = EXE_to_MEM_bus_valid;
    assign MEM_ex_type = EXE_ex_type;

    //add exp14 control
    reg exc_reg;
    reg ertn_reg;
    assign ldst_cancel = MEM_ex | MEM_ertn;
    assign is_ertn_exc = wb_ex | ertn_flush | exc_reg | ertn_reg;
    always @(posedge clk) begin
        if (~resetn) begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end 
        else if (wb_ex) begin
            exc_reg <= 1'b1;
        end 
        else if (ertn_flush) begin
            ertn_reg <= 1'b1;
        end 
        else if (EXE_to_MEM_valid & MEM_allow_in)begin
            exc_reg <= 1'b0;
            ertn_reg <= 1'b0;
        end
    end

    //load by swt start
    wire    [ 1:0]  vaddr;
    wire    [31:0]  word;
    wire    [15:0]  half;
    wire    [ 7:0]  byte;
    wire    [31:0]  half_xtnd;
    wire    [31:0]  byte_xtnd;
    wire    [31:0]  mem_ld_result;
    wire    [31:0]  final_result;
    
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

    assign final_result = MEM_ex_type[`TYPE_ALE] ? alu_result : //change exp13 此时是地址非对齐例外
                           res_from_mem ? mem_ld_result : alu_result;
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