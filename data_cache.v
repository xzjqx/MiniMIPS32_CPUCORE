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
`define MEM_WRITE     1'b1

module data_cache #(parameter
	TAG_WIDTH = 22,
	INDEX_WIDTH = 4,
	OFFSET_WIDTH = 6,
	NUM_ASSOC = 4
	`define NUM_DCACHE_LINES (2 ** (INDEX_WIDTH  + 2))
	`define NUM_REG_PER_LINE (2 ** (OFFSET_WIDTH - 2))
) (
	// clock and reset
	input  wire 					cache_rst,
	input  wire 					cache_clk,

	//与cpu相连的信号
    input  wire [3   :   0  	]	cpu_req,
    input  wire 					cpu_wr,
    input  wire [`DATA_ADDR_BUS	]   cpu_addr,
    input  wire [`DATA_BUS		]   cpu_wdata,
	
    output wire                     operation_ok,
    output wire [`DATA_BUS		]   cpu_rdata,

	//data_ram like
    output wire [3   :   0  	]	ram_req,
    output wire 					ram_wr,
    output wire 					uncached,
    // output wire [`RW_SIZE_BUS   ]   ram_size,
    output wire [`DATA_ADDR_BUS	]   ram_addr,
    output wire [`DATA_BUS		]   ram_wdata,

    input  wire 					ram_addr_ok,
	input  wire						ram_beat_ok,
    input  wire 					ram_data_ok,
    input  wire [`DATA_BUS		]   ram_rdata
);

	//将tag、index、offset从地址中分离出来
	wire [TAG_WIDTH-1:0		] addr_tag		= cpu_addr[31:(INDEX_WIDTH + OFFSET_WIDTH)];
	wire [INDEX_WIDTH-1:0	] addr_index	= cpu_addr[(INDEX_WIDTH + OFFSET_WIDTH)-1:OFFSET_WIDTH];
	wire [OFFSET_WIDTH-3:0	] addr_offset	= cpu_addr[OFFSET_WIDTH-1 : 2];

	// 根据参数定义若干个32位寄存器，组成Cache
	reg [`REG_BUS] 	regs[0:`NUM_DCACHE_LINES * `NUM_REG_PER_LINE -1];

	// 定义与行数相同数量的tag寄存器和valid寄存器
	reg [TAG_WIDTH-1:0]  tags[0:`NUM_DCACHE_LINES-1];
	reg	[1 : 0] lru_bits[0 : `NUM_DCACHE_LINES - 1];	
	reg	valid_bits [0:`NUM_DCACHE_LINES-1];	
			
	// CPU送来的请求信号延迟一个周期作为cache的驱动信号
	reg req;
	always @(posedge cache_clk) begin
		req <= (cache_rst == `RST_ENABLE) ? `FALSE_V :
				(|cpu_req && !req) ? `TRUE_V :
				operation_ok ? `FALSE_V : req;
	end
	
	// 读/写命中信号及一组内的命中行数
	wire hit = (cache_rst == `RST_ENABLE) ? `FALSE_V :
			// (req == `FALSE_V) ? `FALSE_V : 
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
				(~cpu_wr & hit & ~uncached) ? 
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] :
				(uncached & ram_data_ok) ? ram_rdata : `ZERO_WORD;
	
	// 送给类SRAM-AXI转换桥接口的信号（相当于送至RAM）
	// 当读miss时发出对cache一行的读请求，当写时发出对由CPU指定的地址和size的写请求
	assign ram_req = (cache_rst == `RST_ENABLE) ? 4'b0 : 
				(req & ~cpu_wr & ~hit & ~uncached 
					|| uncached || req & cpu_wr) ? ((~ram_data_ok) ? cpu_req : 4'b0) : 4'b0;
	// 如果是读kseg1的数据（地址0xA000_0000~0xBFFF_FFF）
	// 由于kseg1为Uncached属性，故不能从Cache中读出，需直接访问ram
	assign uncached = (cache_rst == `RST_ENABLE) ? `FALSE_V :
				(req && ~cpu_wr && (cpu_addr[31:29] == 3'b101)) ? `TRUE_V : `FALSE_V;
	assign ram_wr = (cache_rst == `RST_ENABLE) ? `FALSE_V : 
				(req & ~cpu_wr & ~hit & ~uncached || uncached) ? `MEM_READ :
				(req &  cpu_wr) ? `MEM_WRITE : `FALSE_V;
    // assign ram_size = (cache_rst == `RST_ENABLE) ? 2'b00 :
	// 			(req & ~cpu_wr & ~hit & ~uncached) ? 2'b10 :
	// 			(uncached) ? cpu_size :
	// 			(req &  cpu_wr) ? cpu_size : 2'b00;
	// 需要把CPU发出的虚地址转换为实地址，再送至ram
	assign ram_addr = (cache_rst == `RST_ENABLE) ? `ZERO_WORD : 
				(req & ~cpu_wr & ~hit & ~uncached) ? 
				{cpu_addr[31:OFFSET_WIDTH],{OFFSET_WIDTH{1'b0}}} :
				(uncached) ? cpu_addr[31:0] :
				(req &  cpu_wr) ? cpu_addr[31:0] : `ZERO_WORD;
	assign ram_wdata = (cache_rst == `RST_ENABLE) ? `ZERO_WORD : 
				(req & ~cpu_wr & ~hit) ? `ZERO_WORD :
				(req &  cpu_wr) ? cpu_wdata : `ZERO_WORD;
				
	// 送给CPU的读/写操作完成信号
	assign operation_ok = (cache_rst == `RST_ENABLE) ? `FALSE_V : 
				(~cpu_wr & hit) ? `TRUE_V : // 读直接hit或者读miss导致更新一行之后hit，操作完成
				(uncached  & ram_data_ok) ? `TRUE_V : // 读uncached区域时待ram返回ok，操作完成
				(req &  cpu_wr &  hit & ram_data_ok) ? `TRUE_V : // 写hit也要等待ram返回ok，操作完成
				(req &  cpu_wr & ~hit & ram_data_ok) ? `TRUE_V : // 写miss时等待ram返回ok，操作完成
				`FALSE_V;
	
	// 几种情况下对cache中数据的修改
	integer i; // 循环体计数
	reg  [OFFSET_WIDTH-3 : 0] cnt; // 记录写cache时的字数
	wire [1 : 0] lru_temp = lru_bits[addr_index * NUM_ASSOC + lucky];
	wire [`DATA_BUS ] word_temp = // 要被替换的字的旧值
		regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset];
	/* wire victim = (cache_rst == `RST_ENABLE) ? `FALSE_V : 
			(~lru_bits[addr_index * NUM_ASSOC    ]) ? 1'b0 : 
			(~lru_bits[addr_index * NUM_ASSOC + 1]) ? 1'b1 : 
			`FALSE_V;// 确定组内要被替换的行 */
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
			for(i = 0;i <= `NUM_DCACHE_LINES-1;i=i+1) begin
				valid_bits[i]	<= `FALSE_V;
				lru_bits[i] 	<= 2'd0;
				tags[i] 		<= {TAG_WIDTH{1'b0}};
			end
			cnt <= {(OFFSET_WIDTH-2){1'b0}};
		end
		// 读hit时更新命中组的所有行的lru位
		else if(req & ~cpu_wr & ~uncached & hit) begin
			for (i = 0; i < NUM_ASSOC;i = i + 1) begin
				if (/*valid_bits[addr_index * NUM_ASSOC + i] &&*/ lru_bits[addr_index * NUM_ASSOC + i] < lru_temp)
					lru_bits[addr_index * NUM_ASSOC + i] <= lru_bits[addr_index * NUM_ASSOC + i] + 1;
			end
			lru_bits[addr_index * NUM_ASSOC + lucky] <= 2'd0;	
		end	
		// 读miss时根据LRU策略替换cache的victim行
		else if (req & ~cpu_wr & ~hit & ~uncached & ram_beat_ok) begin
			if(cnt == {(OFFSET_WIDTH-2){1'b1}}) begin
				regs[(addr_index * NUM_ASSOC + victim) * `NUM_REG_PER_LINE + cnt] 
					<= ram_rdata;
				valid_bits[addr_index * NUM_ASSOC + victim] <= `TRUE_V;
				tags[addr_index * NUM_ASSOC + victim] <= addr_tag;
		  		cnt <= {(OFFSET_WIDTH-2){1'b0}};
				for (i = 0; i < NUM_ASSOC;i = i + 1) begin
					if (/*valid_bits[addr_index * NUM_ASSOC + i] &&*/ i != victim)
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
		// 写hit时按照addr和size更新一个字，更新改组的所有行的lru
		else if (req & cpu_wr & hit) begin
				// 写hit时更新该组所有行的lru
				for (i = 0; i < NUM_ASSOC;i = i + 1) begin
					if (/*valid_bits[addr_index * NUM_ASSOC + i] &&*/ lru_bits[addr_index * NUM_ASSOC + i] < lru_temp)
						lru_bits[addr_index * NUM_ASSOC + i] <= lru_bits[addr_index * NUM_ASSOC + i] + 1;
				end
				lru_bits[addr_index * NUM_ASSOC + lucky] <= 2'd0;
			if (/*cpu_size == 2'b00*/cpu_req == 4'd1 || cpu_req == 4'd2 || cpu_req == 4'd4 || cpu_req == 4'd8) begin
                if (cpu_req == 4'd1) 
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {word_temp[31:8],cpu_wdata[7:0]};
				else if (cpu_req == 4'd2)
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {word_temp[31:16],cpu_wdata[15:8],word_temp[7:0]};
				else if (cpu_req == 4'd4)
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {word_temp[31:24],cpu_wdata[23:16],word_temp[15:0]};
				else if (cpu_req == 4'd8)
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {cpu_wdata[31:24],word_temp[23:0]};
				else 
					valid_bits[0] <= valid_bits[0];
				// if (cpu_addr[1:0] == 2'b00) 
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {word_temp[31:8],cpu_wdata[7:0]};
				// else if (cpu_addr[1:0] == 2'b01)
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {word_temp[31:16],cpu_wdata[15:8],word_temp[7:0]};
				// else if (cpu_addr[1:0] == 2'b10)
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {word_temp[31:24],cpu_wdata[23:16],word_temp[15:0]};
				// else if (cpu_addr[1:0] == 2'b11)
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {cpu_wdata[31:24],word_temp[23:0]};
				// else 
				// 	valid_bits[0] <= valid_bits[0];
			end
			else if (/*cpu_size == 2'b01*/cpu_req == 4'd3 || cpu_req == 4'd12) begin
                if (cpu_req == 4'd3) 
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {word_temp[31:16],cpu_wdata[15: 0]};
				else if (cpu_req == 4'd12)
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
						<= {cpu_wdata[31:16],word_temp[15:0]};
				else 
					valid_bits[0] <= valid_bits[0];
				// if (cpu_addr[1:0] == 2'b00) 
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {word_temp[31:16],cpu_wdata[15: 0]};
				// else if (cpu_addr[1:0] == 2'b10)
				// 	regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
				// 		<= {cpu_wdata[31:16],word_temp[15:0]};
				// else 
				// 	valid_bits[0] <= valid_bits[0];
			end
			else if (/*cpu_size == 2'b10*/cpu_req == 4'd15) begin
					regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] 
					<= cpu_wdata;
			end
			else
				valid_bits[0] <= valid_bits[0];
		end
		// 补全if-else的无聊操作
		else 
			valid_bits[0] <= valid_bits[0];
	end
			
endmodule