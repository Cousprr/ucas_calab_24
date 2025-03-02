module tlb
#(
parameter TLBNUM = 16
)
(
input wire clk,
// search port 0 (for fetch)
input wire [ 18:0] s0_vppn,     // vppn 访存虚地址第31~13位
input wire s0_va_bit12,         // va_bit12 访存虚地址第12位
input wire [ 9:0] s0_asid,      // asid ASID域
output wire s0_found,           // found 查找结果 1:找到对应表项
output wire [$clog2(TLBNUM)-1:0] s0_index,// index 查找结果对应表项索引
output wire [ 19:0] s0_ppn,     // ppn 物理页号
output wire [ 5:0] s0_ps,       // ps 页大小
output wire [ 1:0] s0_plv,      // plv 特权等级 判定是否产生页特权等级不合规异常
output wire [ 1:0] s0_mat,      // mat 存储访问类型 0x00:强序非缓存 0x01:一致可缓存 0x10/0x11:保留
output wire s0_d,               // d 脏位 判定是否产生页修改异常
output wire s0_v,               // v 有效位 判定是否产生页无效异常、页修改异常

input wire [ 18:0] s1_vppn,
input wire s1_va_bit12,
input wire [ 9:0] s1_asid,
output wire s1_found,
output wire [$clog2(TLBNUM)-1:0] s1_index,
output wire [ 19:0] s1_ppn,
output wire [ 5:0] s1_ps,
output wire [ 1:0] s1_plv,
output wire [ 1:0] s1_mat,
output wire s1_d,
output wire s1_v,

// invtlb opcode
input wire invtlb_valid,
input wire [ 4:0] invtlb_op,

// write port
input wire we, //w(rite) e(nable)
input wire [$clog2(TLBNUM)-1:0] w_index,
input wire w_e,
input wire [ 18:0] w_vppn,
input wire [ 5:0] w_ps,
input wire [ 9:0] w_asid,
input wire w_g,
input wire [ 19:0] w_ppn0,
input wire [ 1:0] w_plv0,
input wire [ 1:0] w_mat0,
input wire w_d0,
input wire w_v0,
input wire [ 19:0] w_ppn1,
input wire [ 1:0] w_plv1,
input wire [ 1:0] w_mat1,
input wire w_d1,
input wire w_v1,

// read port
input wire [$clog2(TLBNUM)-1:0] r_index,
output wire r_e,
output wire [ 18:0] r_vppn,
output wire [ 5:0] r_ps,
output wire [ 9:0] r_asid,
output wire r_g,
output wire [ 19:0] r_ppn0,
output wire [ 1:0] r_plv0,
output wire [ 1:0] r_mat0,
output wire r_d0,
output wire r_v0,
output wire [ 19:0] r_ppn1,
output wire [ 1:0] r_plv1,
output wire [ 1:0] r_mat1,
output wire r_d1,
output wire r_v1

);
reg [TLBNUM-1:0] tlb_e;                 //e     存在位，1:所在TLB表项非空
reg [TLBNUM-1:0] tlb_ps4MB;             //ps4MB 页大小  1:4MB, 0:4KB
reg [ 18:0] tlb_vppn [TLBNUM-1:0];      //vppn  虚双页号
reg [ 9:0] tlb_asid [TLBNUM-1:0];       //asid  地址空间标识符
reg tlb_g [TLBNUM-1:0];                 //g     全局位  1:不进行ASID一致性检查
reg [ 19:0] tlb_ppn0 [TLBNUM-1:0];      //ppn   物理页号
reg [ 1:0] tlb_plv0 [TLBNUM-1:0];       //plv   特权等级
reg [ 1:0] tlb_mat0 [TLBNUM-1:0];       //mat   存储访问类型 0x00:强序非缓存 0x01:一致可缓存 0x10/0x11:保留
reg tlb_d0 [TLBNUM-1:0];                //d     脏位 1：有脏数据
reg tlb_v0 [TLBNUM-1:0];                //v     有效位 1:有效且被访问过
reg [ 19:0] tlb_ppn1 [TLBNUM-1:0];
reg [ 1:0] tlb_plv1 [TLBNUM-1:0];
reg [ 1:0] tlb_mat1 [TLBNUM-1:0];
reg tlb_d1 [TLBNUM-1:0];
reg tlb_v1 [TLBNUM-1:0];

wire [TLBNUM - 1:0] match0;
wire [TLBNUM - 1:0] match1;

//TLB[i].VPPN[VALEN-1: TLB[i].PS+1]==va[VALEN-1: TLB[i].PS+1]
//PS 21/13
//s0_vppn[18:10]==tlb_vppn[ 0][18:10]

assign match0[ 0] = (s0_vppn[18:9] == tlb_vppn[ 0][18:9])
                    && (tlb_ps4MB[ 0] || s0_vppn[8:0] == tlb_vppn[ 0][8:0])
                    && ((s0_asid == tlb_asid[ 0]) || tlb_g[ 0]);
assign match0[ 1] = (s0_vppn[18:9] == tlb_vppn[ 1][18:9])
                    && (tlb_ps4MB[ 1] || s0_vppn[8:0] == tlb_vppn[ 1][8:0])
                    && ((s0_asid == tlb_asid[ 1]) || tlb_g[ 1]);
assign match0[ 2] = (s0_vppn[18:9] == tlb_vppn[ 2][18:9])
                    && (tlb_ps4MB[ 2] || s0_vppn[8:0] == tlb_vppn[ 2][8:0])
                    && ((s0_asid == tlb_asid[ 2]) || tlb_g[ 2]);
assign match0[ 3] = (s0_vppn[18:9] == tlb_vppn[ 3][18:9])
                    && (tlb_ps4MB[ 3] || s0_vppn[8:0] == tlb_vppn[ 3][8:0])
                    && ((s0_asid == tlb_asid[ 3]) || tlb_g[ 3]);
assign match0[ 4] = (s0_vppn[18:9] == tlb_vppn[ 4][18:9])
                    && (tlb_ps4MB[ 4] || s0_vppn[8:0] == tlb_vppn[ 4][8:0])
                    && ((s0_asid == tlb_asid[ 4]) || tlb_g[ 4]);
assign match0[ 5] = (s0_vppn[18:9] == tlb_vppn[ 5][18:9])
                    && (tlb_ps4MB[ 5] || s0_vppn[8:0] == tlb_vppn[ 5][8:0])
                    && ((s0_asid == tlb_asid[ 5]) || tlb_g[ 5]);
assign match0[ 6] = (s0_vppn[18:9] == tlb_vppn[ 6][18:9])
                    && (tlb_ps4MB[ 6] || s0_vppn[8:0] == tlb_vppn[ 6][8:0])
                    && ((s0_asid == tlb_asid[ 6]) || tlb_g[ 6]);
assign match0[ 7] = (s0_vppn[18:9] == tlb_vppn[ 7][18:9])
                    && (tlb_ps4MB[ 7] || s0_vppn[8:0] == tlb_vppn[ 7][8:0])
                    && ((s0_asid == tlb_asid[ 7]) || tlb_g[ 7]);
assign match0[ 8] = (s0_vppn[18:9] == tlb_vppn[ 8][18:9])
                    && (tlb_ps4MB[ 8] || s0_vppn[8:0] == tlb_vppn[ 8][8:0])
                    && ((s0_asid == tlb_asid[ 8]) || tlb_g[ 8]);
assign match0[ 9] = (s0_vppn[18:9] == tlb_vppn[ 9][18:9])
                    && (tlb_ps4MB[ 9] || s0_vppn[8:0] == tlb_vppn[ 9][8:0])
                    && ((s0_asid == tlb_asid[ 9]) || tlb_g[ 9]);
assign match0[10] = (s0_vppn[18:9] == tlb_vppn[10][18:9])
                    && (tlb_ps4MB[10] || s0_vppn[8:0] == tlb_vppn[10][8:0])
                    && ((s0_asid == tlb_asid[10]) || tlb_g[10]);
assign match0[11] = (s0_vppn[18:9] == tlb_vppn[11][18:9])
                    && (tlb_ps4MB[11] || s0_vppn[8:0] == tlb_vppn[11][8:0])
                    && ((s0_asid == tlb_asid[11]) || tlb_g[11]);
assign match0[12] = (s0_vppn[18:9] == tlb_vppn[12][18:9])
                    && (tlb_ps4MB[12] || s0_vppn[8:0] == tlb_vppn[12][8:0])
                    && ((s0_asid == tlb_asid[12]) || tlb_g[12]);
assign match0[13] = (s0_vppn[18:9] == tlb_vppn[13][18:9])
                    && (tlb_ps4MB[13] || s0_vppn[8:0] == tlb_vppn[13][8:0])
                    && ((s0_asid == tlb_asid[13]) || tlb_g[13]);
assign match0[14] = (s0_vppn[18:9] == tlb_vppn[14][18:9])
                    && (tlb_ps4MB[14] || s0_vppn[8:0] == tlb_vppn[14][8:0])
                    && ((s0_asid == tlb_asid[14]) || tlb_g[14]);
assign match0[15] = (s0_vppn[18:9] == tlb_vppn[15][18:9])
                    && (tlb_ps4MB[15] || s0_vppn[8:0] == tlb_vppn[15][8:0])
                    && ((s0_asid == tlb_asid[15]) || tlb_g[15]);


assign match1[ 0] = (s1_vppn[18:9]==tlb_vppn[ 0][18:9])
                    && (tlb_ps4MB[ 0] || s1_vppn[8:0]==tlb_vppn[ 0][8:0])
                    && ((s1_asid==tlb_asid[ 0]) || tlb_g[ 0]);
assign match1[ 1] = (s1_vppn[18:9]==tlb_vppn[ 1][18:9])
                    && (tlb_ps4MB[ 1] || s1_vppn[8:0]==tlb_vppn[ 1][8:0])
                    && ((s1_asid==tlb_asid[ 1]) || tlb_g[ 1]);
assign match1[ 2] = (s1_vppn[18:9]==tlb_vppn[ 2][18:9])
                    && (tlb_ps4MB[ 2] || s1_vppn[8:0]==tlb_vppn[ 2][8:0])
                    && ((s1_asid==tlb_asid[ 2]) || tlb_g[ 2]);
assign match1[ 3] = (s1_vppn[18:9]==tlb_vppn[ 3][18:9])
                    && (tlb_ps4MB[ 3] || s1_vppn[8:0]==tlb_vppn[ 3][8:0])
                    && ((s1_asid==tlb_asid[ 3]) || tlb_g[ 3]);
assign match1[ 4] = (s1_vppn[18:9]==tlb_vppn[ 4][18:9])
                    && (tlb_ps4MB[ 4] || s1_vppn[8:0]==tlb_vppn[ 4][8:0])
                    && ((s1_asid==tlb_asid[ 4]) || tlb_g[ 4]);
assign match1[ 5] = (s1_vppn[18:9]==tlb_vppn[ 5][18:9])
                    && (tlb_ps4MB[ 5] || s1_vppn[8:0]==tlb_vppn[ 5][8:0])
                    && ((s1_asid==tlb_asid[ 5]) || tlb_g[ 5]);
assign match1[ 6] = (s1_vppn[18:9]==tlb_vppn[ 6][18:9])
                    && (tlb_ps4MB[ 6] || s1_vppn[8:0]==tlb_vppn[ 6][8:0])
                    && ((s1_asid==tlb_asid[ 6]) || tlb_g[ 6]);  
assign match1[ 7] = (s1_vppn[18:9]==tlb_vppn[ 7][18:9])
                    && (tlb_ps4MB[ 7] || s1_vppn[8:0]==tlb_vppn[ 7][8:0])
                    && ((s1_asid==tlb_asid[ 7]) || tlb_g[ 7]);
assign match1[ 8] = (s1_vppn[18:9]==tlb_vppn[ 8][18:9]) 
                    && (tlb_ps4MB[ 8] || s1_vppn[8:0]==tlb_vppn[ 8][8:0])
                    && ((s1_asid==tlb_asid[ 8]) || tlb_g[ 8]);
assign match1[ 9] = (s1_vppn[18:9]==tlb_vppn[ 9][18:9])
                    && (tlb_ps4MB[ 9] || s1_vppn[8:0]==tlb_vppn[ 9][8:0])
                    && ((s1_asid==tlb_asid[ 9]) || tlb_g[ 9]);
assign match1[10] = (s1_vppn[18:9]==tlb_vppn[10][18:9])
                    && (tlb_ps4MB[10] || s1_vppn[8:0]==tlb_vppn[10][8:0])
                    && ((s1_asid==tlb_asid[10]) || tlb_g[10]);
assign match1[11] = (s1_vppn[18:9]==tlb_vppn[11][18:9])
                    && (tlb_ps4MB[11] || s1_vppn[8:0]==tlb_vppn[11][8:0])
                    && ((s1_asid==tlb_asid[11]) || tlb_g[11]);
assign match1[12] = (s1_vppn[18:9]==tlb_vppn[12][18:9])
                    && (tlb_ps4MB[12] || s1_vppn[8:0]==tlb_vppn[12][8:0])
                    && ((s1_asid==tlb_asid[12]) || tlb_g[12]);
assign match1[13] = (s1_vppn[18:9]==tlb_vppn[13][18:9])
                    && (tlb_ps4MB[13] || s1_vppn[8:0]==tlb_vppn[13][8:0])
                    && ((s1_asid==tlb_asid[13]) || tlb_g[13]);
assign match1[14] = (s1_vppn[18:9]==tlb_vppn[14][18:9])
                    && (tlb_ps4MB[14] || s1_vppn[8:0]==tlb_vppn[14][8:0])
                    && ((s1_asid==tlb_asid[14]) || tlb_g[14]);
assign match1[15] = (s1_vppn[18:9]==tlb_vppn[15][18:9])
                    && (tlb_ps4MB[15] || s1_vppn[8:0]==tlb_vppn[15][8:0])
                    && ((s1_asid==tlb_asid[15]) || tlb_g[15]);  


//search port 0
assign s0_found = |match0[TLBNUM-1:0];  //按位或

assign s0_index[0] = match0[ 1] | match0[ 3] | match0[ 5] | match0[ 7] | match0[ 9] | match0[11] | match0[13] | match0[15];
assign s0_index[1] = match0[ 2] | match0[ 3] | match0[ 6] | match0[ 7] | match0[10] | match0[11] | match0[14] | match0[15];
assign s0_index[2] = match0[ 4] | match0[ 5] | match0[ 6] | match0[ 7] | match0[12] | match0[13] | match0[14] | match0[15];
assign s0_index[3] = match0[ 8] | match0[ 9] | match0[10] | match0[11] | match0[12] | match0[13] | match0[14] | match0[15];


// if (va[found_ps]==0) :
// found_v = TLB[i].V0
// found_d = TLB[i].D0
// found_mat = TLB[i].MAT0
// found_plv = TLB[i].PLV0
// found_ppn = TLB[i].PPN0
// else :
// found_v = TLB[i].V1
// found_d = TLB[i].D1
// found_mat = TLB[i].MAT1
// found_plv = TLB[i].PLV1
// found_ppn = TLB[i].PPN1
wire s0_found_ps;
assign s0_ps = tlb_ps4MB[s0_index]? 6'd21 : 6'd12;
assign s0_found_ps = tlb_ps4MB[s0_index]? s0_vppn[8] : s0_va_bit12;//21/12
assign s0_v = s0_found_ps? tlb_v1[s0_index] : tlb_v0[s0_index];
assign s0_d = s0_found_ps? tlb_d1[s0_index] : tlb_d0[s0_index];
assign s0_mat = s0_found_ps? tlb_mat1[s0_index] : tlb_mat0[s0_index];
assign s0_plv = s0_found_ps? tlb_plv1[s0_index] : tlb_plv0[s0_index];
assign s0_ppn = s0_found_ps? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];

//search port 1

assign s1_found = |match1[TLBNUM-1:0];  //按位或

assign s1_index[0] = match1[ 1] | match1[ 3] | match1[ 5] | match1[ 7] | match1[ 9] | match1[11] | match1[13] | match1[15];
assign s1_index[1] = match1[ 2] | match1[ 3] | match1[ 6] | match1[ 7] | match1[10] | match1[11] | match1[14] | match1[15];
assign s1_index[2] = match1[ 4] | match1[ 5] | match1[ 6] | match1[ 7] | match1[12] | match1[13] | match1[14] | match1[15];
assign s1_index[3] = match1[ 8] | match1[ 9] | match1[10] | match1[11] | match1[12] | match1[13] | match1[14] | match1[15];

assign s1_ps = tlb_ps4MB[s1_index]? 6'd21 : 6'd12;
wire s1_found_ps;
//assign s1_found_ps = tlb_ps4MB[s1_index]? s0_vppn[8] : s0_va_bit12;//21/12
assign s1_found_ps = tlb_ps4MB[s1_index]? s1_vppn[8] : s1_va_bit12;//21/12
assign s1_v = s1_found_ps? tlb_v1[s1_index] : tlb_v0[s1_index];
assign s1_d = s1_found_ps? tlb_d1[s1_index] : tlb_d0[s1_index];
assign s1_mat = s1_found_ps? tlb_mat1[s1_index] : tlb_mat0[s1_index];
assign s1_plv = s1_found_ps? tlb_plv1[s1_index] : tlb_plv0[s1_index];
assign s1_ppn = s1_found_ps? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];

//invtlb
wire [TLBNUM - 1:0] invtlb_choice[31:0];          // choice : 选择对应 invtlb_op表项
wire [TLBNUM - 1:0] cond1;                      // cond1: G 域等于 0
wire [TLBNUM - 1:0] cond2;                      // cond2: G 域等于 1
wire [TLBNUM - 1:0] cond3;                      // cond3: s1_asid 是否等于 ASID 域
wire [TLBNUM - 1:0] cond4;                      // cond4: s1_vppn 是否匹配 VPPN 和 PS 域
assign cond1 = {
    ~tlb_g[15],~tlb_g[14],~tlb_g[13],~tlb_g[12],~tlb_g[11],~tlb_g[10],~tlb_g[ 9],~tlb_g[ 8],~tlb_g[ 7],~tlb_g[ 6],~tlb_g[ 5],~tlb_g[ 4],~tlb_g[ 3],~tlb_g[ 2],~tlb_g[ 1],~tlb_g[ 0]
};
assign cond2 = {
    tlb_g[15],tlb_g[14],tlb_g[13],tlb_g[12],tlb_g[11],tlb_g[10],tlb_g[ 9],tlb_g[ 8],tlb_g[ 7],tlb_g[ 6],tlb_g[ 5],tlb_g[ 4],tlb_g[ 3],tlb_g[ 2],tlb_g[ 1],tlb_g[ 0]
};
assign cond3[ 0] = s1_asid == tlb_asid[ 0];
assign cond3[ 1] = s1_asid == tlb_asid[ 1];
assign cond3[ 2] = s1_asid == tlb_asid[ 2];
assign cond3[ 3] = s1_asid == tlb_asid[ 3];
assign cond3[ 4] = s1_asid == tlb_asid[ 4];
assign cond3[ 5] = s1_asid == tlb_asid[ 5];
assign cond3[ 6] = s1_asid == tlb_asid[ 6];
assign cond3[ 7] = s1_asid == tlb_asid[ 7];
assign cond3[ 8] = s1_asid == tlb_asid[ 8];
assign cond3[ 9] = s1_asid == tlb_asid[ 9];
assign cond3[10] = s1_asid == tlb_asid[10];
assign cond3[11] = s1_asid == tlb_asid[11];
assign cond3[12] = s1_asid == tlb_asid[12];
assign cond3[13] = s1_asid == tlb_asid[13];
assign cond3[14] = s1_asid == tlb_asid[14];
assign cond3[15] = s1_asid == tlb_asid[15];

assign cond4[ 0] = (s1_vppn[18:9] == tlb_vppn[ 0][18:9]) && (tlb_ps4MB[ 0] || s1_vppn[8:0] == tlb_vppn[ 0][8:0]);
assign cond4[ 1] = (s1_vppn[18:9] == tlb_vppn[ 1][18:9]) && (tlb_ps4MB[ 1] || s1_vppn[8:0] == tlb_vppn[ 1][8:0]);
assign cond4[ 2] = (s1_vppn[18:9] == tlb_vppn[ 2][18:9]) && (tlb_ps4MB[ 2] || s1_vppn[8:0] == tlb_vppn[ 2][8:0]);
assign cond4[ 3] = (s1_vppn[18:9] == tlb_vppn[ 3][18:9]) && (tlb_ps4MB[ 3] || s1_vppn[8:0] == tlb_vppn[ 3][8:0]);
assign cond4[ 4] = (s1_vppn[18:9] == tlb_vppn[ 4][18:9]) && (tlb_ps4MB[ 4] || s1_vppn[8:0] == tlb_vppn[ 4][8:0]);
assign cond4[ 5] = (s1_vppn[18:9] == tlb_vppn[ 5][18:9]) && (tlb_ps4MB[ 5] || s1_vppn[8:0] == tlb_vppn[ 5][8:0]);
assign cond4[ 6] = (s1_vppn[18:9] == tlb_vppn[ 6][18:9]) && (tlb_ps4MB[ 6] || s1_vppn[8:0] == tlb_vppn[ 6][8:0]);
assign cond4[ 7] = (s1_vppn[18:9] == tlb_vppn[ 7][18:9]) && (tlb_ps4MB[ 7] || s1_vppn[8:0] == tlb_vppn[ 7][8:0]);
assign cond4[ 8] = (s1_vppn[18:9] == tlb_vppn[ 8][18:9]) && (tlb_ps4MB[ 8] || s1_vppn[8:0] == tlb_vppn[ 8][8:0]);
assign cond4[ 9] = (s1_vppn[18:9] == tlb_vppn[ 9][18:9]) && (tlb_ps4MB[ 9] || s1_vppn[8:0] == tlb_vppn[ 9][8:0]);
assign cond4[10] = (s1_vppn[18:9] == tlb_vppn[10][18:9]) && (tlb_ps4MB[10] || s1_vppn[8:0] == tlb_vppn[10][8:0]);
assign cond4[11] = (s1_vppn[18:9] == tlb_vppn[11][18:9]) && (tlb_ps4MB[11] || s1_vppn[8:0] == tlb_vppn[11][8:0]);
assign cond4[12] = (s1_vppn[18:9] == tlb_vppn[12][18:9]) && (tlb_ps4MB[12] || s1_vppn[8:0] == tlb_vppn[12][8:0]);
assign cond4[13] = (s1_vppn[18:9] == tlb_vppn[13][18:9]) && (tlb_ps4MB[13] || s1_vppn[8:0] == tlb_vppn[13][8:0]);
assign cond4[14] = (s1_vppn[18:9] == tlb_vppn[14][18:9]) && (tlb_ps4MB[14] || s1_vppn[8:0] == tlb_vppn[14][8:0]);
assign cond4[15] = (s1_vppn[18:9] == tlb_vppn[15][18:9]) && (tlb_ps4MB[15] || s1_vppn[8:0] == tlb_vppn[15][8:0]);


assign invtlb_choice[ 0] = 16'hffff; //cond1 || cond2
assign invtlb_choice[ 1] = 16'hffff; //cond1 || cond2
assign invtlb_choice[ 2] =  cond2;
assign invtlb_choice[ 3] =  cond1;
assign invtlb_choice[ 4] =  {
    cond1[15]&cond3[15],cond1[14]&cond3[14],cond1[13]&cond3[13],cond1[12]&cond3[12],cond1[11]&cond3[11],cond1[10]&cond3[10],cond1[9]&cond3[9],cond1[8]&cond3[8],cond1[7]&cond3[7],cond1[6]&cond3[6],cond1[5]&cond3[5],cond1[4]&cond3[4],cond1[3]&cond3[3],cond1[2]&cond3[2],cond1[1]&cond3[1],cond1[0]&cond3[0]
}; //cond1 && cond3
assign invtlb_choice[ 5] ={
    cond1[15]&cond3[15]&cond4[15],cond1[14]&cond3[14]&cond4[14],cond1[13]&cond3[13]&cond4[13],cond1[12]&cond3[12]&cond4[12],cond1[11]&cond3[11]&cond4[11],cond1[10]&cond3[10]&cond4[10],cond1[9]&cond3[9]&cond4[9],cond1[8]&cond3[8]&cond4[8],cond1[7]&cond3[7]&cond4[7],cond1[6]&cond3[6]&cond4[6],cond1[5]&cond3[5]&cond4[5],cond1[4]&cond3[4]&cond4[4],cond1[3]&cond3[3]&cond4[3],cond1[2]&cond3[2]&cond4[2],cond1[1]&cond3[1]&cond4[1],cond1[0]&cond3[0]&cond4[0]
}; //cond1 && cond3 && cond4
assign invtlb_choice[ 6] =  match1;

assign invtlb_choice[ 7] =  16'h0000; 
assign invtlb_choice[ 8] =  16'h0000;
assign invtlb_choice[ 9] =  16'h0000;
assign invtlb_choice[10] =  16'h0000;
assign invtlb_choice[11] =  16'h0000;
assign invtlb_choice[12] =  16'h0000;
assign invtlb_choice[13] =  16'h0000;
assign invtlb_choice[14] =  16'h0000;
assign invtlb_choice[15] =  16'h0000;
assign invtlb_choice[16] =  16'h0000;
assign invtlb_choice[17] =  16'h0000;
assign invtlb_choice[18] =  16'h0000;
assign invtlb_choice[19] =  16'h0000;
assign invtlb_choice[20] =  16'h0000;
assign invtlb_choice[21] =  16'h0000;
assign invtlb_choice[22] =  16'h0000;
assign invtlb_choice[23] =  16'h0000;
assign invtlb_choice[24] =  16'h0000;
assign invtlb_choice[25] =  16'h0000;
assign invtlb_choice[26] =  16'h0000;
assign invtlb_choice[27] =  16'h0000;
assign invtlb_choice[28] =  16'h0000;
assign invtlb_choice[29] =  16'h0000;
assign invtlb_choice[30] =  16'h0000;
assign invtlb_choice[31] =  16'h0000;

//write port
always @(posedge clk) begin
    if(we)begin
            tlb_e   [w_index] <= w_e;
            tlb_vppn[w_index] <= w_vppn;
            tlb_asid[w_index] <= w_asid;
            tlb_g   [w_index] <= w_g;
            tlb_ppn0[w_index] <= w_ppn0;
            tlb_plv0[w_index] <= w_plv0;
            tlb_mat0[w_index] <= w_mat0;
            tlb_d0  [w_index] <= w_d0;
            tlb_v0  [w_index] <= w_v0;
            tlb_ppn1[w_index] <= w_ppn1;
            tlb_plv1[w_index] <= w_plv1;
            tlb_mat1[w_index] <= w_mat1;
            tlb_d1  [w_index] <= w_d1;
            tlb_v1  [w_index] <= w_v1;
            if(w_ps == 6'd21)begin
                tlb_ps4MB[w_index] <= 1'b1;
            end
            else if(w_ps == 6'd12) begin
                tlb_ps4MB[w_index] <= 1'b0;
            end
    end
    else if(invtlb_valid)begin
        tlb_e <= ~invtlb_choice[invtlb_op] & tlb_e;
    end
end

//read port
assign r_e   = tlb_e   [r_index];
assign r_vppn = tlb_vppn[r_index];
assign r_ps   = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
assign r_asid = tlb_asid[r_index];
assign r_g   = tlb_g   [r_index];
assign r_ppn0 = tlb_ppn0[r_index];
assign r_plv0 = tlb_plv0[r_index];
assign r_mat0 = tlb_mat0[r_index];
assign r_d0  = tlb_d0  [r_index];
assign r_v0  = tlb_v0  [r_index];
assign r_ppn1 = tlb_ppn1[r_index];
assign r_plv1 = tlb_plv1[r_index];
assign r_mat1 = tlb_mat1[r_index];
assign r_d1  = tlb_d1  [r_index];
assign r_v1  = tlb_v1  [r_index];

endmodule