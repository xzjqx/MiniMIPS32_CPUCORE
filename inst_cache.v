`include "defines.v"
/*
Cache size : 4KB
Block size : 64B
Associate : 4
Line number : 64
*/
`define DATA_ADDR_BUS 31:0
`define DATA_BUS      31:0
`define RW_SIZE_BUS   2 :0
`define MEM_READ      1'b0

module inst_cache #(parameter
	TAG_WIDTH = 22,
	INDEX_WIDTH = 4,
	OFFSET_WIDTH = 6,
	NUM_ASSOC = 4
	`define NUM_ICACHE_LINES (2 ** (INDEX_WIDTH  + 2))
	`define NUM_REG_PER_LINE (2 ** (OFFSET_WIDTH - 2))
) (
	// clock and reset
	input  wire 					cache_rst,
	input  wire 					cache_clk,

	//与cpu相连的信号
    input  wire 					cpu_req,
    input  wire [`DATA_ADDR_BUS	]   cpu_addr,
	
    output wire                     operation_ok,
    output wire [`DATA_BUS		]   cpu_rdata,

	//inst_ram like
    output wire [3   :   0  	]	ram_req,
    output wire 					ram_wr,
    output wire 				    uncached,
    // output wire [`RW_SIZE_BUS	]	ram_size,
    output wire [`DATA_ADDR_BUS	]   ram_addr,
    output wire [`DATA_BUS		]	ram_wdata,

    input  wire 					ram_addr_ok,
	input  wire						ram_beat_ok,
    input  wire 					ram_data_ok,
    input  wire [`DATA_BUS		]   ram_rdata
);

	//将tag、index、offset从地址中分离出来
	wire [TAG_WIDTH-1 : 0	] addr_tag 		= cpu_addr[31 : (INDEX_WIDTH + OFFSET_WIDTH)];
	wire [INDEX_WIDTH-1 : 0	] addr_index 	= cpu_addr[(INDEX_WIDTH + OFFSET_WIDTH) - 1 : OFFSET_WIDTH];
	wire [OFFSET_WIDTH-3 : 0] addr_offset 	= cpu_addr[OFFSET_WIDTH - 1 : 2];

	// 根据参数定义若干个32位寄存器，组成Cache
	reg [`REG_BUS] 	regs[0:`NUM_ICACHE_LINES * `NUM_REG_PER_LINE - 1];

	// 根据参数为Cache每行定义tag位、valid位、lru位
	reg	valid_bits[0 : `NUM_ICACHE_LINES - 1];
	reg	[1 : 0] lru_bits[0 : `NUM_ICACHE_LINES - 1];
	reg [TAG_WIDTH-1 : 0] tags[0 : `NUM_ICACHE_LINES - 1];

	
	// CPU送来的请求信号延迟一个周期作为cache的驱动信号
	reg req;
	always @(posedge cache_clk) begin
		req <= (cache_rst == `RST_ENABLE) ? `FALSE_V :
				(cpu_req && !req) ? `TRUE_V :
				operation_ok ? `FALSE_V : req;
	end
	
	// 读命中信号及一组内的命中行数
	wire hit = (cache_rst == `RST_ENABLE) ? `FALSE_V :
			(uncached == `TRUE_V) ? `FALSE_V : 
			(addr_tag == tags[addr_index * NUM_ASSOC    ] 
				&& valid_bits[addr_index * NUM_ASSOC    ]) ? `TRUE_V :
			(addr_tag == tags[addr_index * NUM_ASSOC + 1] 
				&& valid_bits[addr_index * NUM_ASSOC + 1]) ? `TRUE_V :
			(addr_tag == tags[addr_index * NUM_ASSOC + 2] 
				&& valid_bits[addr_index * NUM_ASSOC + 2]) ? `TRUE_V :
			(addr_tag == tags[addr_index * NUM_ASSOC + 3] 
				&& valid_bits[addr_index * NUM_ASSOC + 3]) ? `TRUE_V :
			`FALSE_V;
	wire [1:0] lucky = (cache_rst == `RST_ENABLE) ? `FALSE_V :
			(hit == `FALSE_V) ? `FALSE_V : 
			(addr_tag == tags[addr_index * NUM_ASSOC    ] 
				&& valid_bits[addr_index * NUM_ASSOC    ]) ? 2'd0 :
			(addr_tag == tags[addr_index * NUM_ASSOC + 1] 
				&& valid_bits[addr_index * NUM_ASSOC + 1]) ? 2'd1 :
			(addr_tag == tags[addr_index * NUM_ASSOC + 2] 
				&& valid_bits[addr_index * NUM_ASSOC + 2]) ? 2'd2 :
			(addr_tag == tags[addr_index * NUM_ASSOC + 3] 
				&& valid_bits[addr_index * NUM_ASSOC + 3]) ? 2'd3 :
			`FALSE_V;
	// 根据命中情况和行号读出命中的指令送至CPU
	assign cpu_rdata = (cache_rst == `RST_ENABLE) ? `ZERO_WORD :
            (hit & ~uncached) ? 
				regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] :
			(uncached & ram_data_ok) ? ram_rdata : `ZERO_WORD;

	// 送给SRAM-AXI转换桥接口的信号（相当于送至RAM）
	// 当读miss时发出对cache一行的读请求
	assign ram_req = (cache_rst == `RST_ENABLE) ? 4'b0 : 
	            (cpu_addr[31:20] == 12'hbfc) ? 4'b0 :
				(req & ~hit & ~uncached || uncached) ? {4{~ram_data_ok}} : 4'b0;
	// 如果是读kseg1的数据（地址0xA000_0000~0xBFFF_FFF）
	// 由于kseg1为Uncached属性，故不能从Cache中读出，需直接访问ram
	assign uncached = /*  */(cache_rst == `RST_ENABLE) ? `FALSE_V :
                (cpu_addr[31:29] == 3'b101) ? `TRUE_V : `FALSE_V;
				// (req && cpu_addr[31:29] == 3'b101) ? `TRUE_V : `FALSE_V;
	// 需要把CPU发出的虚地址转换为实地址，再送至ram
	assign ram_addr = (cache_rst == `RST_ENABLE) ? `ZERO_WORD : 
				(req & ~hit & ~uncached) ? 
				{cpu_addr[31:OFFSET_WIDTH],{OFFSET_WIDTH{1'b0}}} :
				(uncached) ? cpu_addr[31:0] :
				`ZERO_WORD;
	assign ram_wr = `MEM_READ;
    // assign ram_size = 2'b10;
	assign ram_wdata = `ZERO_WORD;
	
	// 送给CPU的读操作完成信号
	assign operation_ok =  (cache_rst == `RST_ENABLE) ? `FALSE_V : 
                (hit) ? `TRUE_V : // 读直接hit或者读miss导致更新一行之后hit，操作完成
				(uncached  & ram_data_ok) ? `TRUE_V : // 读uncached区域时待ram返回ok，操作完成
				`FALSE_V;
	
	//循环中计数
	integer		i;
	reg	[OFFSET_WIDTH-3:0]	cnt;
	wire [1 : 0] lru_temp = lru_bits[addr_index * NUM_ASSOC + lucky];
	
	wire [1 : 0] max1 = (cache_rst == `RST_ENABLE) ? 2'd0 :
						(lru_bits[addr_index * NUM_ASSOC] > lru_bits[addr_index * NUM_ASSOC + 1]) ? 
							lru_bits[addr_index * NUM_ASSOC] : lru_bits[addr_index * NUM_ASSOC + 1];
	wire [1 : 0] max11 = (cache_rst == `RST_ENABLE) ? 2'd0 :
						(lru_bits[addr_index * NUM_ASSOC] > lru_bits[addr_index * NUM_ASSOC + 1]) ? 2'd0 : 2'd1;
	wire [1 : 0] max2 = (cache_rst == `RST_ENABLE) ? 2'd0 :
						(lru_bits[addr_index * NUM_ASSOC + 2] > lru_bits[addr_index * NUM_ASSOC + 3]) ? 
							lru_bits[addr_index * NUM_ASSOC + 2] : lru_bits[addr_index * NUM_ASSOC + 3];
	wire [1 : 0] max22 = (cache_rst == `RST_ENABLE) ? 2'd0 :
						(lru_bits[addr_index * NUM_ASSOC + 2] > lru_bits[addr_index * NUM_ASSOC + 3]) ? 2'd2 : 2'd3;
	wire [1 : 0] victim = (cache_rst == `RST_ENABLE) ? 2'd0 :
						(max1 > max2) ? max11 : max22;
	
	always @(posedge cache_clk) begin
		// 复位时对cache的tag、valid、lru位清零，cnt置零
		if(cache_rst == `RST_ENABLE) begin
			for(i = 0;i <= `NUM_ICACHE_LINES-1;i=i+1) begin
				valid_bits[i]	<= `FALSE_V;
				lru_bits[i] 	<= 2'd0;
				tags[i] 		<= {TAG_WIDTH{1'b0}};
			end
			cnt <= {(OFFSET_WIDTH-2){1'b0}};
		end
		// 读hit时更新命中组的所有行的lru位
		else if(req & ~uncached & hit) begin
			for (i = 0; i < NUM_ASSOC;i = i + 1) begin
				if (/* valid_bits[addr_index * NUM_ASSOC + i] && */ lru_bits[addr_index * NUM_ASSOC + i] < lru_temp)
					lru_bits[addr_index * NUM_ASSOC + i] <= lru_bits[addr_index * NUM_ASSOC + i] + 1;
			end
			lru_bits[addr_index * NUM_ASSOC + lucky] <= 2'd0;				
		end		
		// 读miss时根据LRU策略替换cache一行
		else if(req & ~uncached & ~hit & ram_beat_ok) begin
			if(cnt == {(OFFSET_WIDTH-2){1'b1}}) begin
				valid_bits[addr_index * NUM_ASSOC + victim] <= `TRUE_V;
				//lru_bits[addr_index * NUM_ASSOC +  victim] <= `TRUE_V;
				//lru_bits[addr_index * NUM_ASSOC + ~victim] <= `FALSE_V;
				tags[addr_index * NUM_ASSOC + victim] <= addr_tag;
				regs[(addr_index * NUM_ASSOC + victim) * `NUM_REG_PER_LINE + cnt] 
					<= ram_rdata;
		  		cnt <= {(OFFSET_WIDTH-2){1'b0}};
				for (i = 0; i < NUM_ASSOC;i = i + 1) begin
					if (/* valid_bits[addr_index * NUM_ASSOC + i] && */ i != victim) 
						lru_bits[addr_index * NUM_ASSOC + i] <= lru_bits[addr_index * NUM_ASSOC + i] + 1;
				end
				lru_bits[addr_index * NUM_ASSOC + victim] <= 2'd0;
			end
			else begin
				regs[(addr_index * NUM_ASSOC + victim) * `NUM_REG_PER_LINE + cnt] 
					<= ram_rdata;
		  		cnt <= cnt + 1;
			end
		end
		// 补全if-else的无聊操作
		else
			valid_bits[0] <= valid_bits[0];
	end
endmodule