module alu(
  input  wire [18:0] alu_op,//�޸�λ��
  input  wire [31:0] alu_src1,
  input  wire [31:0] alu_src2,
  output wire [31:0] alu_result
);

wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_mull;   //low_32bit mul
wire op_mulh;  //signed high_32bit mul
wire op_mulhu; //unsigned high_32bit mul

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mull  = alu_op[12];
assign op_mulh = alu_op[13];
assign op_mulhu = alu_op[14];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [63:0] sr64_result;
wire [31:0] sr_result;
wire [31:0] mull_result;     //low_32bit mul
wire [31:0] mulh_result;    //signed high_32bit mul
wire [31:0] mulhu_result;   //unsigned high_32bit mul
wire [65:0] mulsu_result;   //signed and unsigned result as [63:0]
wire [32:0] mul_extend_src1;
wire [32:0] mul_extend_src2;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
//assign or_result  = alu_src1 | alu_src2 | alu_result;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
//assign sll_result = alu_src2 << alu_src1[4:0];   //rj << i5
assign sll_result = alu_src1 << alu_src2[4:0];

// SRL, SRA result
//assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0]; //rj >> i5
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5

//assign sr_result   = sr64_result[30:0];
assign sr_result   = sr64_result[31:0];

//by swt start
//mul result
assign mul_extend_src1 = ({33{op_mulh | op_mull}} & {alu_src1[31],alu_src1}) | ({33{op_mulhu}} & {1'b0,alu_src1});
assign mul_extend_src2 = ({33{op_mulh | op_mull}} & {alu_src2[31],alu_src2}) | ({33{op_mulhu}} & {1'b0,alu_src2});
assign mulsu_result = $signed(mul_extend_src1) * $signed(mul_extend_src2);
assign mull_result = mulsu_result[31:0];
assign mulh_result = mulsu_result[63:32];
assign mulhu_result = mulsu_result[63:32];
//by swt end

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result)
                  | ({32{op_mull      }} & mull_result)
                  | ({32{op_mulh      }} & mulh_result)
                  | ({32{op_mulhu     }} & mulhu_result);

endmodule
