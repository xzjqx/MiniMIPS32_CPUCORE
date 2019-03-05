`include "defines.v"

module MiniMIPS32_SYS(
/************************SoC添加 begin*******************************/

    input  wire cpu_clk_50M,
    input  wire cpu_rst_n,

    // block ram
    output wire [11     :     0] bfc_addr,
    output wire                  bfc_ce,
    input  wire [`INST_BUS     ] bfc_dout,

    //axi4 interface
	output wire [3 :0]  m0_awid   ,
	output wire [31:0]  m0_awaddr ,
	output wire [7 :0]  m0_awlen  ,
	output wire [2 :0]  m0_awsize ,
	output wire [1 :0]  m0_awburst,
	output wire         m0_awlock ,
	output wire [3 :0]  m0_awcache,
	output wire [2 :0]  m0_awprot ,
	output wire         m0_awvalid,
	input  wire         m0_awready,
    output wire [3 :0]  m0_wid    ,
	output wire [31:0]  m0_wdata  ,
	output wire [3 :0]  m0_wstrb  ,
	output wire         m0_wlast  ,
	output wire         m0_wvalid ,
	input  wire         m0_wready ,
	input  wire [3 :0]  m0_bid    ,
	input  wire [1 :0]  m0_bresp  ,
	input  wire         m0_bvalid ,
	output wire         m0_bready ,
	output wire [3 :0]  m0_arid   ,
	output wire [31:0]  m0_araddr ,
	output wire [7 :0]  m0_arlen  ,
	output wire [2 :0]  m0_arsize ,
	output wire [1 :0]  m0_arburst,
	output wire         m0_arlock ,
	output wire [3 :0]  m0_arcache,
	output wire [2 :0]  m0_arprot ,
	output wire         m0_arvalid,
	input  wire         m0_arready,
	input  wire [3 :0]  m0_rid    ,
	input  wire [31:0]  m0_rdata  ,
	input  wire [1 :0]  m0_rresp  ,
	input  wire         m0_rlast  ,
	input  wire         m0_rvalid ,
	output wire         m0_rready
/************************SoC添加 end*********************************/
    );

    wire [`INST_ADDR_BUS] iaddr;
    wire                  ice;
    wire [`INST_BUS     ] inst;
    wire                  dce;
    wire [`INST_ADDR_BUS] daddr;
    wire [`BSEL_BUS     ] we;
    wire [`INST_BUS     ] din;
    wire [`INST_BUS     ] dout;
/************************SoC添加 begin*******************************/
    wire                  if_data_ok;
    wire                  mem_hit;
/************************SoC添加 end*********************************/

    // 将时钟中断传入CPU核
    wire [`CP0_INT_BUS  ] int_i;
    wire timer_int;
    assign int_i = {5'b0, timer_int};

    MiniMIPS32 minimips32 (
        .cpu_clk_50M(cpu_clk_50M),
        .cpu_rst_n(cpu_rst_n),
        .iaddr(iaddr), 
        .ice(ice),
        .inst(inst),
        .dce(dce),
        .daddr(daddr),
        .we(we),
        .din(din),
        .dm(dout),
        .if_data_ok(if_data_ok),
        .mem_data_ok(mem_hit),
        .int_i(int_i),
        .timer_int(timer_int)
    );
    
/************************SoC修改 begin*******************************/

    //inst sram to cache
    wire        if_req;
    assign      if_req = (ice == 1'b1 && !bfc_ce) ? 1 : 0;
    wire [31:0] if_rdata;
    wire        if_hit;
    wire        inst_addr_ok;
    wire        inst_beat_ok;
    wire        inst_data_ok;
    wire [3 :0] inst_ben;
    wire [31:0] inst_addr_t;
    wire [31:0] inst_rdata;
    wire        inst_uncached;

    // inst cache
    inst_cache inst_cache(
        // clock and reset
        .cache_rst   (cpu_rst_n    ),
        .cache_clk   (cpu_clk_50M  ),

        //与cpu相连的信号
        .cpu_req     (if_req       ),
        .cpu_addr    (iaddr        ),
        .cpu_rdata   (if_rdata     ),
        .operation_ok(if_hit       ),

        //inst_ram like
        .ram_req     (inst_ben     ),
        .uncached    (inst_uncached),
        .ram_addr    (inst_addr_t  ),

        .ram_addr_ok (inst_addr_ok ),
        .ram_beat_ok (inst_beat_ok ),
        .ram_data_ok (inst_data_ok ),
        .ram_rdata   (inst_rdata   )
    );

    wire [31:0] inst_addr;
    vmmap vmmap0 (
        .i_addr(inst_addr_t),
        .o_addr(inst_addr)
    );

    //data sram to cache
    wire [3 :0] mem_req;
    wire        mem_wr;
    assign      mem_wr  = |we;
    assign      mem_req = (dce == 1'b1) ? ((mem_wr) ? we : 4'b1111) : 4'b0000;
    wire        data_addr_ok;
    wire        data_beat_ok;
    wire        data_data_ok;
    wire [3 :0] data_ben;
    wire        data_wr;
    wire [31:0] data_addr_t;
    wire [31:0] data_wdata;
    wire [31:0] data_rdata;
    wire        data_uncached;
    
    // data cache
    data_cache data_cache(
        // clock and reset
        .cache_rst   (cpu_rst_n    ),
        .cache_clk   (cpu_clk_50M  ),

        //与cpu相连的信号
        .cpu_req     (mem_req      ),
        .cpu_wr      (mem_wr       ),
        .cpu_addr    (daddr        ),
        .cpu_wdata   (din          ),
        .operation_ok(mem_hit      ),
        .cpu_rdata   (dout         ),

        //data_ram like
        .ram_req     (data_ben     ),
        .ram_wr      (data_wr      ),
        .uncached    (data_uncached),
        .ram_addr    (data_addr_t  ),
        .ram_wdata   (data_wdata   ),

        .ram_addr_ok (data_addr_ok ),
        .ram_beat_ok (data_beat_ok ),
        .ram_data_ok (data_data_ok ),
        .ram_rdata   (data_rdata   )
    );

    wire [31:0] data_addr;
    vmmap vmmap1 (
        .i_addr(data_addr_t),
        .o_addr(data_addr)
    );

    sram_to_axi sram_to_axi(
       .clk(cpu_clk_50M),
       .resetn(cpu_rst_n),
       //fetch like-sram interface
       .inst_ben     (inst_ben     ),
       .inst_wdata   (`ZERO_WORD   ),
       .inst_wr      (1'b0         ),
       .inst_uncached(inst_uncached),
       .inst_addr    (inst_addr    ),
       .inst_addr_ok (inst_addr_ok ),
       .inst_beat_ok (inst_beat_ok ),
       .inst_data_ok (inst_data_ok ),
       .inst_rdata   (inst_rdata   ),

       //mem like-sram interface
       .data_ben     (data_ben     ),
       .data_wdata   (data_wdata   ),
       .data_wr      (data_wr      ),
       .data_uncached(data_uncached),
       .data_addr    (data_addr    ),
       .data_addr_ok (data_addr_ok ),
       .data_beat_ok (data_beat_ok ),
       .data_data_ok (data_data_ok ),
       .data_rdata   (data_rdata   ),

       //axi interface
       .awid         (m0_awid      ),
       .awaddr       (m0_awaddr    ),
       .awlen        (m0_awlen     ),
       .awsize       (m0_awsize    ),
       .awburst      (m0_awburst   ),
       .awlock       (m0_awlock    ),
       .awcache      (m0_awcache   ),
       .awprot       (m0_awprot    ),
       .awvalid      (m0_awvalid   ),
       .awready      (m0_awready   ),
       .wid          (m0_wid       ),
       .wdata        (m0_wdata     ),
       .wstrb        (m0_wstrb     ),
       .wlast        (m0_wlast     ),
       .wvalid       (m0_wvalid    ),
       .wready       (m0_wready    ),
       .bid          (m0_bid       ),
       .bresp        (m0_bresp     ),
       .bvalid       (m0_bvalid    ),
       .bready       (m0_bready    ),
       .arid         (m0_arid      ),
       .araddr       (m0_araddr    ),
       .arlen        (m0_arlen     ),
       .arsize       (m0_arsize    ),
       .arburst      (m0_arburst   ),
       .arlock       (m0_arlock    ),
       .arcache      (m0_arcache   ),
       .arprot       (m0_arprot    ),
       .arvalid      (m0_arvalid   ),
       .arready      (m0_arready   ),
       .rid          (m0_rid       ),
       .rdata        (m0_rdata     ),
       .rresp        (m0_rresp     ),
       .rlast        (m0_rlast     ),
       .rvalid       (m0_rvalid    ),
       .rready       (m0_rready    )

    );

    reg ice_t;
    always @(posedge cpu_clk_50M) begin
        ice_t <= ice;
    end

    // 仲裁指令来自bootloader还是内存
    assign bfc_ce     = (ice == 1'b1 && iaddr[31:20] == 12'hbfc) ? 1 : 0;
    assign bfc_addr   = iaddr[13:2];
    // assign inst       = if_hit ? if_rdata : bfc_dout;
    assign inst       = (iaddr[31:20] == 12'hbfc) ? bfc_dout : if_rdata;
    assign if_data_ok = (iaddr[31:20] == 12'hbfc) ? ice_t : if_hit;

/************************SoC修改 end*********************************/

endmodule
