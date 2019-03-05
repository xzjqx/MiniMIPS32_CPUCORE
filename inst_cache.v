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

	//��cpu�������ź�
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

	//��tag��index��offset�ӵ�ַ�з������
	wire [TAG_WIDTH-1 : 0	] addr_tag 		= cpu_addr[31 : (INDEX_WIDTH + OFFSET_WIDTH)];
	wire [INDEX_WIDTH-1 : 0	] addr_index 	= cpu_addr[(INDEX_WIDTH + OFFSET_WIDTH) - 1 : OFFSET_WIDTH];
	wire [OFFSET_WIDTH-3 : 0] addr_offset 	= cpu_addr[OFFSET_WIDTH - 1 : 2];

	// ���ݲ����������ɸ�32λ�Ĵ��������Cache
	reg [`REG_BUS] 	regs[0:`NUM_ICACHE_LINES * `NUM_REG_PER_LINE - 1];

	// ���ݲ���ΪCacheÿ�ж���tagλ��validλ��lruλ
	reg	valid_bits[0 : `NUM_ICACHE_LINES - 1];
	reg	[1 : 0] lru_bits[0 : `NUM_ICACHE_LINES - 1];
	reg [TAG_WIDTH-1 : 0] tags[0 : `NUM_ICACHE_LINES - 1];

	
	// CPU�����������ź��ӳ�һ��������Ϊcache�������ź�
	reg req;
	always @(posedge cache_clk) begin
		req <= (cache_rst == `RST_ENABLE) ? `FALSE_V :
				(cpu_req && !req) ? `TRUE_V :
				operation_ok ? `FALSE_V : req;
	end
	
	// �������źż�һ���ڵ���������
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
	// ��������������кŶ������е�ָ������CPU
	assign cpu_rdata = (cache_rst == `RST_ENABLE) ? `ZERO_WORD :
            (hit & ~uncached) ? 
				regs[(addr_index * NUM_ASSOC + lucky) * `NUM_REG_PER_LINE + addr_offset] :
			(uncached & ram_data_ok) ? ram_rdata : `ZERO_WORD;

	// �͸�SRAM-AXIת���Žӿڵ��źţ��൱������RAM��
	// ����missʱ������cacheһ�еĶ�����
	assign ram_req = (cache_rst == `RST_ENABLE) ? 4'b0 : 
	            (cpu_addr[31:20] == 12'hbfc) ? 4'b0 :
				(req & ~hit & ~uncached || uncached) ? {4{~ram_data_ok}} : 4'b0;
	// ����Ƕ�kseg1�����ݣ���ַ0xA000_0000~0xBFFF_FFF��
	// ����kseg1ΪUncached���ԣ��ʲ��ܴ�Cache�ж�������ֱ�ӷ���ram
	assign uncached = /*  */(cache_rst == `RST_ENABLE) ? `FALSE_V :
                (cpu_addr[31:29] == 3'b101) ? `TRUE_V : `FALSE_V;
				// (req && cpu_addr[31:29] == 3'b101) ? `TRUE_V : `FALSE_V;
	// ��Ҫ��CPU���������ַת��Ϊʵ��ַ��������ram
	assign ram_addr = (cache_rst == `RST_ENABLE) ? `ZERO_WORD : 
				(req & ~hit & ~uncached) ? 
				{cpu_addr[31:OFFSET_WIDTH],{OFFSET_WIDTH{1'b0}}} :
				(uncached) ? cpu_addr[31:0] :
				`ZERO_WORD;
	assign ram_wr = `MEM_READ;
    // assign ram_size = 2'b10;
	assign ram_wdata = `ZERO_WORD;
	
	// �͸�CPU�Ķ���������ź�
	assign operation_ok =  (cache_rst == `RST_ENABLE) ? `FALSE_V : 
                (hit) ? `TRUE_V : // ��ֱ��hit���߶�miss���¸���һ��֮��hit���������
				(uncached  & ram_data_ok) ? `TRUE_V : // ��uncached����ʱ��ram����ok���������
				`FALSE_V;
	
	//ѭ���м���
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
		// ��λʱ��cache��tag��valid��lruλ���㣬cnt����
		if(cache_rst == `RST_ENABLE) begin
			for(i = 0;i <= `NUM_ICACHE_LINES-1;i=i+1) begin
				valid_bits[i]	<= `FALSE_V;
				lru_bits[i] 	<= 2'd0;
				tags[i] 		<= {TAG_WIDTH{1'b0}};
			end
			cnt <= {(OFFSET_WIDTH-2){1'b0}};
		end
		// ��hitʱ����������������е�lruλ
		else if(req & ~uncached & hit) begin
			for (i = 0; i < NUM_ASSOC;i = i + 1) begin
				if (/* valid_bits[addr_index * NUM_ASSOC + i] && */ lru_bits[addr_index * NUM_ASSOC + i] < lru_temp)
					lru_bits[addr_index * NUM_ASSOC + i] <= lru_bits[addr_index * NUM_ASSOC + i] + 1;
			end
			lru_bits[addr_index * NUM_ASSOC + lucky] <= 2'd0;				
		end		
		// ��missʱ����LRU�����滻cacheһ��
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
		// ��ȫif-else�����Ĳ���
		else
			valid_bits[0] <= valid_bits[0];
	end
endmodule