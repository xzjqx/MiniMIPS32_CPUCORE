`include "defines.v"

module if_stage (
    input 	wire 					cpu_clk_50M,
    input 	wire 					cpu_rst_n,
    
    output  wire                    ice,
    output 	reg  [`INST_ADDR_BUS] 	pc,
    output 	wire [`INST_ADDR_BUS]	iaddr,
    
/************************转移指令添加 begin*******************************/
    output  wire [`INST_ADDR_BUS] 	pc_plus_4,
    // 从译码阶段获得的跳转地址
    input   wire [`INST_ADDR_BUS]   jump_addr_1,
    input   wire [`INST_ADDR_BUS]   jump_addr_2,
    input   wire [`INST_ADDR_BUS]   jump_addr_3,
    input   wire [`JTSEL_BUS    ]   jtsel,
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
    input   wire [`STALL_BUS    ]   stall,
/************************UPDATE--添加取值阶段暂停*******************************/
    // 取指阶段暂停信号
    output wire                     stallreq_if,
    input  wire                     if_data_ok,
/************************UPDATE--添加取值阶段暂停*******************************/
/************************流水线暂停 end***********************************/
/************************异常处理 begin*******************************/
    output  wire [`EXC_CODE_BUS ] 	if_exccode_o,
	output  wire [`INST_ADDR_BUS] 	if_badvaddr_o,
    input   wire                    flush,          // 清空流水线信号
/************************UPDATE--延长异常发生时的清空流水线信号*******************************/
    output  reg                     flush_t,
/************************UPDATE--延长异常发生时的清空流水线信号*******************************/
    input   wire [`INST_ADDR_BUS]   cp0_excaddr     // 异常处理程序入口地址
/************************异常处理 end*********************************/
    );
                  
    assign pc_plus_4 = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT : pc + 4;
/************************转移指令添加 begin*******************************/
    wire [`INST_ADDR_BUS] pc_next;
    assign pc_next = (jtsel == 2'b00) ? pc_plus_4 :              // 计算下一条指令的地址
                     (jtsel == 2'b01) ? jump_addr_1 :            // j, jal指令转移地址
                     (jtsel == 2'b10) ? jump_addr_3 :            // jr指令转移地址
                     (jtsel == 2'b11) ? jump_addr_2 : `PC_INIT;  // beq, bne指令转移地址
/*********************** 转移指令添加 end*********************************/

/************************流水线暂停 begin*********************************/
    reg ce;
    always @(posedge cpu_clk_50M) begin
		if (cpu_rst_n == `RST_ENABLE)
			ce <= `CHIP_DISABLE;		      // 复位的时候指令存储器禁用  
		else begin
			ce <= `CHIP_ENABLE; 		      // 复位结束后，指令存储器使能
		end
	end

/************************UPDATE--修改以处理取指暂停时发生异常的问题*******************************/
    reg [`INST_ADDR_BUS] excaddr_t;
    assign iaddr = (flush  ) ? cp0_excaddr :
                   (flush_t) ? excaddr_t : pc;    // 获得访问指令存储器的地址
    wire word_aligned = iaddr[1:0] == 2'b00;

    assign ice = (if_data_ok == 1'b1 || !word_aligned) ? 0 : ce; // 当stall[1]和flush都不为1且未发生错地址异常时，才能访问指令存储器
    // 获得取指阶段暂停信号
    assign stallreq_if = ice;

    always @(posedge cpu_clk_50M) begin
        if(cpu_rst_n == `RST_ENABLE) begin
            flush_t <= `FALSE_V;
            excaddr_t <= `ZERO_WORD;
        end
        else if(flush == `TRUE_V) begin
            flush_t <= `TRUE_V;
            excaddr_t <= cp0_excaddr;
        end
        else if(stall[0] == `NOSTOP) begin
            flush_t <= `FALSE_V;
            excaddr_t <= `ZERO_WORD;
        end
    end
/************************UPDATE--修改以处理取指暂停时发生异常的问题*******************************/

    always @(posedge cpu_clk_50M) begin
        if (ce == `CHIP_DISABLE)
            pc <= `PC_INIT;                   // 指令存储器禁用的时候，PC保持初始值（MiniMIPS32中设置为0x00000000）
        else begin
/************************异常处理 begin*******************************/
            if(flush == `TRUE_V)    
                pc <= cp0_excaddr;            // 当发生异常时，PC等于异常处理程序入口地址
/************************UPDATE--修改以处理取指暂停时发生异常的问题*******************************/
            else if(flush_t == `TRUE_V)
                pc <= excaddr_t;              // 取指暂停时发生异常，暂存异常入口地址为excaddr_t，并将其传给PC
/************************UPDATE--修改以处理取指暂停时发生异常的问题*******************************/
/************************异常处理 end*********************************/
            else if (stall[0] == `NOSTOP) begin
                pc <= pc_next;                // 当stall[0]为NOSTOP时，pc等于pc_next，否则，保持pc不变	
            end
        end
    end
/************************流水线暂停 end***********************************/
    
    assign if_badvaddr_o 	= (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                              (!word_aligned) 	 ? iaddr	:
                              (ice == `CHIP_DISABLE) ? `ZERO_WORD :  `ZERO_WORD;
	assign if_exccode_o 	= (cpu_rst_n == `RST_ENABLE) ? `EXC_NONE  : 
                              (!word_aligned) 	 ? `EXC_ADEL  : 
                              (ice == `CHIP_DISABLE) ? `EXC_NONE  : `EXC_NONE;

endmodule
