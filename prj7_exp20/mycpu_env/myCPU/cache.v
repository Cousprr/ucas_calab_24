`define CIDLE   5'b00001
`define LOOKUP  5'b00010
`define MISS    5'b00100
`define REPLACE 5'b01000
`define REFILL  5'b10000
`define W_IDLE  2'b01
`define W_WRITE 2'b10

module cache(
    input              clk,
    input              resetn,
    //cache & cpu interface
    input              valid,
	input              op,        // 0: read, 1: write
	output             addr_ok,   //该次请求的地址传输 OK，读：地址被接收；写：地址和数据被接收
	output             data_ok,   //该次请求的数据传输 OK，读：数据返回；写：数据写入完成
	output    [ 31:0]  rdata,     //读cache结果
	input     [  3:0]  wstrb,     //写字节使能信号
	input     [ 31:0]  wdata,

	input     [ 19:0]  tag,       //行标签，物理地址paddr[31:12]
	input     [  7:0]  index,     //组索引，虚地址addr[11:4]
	input     [  3:0]  offset,    //cache行内偏移
    //cache & AXI interface
    //read port
    output             rd_req,    //读请求
    output    [  2:0]  rd_type,   //读请求类型:3’b000字节，3’b001半字，3’b010字，3’b100行
	output    [ 31:0]  rd_addr,   //读请求起始地址
	input              rd_rdy,    //读响应
	input              ret_valid, //返回数据有效信号后
	input     [  1:0]  ret_last,  //返回数据是一次读请求对应的最后一个返回数据
	input     [ 31:0]  ret_data,  //读返回数据
    //write port
    output             wr_req,
	output    [  2:0]  wr_type,   //exp20取3’b100
	output    [ 31:0]  wr_addr,
	output    [  3:0]  wr_wstrb,  //写操作的字节掩码。仅在写请求类型wr_type为3’b000，3’b001，3’b010下才有意义，exp20无效
	output    [127:0]  wr_data,
	input              wr_rdy
);

//Cache Controller
    
    //LFSR generate random number
    reg [2:0] lfsr_num;
    always @(posedge clk ) begin
        if(~resetn)begin
            lfsr_num <= 3'b001;
        end
        else begin
            lfsr_num <= {lfsr_num[1:0], lfsr_num[2] ^ lfsr_num[1]};
        end
    end
    reg replace_way;
	always @(posedge clk) begin
    if (~resetn) begin
        replace_way <= 1'b0;
	end
    else if (ret_valid && ret_last) begin
        replace_way <= lfsr_num[0];
	end
end

    //rd
    assign rd_req = state[3];//REPLACE
	assign rd_addr = {tag_r,index_r,4'b00};
	assign rd_type = 3'b100;
	//wr
	reg wr_req_r;
	always@(posedge clk) begin
		if(~resetn)
			wr_req_r <= 1'b0;
		else if(~wr_rdy & state[2] & next_state[3]) //MISS->REPLACE
			wr_req_r <= 1'b1;
		else if(wr_rdy)
			wr_req_r <= 1'b0;
	end
	assign wr_req = wr_req_r;
	assign wr_addr = {replace_addr, index_r, offset_r};
	assign wr_wstrb = 4'b1111;
	assign wr_data = {8'hff, replace_data[119:0]};
	assign wr_type = 3'b100;
    
    //axi-ok
	assign addr_ok = state[0] ||											//IDLE
					 state[1] && valid && cache_hit && op ||				//LOOKUP,cache_hit,op=1
					 state[1] && valid && cache_hit && ~op && ~write_hit_blk;//LOOKUP,cache_hit,op=0,write_hit_blk=0
	assign data_ok = state[1] && cache_hit ||								//LOOKUP,cache_hit
					 state[1] && op_r ||									//LOOKUP,op_r=1
					 state[4] && ret_valid && !op_r && ret_count == r_offset;//REFILL,ret_valid=1,offset[3:2]相等

//assign addr_ok = 1'b1;
//assign data_ok = 1'b1;


//tagv RAM * 2
	wire 	    tag0_we;
	wire  	    tag1_we;
	wire [20:0] tag0_rdata;
	wire [20:0] tag1_rdata;
	wire [ 7:0]	way_tagv_addr;
	wire [20:0]	way_tagv_wdata;
	assign way_tagv_addr 	= state[0] ? index : index_r;
	assign way_tagv_wdata	= {tag_r, 1'b1};
	assign tag0_we 	= ~replace_way && ret_valid && ret_last;
	assign tag1_we 	=  replace_way && ret_valid && ret_last;
	tagv_ram way0_tagv(
		.clka(clk),
		.wea(tag0_we),
		.addra(way_tagv_addr),
		.dina(way_tagv_wdata),
		.douta(tag0_rdata),
		.ena(1'b1)
	);
	tagv_ram way1_tagv(
		.clka(clk),
		.wea(tag1_we),
		.addra(way_tagv_addr),
		.dina(way_tagv_wdata),
		.douta(tag1_rdata),
		.ena(1'b1)
	);
	wire way_valid;
	assign way_valid = replace_way ? tag1_rdata[0] : tag0_rdata[0];
//dirty 写回写分配 修改位
	reg [255:0] dirty [1:0];
	always @(posedge clk ) begin
		if(~resetn)begin
			dirty[0] <= 256'b0;
            dirty[1] <= 256'b0;
		end
		else if(wr_state[1]) begin
			dirty[wbuffer_way][wbuffer_index] <= 1'b1;
		end
		else if(ret_last&&ret_valid) begin
			dirty[replace_way][index_r] <= op_r;
		end
	end


//Request Buffer
    reg        op_r;
    reg [ 7:0] index_r;
    reg [19:0] tag_r;
    reg [ 3:0] offset_r;
    reg [ 3:0] wstrb_r;
    reg [31:0] wdata_r;

    always @(posedge clk ) begin
        if(~resetn) begin
            op_r    <= 1'b0;
			index_r <= 8'b0;
			tag_r   <= 20'b0;
			offset_r<= 4'b0;
			wstrb_r <= 4'b0;
			wdata_r <= 32'b0;
        end
        if(next_state[1]) begin
            op_r    <= op;
			index_r <= index;
			tag_r   <= tag;
			offset_r<= offset;
			wstrb_r <= wstrb;
			wdata_r <= wdata;
        end
    end
	wire [1:0] r_offset;
    assign r_offset = offset_r[3:2];
//Tag Compare
    wire [19:0] way0_tag;
	wire [19:0] way1_tag;
	wire        way0_hit;
	wire        way1_hit;
	wire        cache_hit;
	assign way0_tag = tag0_rdata[20:1];
	assign way1_tag = tag1_rdata[20:1];
	assign way0_hit = tag0_rdata[0] && (way0_tag == tag_r);
	assign way1_hit = tag1_rdata[0] && (way1_tag == tag_r);
    assign cache_hit = way0_hit || way1_hit;

	wire write_hit;
    wire write_hit_blk;
    assign write_hit = cache_hit && op_r;
    assign write_hit_blk = 
	(state[1] && valid && ~op && write_hit && index==index_r && offset==offset_r)||
	//主状态机处于 LOOPUP 状态且发现 Store 操作命中 Cache，此时流水线发来的一个新的 Load 类的 Cache 访问请求，他们地址存在写后读相关
	(wr_state[1] && valid && ~op && offset[3:2]==offset_r[3:2]);
	//写状态机处于 WRITE 状态，此时流水线发来的一个新的 Load 类的 Cache 访问请求，并且该 Load 请求与 Write Buffer 里的待写请求的地址重叠

//Data Select
    wire [31:0]   way0_load_word;
	wire [31:0]   way1_load_word;
	wire [31:0]   load_result;
    //assign way0_load_word = way0_data[pa[3:2]*32 +: 32];
    //assign way1_load_word = way1_data[pa[3:2]*32 +: 32];
    //assign load_res = {32{way0_hit}} & way0_load_word | {32{way1_hit}} & way1_load_word;
	assign way0_load_word = ({32{r_offset == 2'b00}} & rdata_00) |
                       		({32{r_offset == 2'b01}} & rdata_01) |
				       		({32{r_offset == 2'b10}} & rdata_02) |
                       		({32{r_offset == 2'b11}} & rdata_03);
	assign way1_load_word = ({32{r_offset == 2'b00}} & rdata_10) |
                       		({32{r_offset == 2'b01}} & rdata_11) |
					   		({32{r_offset == 2'b10}} & rdata_12) |
                       		({32{r_offset == 2'b11}} & rdata_13);
	assign load_result = {32{way0_hit}} & way0_load_word |
                         {32{way1_hit}} & way1_load_word |
                         {32{ret_valid}} & ret_data;
	assign rdata = load_result;

//Miss Buffer
//random number replace_way from LFSR
	wire [ 19:0] replace_addr;
	wire [127:0] replace_data;
	assign replace_addr = replace_way ? way1_tag : way0_tag;
	assign replace_data = replace_way ? {rdata_13, rdata_12, rdata_11, rdata_10} : {rdata_03, rdata_02, rdata_01, rdata_00};
	
	reg [1:0] ret_count;
	always @(posedge clk) begin
		if(~resetn)
			ret_count <= 2'b0;
		else if(ret_valid && ~ret_last)
			ret_count <= ret_count + 2'b01;
		else if(ret_valid && ret_last)
			ret_count <= 2'b0;
	end
//Write Buffer
	reg        wbuffer_way;
	reg [ 1:0] wbuffer_bank;
	reg [ 7:0] wbuffer_index;
	reg [ 3:0] wbuffer_wstrb;
	reg [31:0] wbuffer_wdata;

always @(posedge clk) begin
    if (~resetn) begin
        wbuffer_way   <= 1'b0;
        wbuffer_bank  <= 2'b00;
        wbuffer_index <= 8'b0;
        wbuffer_wstrb <= 4'b0;
        wbuffer_wdata <= 32'b0;
    end
    else if (state[1] && write_hit) begin
        wbuffer_way   <= way0_hit ? 1'b0 : 1'b1;
        wbuffer_bank  <= r_offset;
        wbuffer_index <= index_r;
        wbuffer_wstrb <= wstrb_r;
        wbuffer_wdata <= wdata_r;
    end
end


//data RAM * 8
    wire [ 3:0] we_00;
	wire [ 7:0] addr_00;
	wire [31:0] wdata_00;
	wire [31:0] rdata_00;
	wire        en_00;
	assign we_00    = wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b00 & op_r) ? wstrb_r : 4'b1111;
	assign addr_00 	= state[0] ? index : index_r;
	assign wdata_00 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b00 & op_r) ? wdata_r : ret_data;
	assign en_00    = wr_state[1] ? (~wbuffer_way & wbuffer_bank == 2'b00) : (~replace_way & ret_count == 2'b00 & ret_valid);
	data_bank_ram bank00(
		.clka(clk), 
		.wea(we_00),
		.addra(addr_00),
		.dina(wdata_00),
		.douta(rdata_00),
		.ena(en_00)
	);

	wire [ 3:0] we_01;
	wire [ 7:0] addr_01;
	wire [31:0] wdata_01;
	wire [31:0] rdata_01;
	wire        en_01;
	assign we_01 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b01 & op_r) ? wstrb_r : 4'b1111;
	assign addr_01 	= state[0] ? index : index_r;
	assign wdata_01 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b01 & op_r) ? wdata_r : ret_data;
	assign en_01    = wr_state[1] ? (~wbuffer_way & wbuffer_bank == 2'b01) : (~replace_way & ret_count == 2'b01 & ret_valid);
	data_bank_ram bank01(
		.clka(clk), 
		.wea(we_01),
		.addra(addr_01),
		.dina(wdata_01),
		.douta(rdata_01),
		.ena(en_01)
	);

	wire [ 3:0] we_02;
	wire [ 7:0] addr_02;
	wire [31:0] wdata_02;
	wire [31:0] rdata_02;
	wire        en_02;
	assign we_02 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b10 & op_r) ? wstrb_r : 4'b1111;
	assign addr_02 	= state[0] ? index : index_r;
	assign wdata_02 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b10 & op_r) ? wdata_r : ret_data;
	assign en_02    = wr_state[1] ? (~wbuffer_way & wbuffer_bank == 2'b10) : (~replace_way & ret_count == 2'b10 & ret_valid);
	data_bank_ram bank02(
		.clka(clk), 
		.wea(we_02),
		.addra(addr_02),
		.dina(wdata_02),
		.douta(rdata_02),
		.ena(en_02)
	);

	wire [ 3:0] we_03;
	wire [ 7:0] addr_03;
	wire [31:0] wdata_03;
	wire [31:0] rdata_03;
	wire        en_03;
	assign we_03 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b11 & op_r) ? wstrb_r : 4'b1111;
	assign addr_03 	= state[0] ? index : index_r;
	assign wdata_03 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b11 & op_r) ? wdata_r : ret_data;
	assign en_03    = wr_state[1] ? (~wbuffer_way & wbuffer_bank == 2'b11) : (~replace_way & ret_count == 2'b11 & ret_valid);
	data_bank_ram bank03(
		.clka(clk), 
		.wea(we_03),
		.addra(addr_03),
		.dina(wdata_03),
		.douta(rdata_03),
		.ena(en_03)
	);

	wire [ 3:0] we_10;
	wire [ 7:0] addr_10;
	wire [31:0] wdata_10;
	wire [31:0] rdata_10;
	wire        en_10;
	assign we_10 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b00 & op_r) ? wstrb_r : 4'b1111;
	assign addr_10 	= state[0] ? index : index_r;
	assign wdata_10 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b00 & op_r) ? wdata_r : ret_data;
	assign en_10    = wr_state[1] ? (wbuffer_way & wbuffer_bank == 2'b00) : (replace_way & ret_count == 2'b00 & ret_valid);
	data_bank_ram bank10(
		.clka(clk), 
		.wea(we_10),
		.addra(addr_10),
		.dina(wdata_10),
		.douta(rdata_10),
		.ena(en_10)
	);

	wire [ 3:0] we_11;
	wire [ 7:0] addr_11;
	wire [31:0] wdata_11;
	wire [31:0] rdata_11;
	wire        en_11;
	assign we_11 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b01 & op_r) ? wstrb_r : 4'b1111;
	assign addr_11 	= state[0] ? index : index_r;
	assign wdata_11 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b01 & op_r) ? wdata_r : ret_data;
	assign en_11    = wr_state[1] ? (wbuffer_way & wbuffer_bank == 2'b01) : (replace_way & ret_count == 2'b01 & ret_valid);
	data_bank_ram bank11(
		.clka(clk), 
		.wea(we_11),
		.addra(addr_11),
		.dina(wdata_11),
		.douta(rdata_11),
		.ena(en_11)
	);

	wire [ 3:0] we_12;
	wire [ 7:0] addr_12;
	wire [31:0] wdata_12;
	wire [31:0] rdata_12;
	wire        en_12;
	assign we_12 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b10 & op_r) ? wstrb_r : 4'b1111;
	assign addr_12 	= state[0] ? index : index_r;
	assign wdata_12 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b10 & op_r) ? wdata_r : ret_data;
	assign en_12    = wr_state[1] ? (wbuffer_way & wbuffer_bank == 2'b10) : (replace_way & ret_count == 2'b10 & ret_valid);
	data_bank_ram bank12(
		.clka(clk), 
		.wea(we_12),
		.addra(addr_12),
		.dina(wdata_12),
		.douta(rdata_12),
		.ena(en_12)
	);

	wire [ 3:0] we_13;
	wire [ 7:0] addr_13;
	wire [31:0] wdata_13;
	wire [31:0] rdata_13;
	wire        en_13;
	assign we_13 	= wr_state[1] ? wbuffer_wstrb : (r_offset == 2'b11 & op_r) ? wstrb_r : 4'b1111;
	assign addr_13 	= state[0] ? index : index_r;
	assign wdata_13 = wr_state[1] ? wbuffer_wdata : (r_offset == 2'b11 & op_r) ? wdata_r : ret_data;
	assign en_13    = wr_state[1] ? (wbuffer_way & wbuffer_bank == 2'b11) : (replace_way & ret_count == 2'b11 & ret_valid);
	data_bank_ram bank13(
		.clka(clk), 
		.wea(we_13),
		.addra(addr_13),
		.dina(wdata_13),
		.douta(rdata_13),
		.ena(en_13)
	);
	
    //主状态机
    reg [4:0] state;
    reg [4:0] next_state;
    always @(posedge clk ) begin
        if(~resetn)begin
            state<=`CIDLE;
        end
        else begin
            state<=next_state;
        end
    end
    always @(*) begin
        case (state)
            `CIDLE:
                if(~write_hit_blk & valid)
                    next_state<=`LOOKUP;
                else if(~valid | valid & write_hit_blk)
                    next_state<=`CIDLE; 
            `LOOKUP:
                if(cache_hit & (write_hit_blk & valid | ~valid))
                    next_state<=`CIDLE;
				else if(cache_hit & valid & ~write_hit_blk)
					next_state<=`LOOKUP;
				else if((~dirty[replace_way][index_r] | ~way_valid) & op_r)
					next_state<=`REPLACE;
                else if(~cache_hit)
                    next_state<=`MISS;
            `MISS:
                if(~wr_rdy)
                    next_state<=`MISS;
                else
                    next_state<=`REPLACE;
            `REPLACE:
                if(~rd_rdy)
                    next_state<=`REPLACE;
                else 
                    next_state<=`REFILL;
            `REFILL:
                if(ret_valid && ret_last)
                    next_state<=`CIDLE;
                else
                    next_state<=`REFILL;

            default: next_state<=`CIDLE;
        endcase
    end
    //写状态机
    reg     [1:0]   wr_state;
    reg     [1:0]   wr_next_state;
    always @(posedge clk ) begin
        if(~resetn)begin
            wr_state<=`W_IDLE;
            end
        else begin
            wr_state<=wr_next_state;
        end
    end
    always @(*) begin
        case (wr_state)
            `W_IDLE:
                if(write_hit & state[1])
                    wr_next_state<=`W_WRITE;
                else
                    wr_next_state<=`W_IDLE;
            `W_WRITE:
                if(write_hit)
                    wr_next_state<=`W_WRITE;
                else
                    wr_next_state<=`W_IDLE;

            default: wr_next_state<=`W_IDLE;
        endcase
    end

endmodule