`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/08/06 18:04:01
// Design Name: 
// Module Name: sram_to_axi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module sram_to_axi(
    input  wire        clk,
    input  wire        resetn, 
    
    // 指令类SRAM接口
    input  wire [`BSEL_BUS] inst_ben,
    input  wire [`INST_BUS] inst_wdata,
    input  wire       inst_wr,
    input  wire       inst_uncached,
    input  wire [`INST_ADDR_BUS] inst_addr,
    output wire       inst_addr_ok,
    output wire       inst_beat_ok,
    output wire       inst_data_ok,
    output wire [`INST_BUS] inst_rdata,

    // 数据类SRAM接口
    input  wire [`BSEL_BUS] data_ben,
    input  wire [`INST_BUS] data_wdata,
    input  wire        data_wr,
    input  wire        data_uncached,
    input  wire [`INST_ADDR_BUS] data_addr,
    output wire        data_addr_ok,
    output wire        data_beat_ok,
    output wire        data_data_ok,
    output wire [`INST_BUS] data_rdata,

    // AXI接口
    // 读地址通道信号
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [7 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock       ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    // 读数据通道信号         
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    // 写地址通道信号  
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [7 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    // 写数据通道信号   
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    // 写响应通道信号        
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       

    );

// 设置取指和取数据通道的相关信号
wire inst_valid;
wire data_valid;
assign inst_valid = |inst_ben;
assign data_valid = |data_ben;

reg do_req;
reg do_req_or;
reg        do_wr_r;
reg [1 :0] do_size_r;
reg [31:0] do_addr_r;
reg [31:0] do_wdata_r;
wire data_back;
wire inst_req;
wire data_req;
reg [3 :0] do_strb_r;
reg [7 :0] do_arlen;
reg [1 :0] do_arburst;

// 将类SRAM接口转化为AXI接口
assign inst_req = inst_valid;
assign data_req = data_valid;
assign inst_addr_ok = !do_req&&!data_req;
assign data_addr_ok = !do_req;
wire [1:0] inst_size;
wire [1:0] data_size;
assign inst_size = 2'b10;
wire [3:0] size;
assign size = (data_ben&1'b1) + ((data_ben>>1)&1'b1) + ((data_ben>>2)&1'b1) + ((data_ben>>3)&1'b1);
assign data_size = (size == 4'd1) ? 2'b00 :
                   (size == 4'd2) ? 2'b01 :
                   (size == 4'd4) ? 2'b10 : 2'b00;
always @(posedge clk)
begin
    do_req     <= !resetn                       ? 1'b0 : 
                  (inst_req||data_req)&&!do_req ? 1'b1 :
                  data_back                     ? 1'b0 : do_req;
    do_req_or  <= !resetn ? 1'b0 : 
                  !do_req ? data_req : do_req_or;
    do_wr_r    <= data_req&&data_addr_ok ? data_wr :
                  inst_req&&inst_addr_ok ? inst_wr : do_wr_r;
    do_size_r  <= data_req&&data_addr_ok ? data_size :
                  inst_req&&inst_addr_ok ? inst_size : do_size_r;
    do_addr_r  <= data_req&&data_addr_ok ? data_addr :
                  inst_req&&inst_addr_ok ? inst_addr : do_addr_r;
    do_strb_r  <= data_req&&data_addr_ok ? data_ben :
                  inst_req&&inst_addr_ok ? inst_ben : do_strb_r;
    do_wdata_r <= data_req&&data_addr_ok ? data_wdata :
                  inst_req&&inst_addr_ok ? inst_wdata :do_wdata_r;
    do_arlen   <= data_req && data_addr_ok && ~data_uncached ? 8'd15 :
                  data_req && data_addr_ok &&  data_uncached ? 8'd0 :
                  inst_req && inst_addr_ok && ~inst_uncached ? 8'd15 :
				  inst_req && inst_addr_ok &&  inst_uncached ? 8'd0 : do_arlen;
	do_arburst <= data_req && data_addr_ok && ~data_uncached ? 2'b01 :
                  data_req && data_addr_ok &&  data_uncached ? 2'b00 :
                  inst_req && inst_addr_ok && ~inst_uncached ? 2'b01 :
				  inst_req && inst_addr_ok &&  inst_uncached ? 2'b00 : do_arburst;
end

reg addr_rcv;
reg wdata_rcv;

always @(posedge clk)
begin
    addr_rcv  <= !resetn          ? 1'b0 :
                 arvalid&&arready ? 1'b1 :
                 awvalid&&awready ? 1'b1 :
                 data_back        ? 1'b0 : addr_rcv;
    wdata_rcv <= !resetn        ? 1'b0 :
                 wvalid&&wready ? 1'b1 :
                 data_back      ? 1'b0 : wdata_rcv;
end

wire beat_back;
assign beat_back = addr_rcv && (rvalid && rready || bvalid && bready);
assign data_back = addr_rcv && (rvalid && rready && rlast || bvalid && bready);

assign inst_beat_ok = do_req&&!do_req_or&&beat_back;
assign inst_data_ok = do_req&&!do_req_or&&data_back;

assign data_beat_ok = do_req&&do_req_or&&beat_back;
assign data_data_ok = do_req&&do_req_or&&data_back;

assign inst_rdata   = rdata;
assign data_rdata   = rdata;

// 设置AXI相关信号
// 读地址通道信号
assign arid    = 4'd0;
assign araddr  = do_addr_r;
assign arlen   = do_arlen;
assign arsize  = do_size_r;
assign arburst = do_arburst;
assign arlock  = 2'd0;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = do_req&&!do_wr_r&&!addr_rcv;
// 读数据通道信号
assign rready  = 1'b1;
// 写地址通道信号
assign awid    = 4'd0;
assign awaddr  = do_addr_r;
assign awlen   = 8'd0;
assign awsize  = {1'b0,do_size_r};
assign awburst = 2'd0;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = do_req&&do_wr_r&&!addr_rcv;
//写数据通道信号
assign wid    = 4'd0;
assign wdata  = do_wdata_r;
assign wstrb  = do_strb_r;
assign wlast  = 1'd1;
assign wvalid = do_req&&do_wr_r&&!wdata_rcv;
//写响应通道信号
assign bready  = 1'b1;

endmodule
