module bridge (
    input               aclk,
    input               aresetn,
//读请求�?�道
    output  [ 3:0]      arid,
    output  [31:0]      araddr,
    output  [ 7:0]      arlen,
    output  [ 2:0]      arsize,
    output  [ 1:0]      arburst,
    output  [ 1:0]      arlock,
    output  [ 3:0]      arcache,
    output  [ 2:0]      arprot,
    output              arvalid,
    input               arready,

//读响应�?�道
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,

//写请求�?�道
    output  [ 3:0]      awid,
    output  [31:0]      awaddr,
    output  [ 7:0]      awlen,
    output  [ 2:0]      awsize,
    output  [ 1:0]      awburst,
    output  [ 1:0]      awlock,
    output  [ 3:0]      awcache,
    output  [ 2:0]      awprot,
    output              awvalid,
    input               awready,

//写数据�?�道
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

//写响应�?�道
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready,

    input               inst_sram_req,
    input               inst_sram_wr,
    input   [ 3:0]      inst_sram_wstrb,
    input   [ 1:0]      inst_sram_size,
    input   [31:0]      inst_sram_addr,
    input   [31:0]      inst_sram_wdata,

    output  [31:0]      inst_sram_rdata,
    output              inst_sram_addr_ok,
    output              inst_sram_data_ok,

    input               data_sram_req,
    input               data_sram_wr,
    input   [ 3:0]      data_sram_wstrb,
    input   [ 1:0]      data_sram_size,
    input   [31:0]      data_sram_addr,
    input   [31:0]      data_sram_wdata,
   
    output              data_sram_addr_ok,
    output              data_sram_data_ok,
    output  [31:0]      data_sram_rdata
);
//读请�??--------------------------------------------------------------
`define AR_REQ_wait     5'b00001
`define AR_REQ_inst     5'b00010
`define AR_REQ_raw      5'b00100 //read after write
`define AR_REQ_data     5'b01000
`define AR_REQ_end      5'b10000

reg [4:0] AR_REQ_state;
reg [4:0] AR_REQ_next_state;

always @(posedge aclk) begin
    if(~aresetn)begin
        AR_REQ_state <= `AR_REQ_wait;
    end else begin
        AR_REQ_state <= AR_REQ_next_state;
    end
end
always @(*) begin
    case(AR_REQ_state)
        `AR_REQ_wait:begin
            if(inst_sram_req)begin
                AR_REQ_next_state = `AR_REQ_inst;
            end else if(data_sram_req & !data_sram_wr)begin
                AR_REQ_next_state = `AR_REQ_raw;
            end else begin
                AR_REQ_next_state = `AR_REQ_wait;
            end
        end
        `AR_REQ_inst:begin
            if(arvalid && arready)begin
                AR_REQ_next_state = `AR_REQ_end;
            end else begin
                AR_REQ_next_state = `AR_REQ_inst;
            end
        end
        `AR_REQ_data:begin
            if(arvalid && arready)begin
                AR_REQ_next_state = `AR_REQ_end;
            end else begin
                AR_REQ_next_state = `AR_REQ_data;
            end
        end
        `AR_REQ_raw:begin
            if(bready & read_after_write_blk)begin//�??么是bready？？？？
                AR_REQ_next_state = `AR_REQ_raw;
            end else begin
                AR_REQ_next_state = `AR_REQ_data;
            end
        end
        `AR_REQ_end:begin
            AR_REQ_next_state = `AR_REQ_wait;
        end
        default:begin
            AR_REQ_next_state = `AR_REQ_wait;
        end
    endcase
end

//读数�??----------------------------------------------------------
`define AR_VAL_wait     5'b001
`define AR_VAL_start    5'b010
`define AR_VAL_end      5'b100

reg [2:0] AR_VAL_state;
reg [2:0] AR_VAL_next_state;

always @(posedge aclk) begin
    if(~aresetn)begin
        AR_VAL_state <= `AR_VAL_wait;
    end else begin
        AR_VAL_state <= AR_VAL_next_state;
    end
end
always @(*) begin
    case(AR_VAL_state)
        `AR_VAL_wait:begin
            if((arvalid & arready)|(|read_data_cnt)|(|read_inst_cnt))begin//
                AR_VAL_next_state = `AR_VAL_start;
            end else begin
                AR_VAL_next_state = `AR_VAL_wait;
            end
        end
        `AR_VAL_start:begin
            if(rvalid & rready)begin
                AR_VAL_next_state = `AR_VAL_end;
            end else begin
                AR_VAL_next_state = `AR_VAL_start;
            end
        end
        `AR_VAL_end:begin
            if(rvalid & rready)begin
                AR_VAL_next_state = `AR_VAL_end;
            end else if((|read_data_cnt)|(|read_inst_cnt))begin
                AR_VAL_next_state = `AR_VAL_start;
            end else begin
                AR_VAL_next_state = `AR_VAL_wait;
            end
        end
        default:begin
            AR_VAL_next_state = `AR_VAL_wait;
        end
    endcase
end


//写请求写数据--------------------------------------------------------------
`define AW_REQ_wait     4'b0001
`define AW_REQ_raw      4'b0010 //read after write
`define AW_REQ_start    4'b0100
`define AW_REQ_end      4'b1000
reg [3:0] AW_REQ_state;
reg [3:0] AW_REQ_next_state;

always @(posedge aclk) begin
    if(~aresetn)begin
        AW_REQ_state <= `AW_REQ_wait;
    end else begin
        AW_REQ_state <= AW_REQ_next_state;
    end
end

always @(*) begin
    case(AW_REQ_state)
        `AW_REQ_wait:begin
            if(data_sram_req & data_sram_wr)begin
                AW_REQ_next_state = `AW_REQ_raw;
            end else begin
                AW_REQ_next_state = `AW_REQ_wait;
            end
        end
        `AW_REQ_raw:begin
            if(rready & read_after_write_blk)begin
                AW_REQ_next_state = `AW_REQ_raw;
            end else begin
                AW_REQ_next_state = `AW_REQ_start;
            end
        end
        `AW_REQ_start:begin
            if(wvalid & wready)begin
                AW_REQ_next_state = `AW_REQ_end;
            end else begin
                AW_REQ_next_state = `AW_REQ_start;
            end
        end
        `AW_REQ_end:begin
            AW_REQ_next_state = `AW_REQ_wait;
        end
        default:begin
            AW_REQ_next_state = `AW_REQ_wait;
        end
    endcase
end

//写响�??----------------------------------------------------------
`define B_wait     5'b001
`define B_start    5'b010
`define B_end      5'b100

reg [2:0] B_state;
reg [2:0] B_next_state;

always @(posedge aclk) begin
    if(~aresetn)begin
        B_state <= `B_wait;
    end else begin
        B_state <= B_next_state;
    end
end

always @(*) begin
    case(B_state)
        `B_wait:begin
            if(wvalid && wready)begin
                B_next_state = `B_start;
            end else begin
                B_next_state = `B_wait;
            end
        end
        `B_start:begin
            if(bvalid & bready)begin
                B_next_state = `B_end;
            end else begin
                B_next_state = `B_start;
            end
        end
        `B_end:begin
            if(bvalid & bready)begin
                B_next_state = `B_end;
            end else if((wvalid & wready) | (|write_cnt) )begin
                B_next_state = `B_start;
            end else begin
                B_next_state = `B_wait;
            end
        end
        default:begin
            B_next_state = `B_wait;
        end
    endcase
end

//接口信号----------------------------------------------------------

//读请求AR----------------------
reg [3:0] arid_reg;
reg [31:0] araddr_reg; 
reg [ 2:0] arsize_reg;
reg arvalid_reg;

assign arid = arid_reg;
assign araddr = araddr_reg;
assign arlen = 8'b0;
assign arsize = arsize_reg;
assign arburst = 2'b1;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;
assign arvalid = arvalid_reg;

always @(posedge aclk)begin
    if(~aresetn)begin
        arid_reg <= 4'b0;
        araddr_reg <= 32'b0;
        arsize_reg <= 3'b0;
    end else if((AR_REQ_state == `AR_REQ_data)|(AR_REQ_next_state == `AR_REQ_data))begin
        arid_reg <= 4'b1;
        araddr_reg <= data_sram_addr;
        arsize_reg <= {1'b0,data_sram_size};
    end else if((AR_REQ_state == `AR_REQ_inst)|(AR_REQ_next_state == `AR_REQ_inst))begin
        arid_reg <= 4'b0;
        arsize_reg <= {1'b0,inst_sram_size};
        araddr_reg <= inst_sram_addr;
    end else begin
        arid_reg <= 4'b0;
        araddr_reg <= 32'b0;
        arsize_reg <= 3'b0;
    end
end 

always @(posedge aclk)begin
    if(~aresetn | arready)begin
        arvalid_reg <= 1'b0;
    end else if((AR_REQ_state == `AR_REQ_inst)|(AR_REQ_state == `AR_REQ_data))begin//
        arvalid_reg <= 1'b1;
    end 
    //else begin
    //    arvalid_reg <= arvalid_reg;
    //end                               //exp16 change
end

//读数据R---------------------
assign rready = (read_data_cnt != 2'b0) | (read_inst_cnt != 2'b0);
reg [3:0] rid_reg;
always @(posedge aclk)begin
    if(~aresetn)begin
        rid_reg <= 4'b0;
    end else if(AR_VAL_next_state == `AR_VAL_wait)begin//
        rid_reg <= 4'b0;
    end else if (rvalid) begin
        rid_reg <= rid;
    end
end

//写请求AW---------------------
reg [31:0] awaddr_reg;
reg [ 2:0] awsize_reg;
reg awvalid_reg;
reg awready_reg;

assign awid = 4'b1;
assign awaddr = awaddr_reg;
assign awlen = 8'b0;
assign awsize = awsize_reg;
assign awburst = 2'b01;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign awvalid = awvalid_reg;

always @(posedge aclk)begin
    if(~aresetn)begin
        awaddr_reg <= 32'b0;
        awsize_reg <= 3'b0;
    end else if(AW_REQ_state == `AW_REQ_start)begin
        awaddr_reg <= data_sram_addr;
        awsize_reg <= {1'b0,data_sram_size};
    end else begin
        awaddr_reg <= 32'b0;
        awsize_reg <= 3'b0;
    end
end

always @(posedge aclk)begin
    if(~aresetn | awready | awready_reg)begin //为什么加awready_reg？？�??
        awvalid_reg <= 1'b0;
    end else if(AW_REQ_state == `AW_REQ_start)begin
        awvalid_reg <= 1'b1;
    end
end

always @(posedge aclk)begin
    if(~aresetn)begin
        awready_reg <= 1'b0;
    end else if(awvalid & awready)begin
        awready_reg <= 1'b1;
    end else if(AW_REQ_next_state == `AW_REQ_end)begin//
        awready_reg <= 1'b0;//
    end
end

//写数据W---------------------
reg [31:0] wdata_reg;
reg [ 3:0] wstrb_reg;
reg wvalid_reg;

assign wid     = 4'b1;
assign wdata   = wdata_reg;
assign wstrb   = wstrb_reg;
assign wlast   = 1'b1;
assign wvalid  = wvalid_reg;

always @(posedge aclk)begin
    if(~aresetn)begin
        wdata_reg <= 32'b0;
        wstrb_reg <= 4'b0;
    end else if(AW_REQ_state == `AW_REQ_start)begin
        wdata_reg <= data_sram_wdata;
        wstrb_reg <= data_sram_wstrb;
    end
end

always @(posedge aclk)begin
    if(~aresetn | wready)begin
        wvalid_reg <= 1'b0;
    end else if(AW_REQ_state == `AW_REQ_start)begin
        wvalid_reg <= 1'b1;
    end else begin
        wvalid_reg <= 1'b0;
    end
end

//写响应B---------------------
reg bready_reg;
assign bready = bready_reg;
always @(posedge aclk)begin
    if(~aresetn | bvalid)begin
        bready_reg <= 1'b0;
    end else if(B_next_state == `B_start)begin
        bready_reg <= 1'b1;
    end else begin
        bready_reg <= 1'b0;
    end
end

//read_cnt&write_cnt----------------
//exp16 ����λ������2bit��Ϊ3bit
reg [2:0] read_data_cnt;
reg [2:0] read_inst_cnt;
reg [2:0] write_cnt;

always @(posedge aclk)begin
    if(~aresetn)begin
        read_data_cnt <= 3'b0;
    end else if((arready & arvalid)&(rready & rvalid))begin
        if ((arid == 4'b1)&(rid == 4'b0)) begin
            read_data_cnt <= read_data_cnt + 3'b1;
        end else if ((arid == 4'b0)&(rid == 4'b1)) begin
            read_data_cnt <= read_data_cnt - 3'b1;//
        end
    end else if(rready & rvalid & (rid==4'b1))begin//exp16 add (rid==4'b1)
        read_data_cnt <= read_data_cnt - 3'b1;
    end else if(arready & arvalid & (arid==4'b1))begin//exp16 add (arid==4'b1)
        read_data_cnt <= read_data_cnt + 3'b1;
    end
end

always @(posedge aclk)begin
    if(~aresetn)begin
        read_inst_cnt <= 3'b0;
    end else if((arready & arvalid)&(rready & rvalid))begin
        if ((arid == 4'b1)&(rid == 4'b0)) begin
            read_inst_cnt <= read_inst_cnt - 3'b1;
        end else if ((arid == 4'b0)&(rid == 4'b1)) begin
            read_inst_cnt <= read_inst_cnt + 3'b1;
        end
    end else if(rready & rvalid & (rid==4'b0))begin//exp16 add (rid==4'b0)
        read_inst_cnt <= read_inst_cnt - 3'b1;
    end else if(arready & arvalid & (arid==4'b0))begin//exp16 add (arid==4'b0)
        read_inst_cnt <= read_inst_cnt + 3'b1;
    end
end

always @(posedge aclk) begin
    if(~aresetn) begin
        write_cnt <= 3'b0;
    end 
    else if((bvalid && bready) && (wvalid && wready)) begin
        write_cnt <= write_cnt;
    end 
    else if(wvalid && wready) begin
        write_cnt <= write_cnt + 3'b1;
    end 
    else if(bvalid && bready) begin
        write_cnt <= write_cnt - 3'b1;
    end
end

//read_after_write_blk----------------
wire read_after_write_blk;
assign read_after_write_blk = arvalid_reg & awvalid_reg & (araddr_reg == awaddr_reg);

//inst buffer & data buffer----------------
reg [31:0] inst_buffer;
reg [31:0] data_buffer;

always @(posedge aclk)begin
    if(~aresetn)begin
        inst_buffer <= 32'b0;
    end else if(rvalid & rready & ~rid[0])begin//
        inst_buffer <= rdata;
    end
end

always @(posedge aclk)begin
    if(~aresetn)begin
        data_buffer <= 32'b0;
    end else if(rvalid & rready & rid[0])begin//
        data_buffer <= rdata;
    end
end

assign inst_sram_rdata = inst_buffer;
assign data_sram_rdata = data_buffer;
assign inst_sram_addr_ok = (AR_REQ_state == `AR_REQ_end) & (arid_reg == 4'b0);
assign inst_sram_data_ok = (AR_VAL_state == `AR_VAL_end) & (rid_reg == 4'b0);
assign data_sram_addr_ok = (AR_REQ_state == `AR_REQ_end) & (arid_reg == 4'b1) | (AW_REQ_state == `AW_REQ_end);
assign data_sram_data_ok = (AR_VAL_state == `AR_VAL_end) & (rid_reg == 4'b1) | (B_state == `B_end); 

endmodule