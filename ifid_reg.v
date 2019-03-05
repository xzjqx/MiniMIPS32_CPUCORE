`include "defines.v"

module ifid_reg (
	input  wire 					   cpu_clk_50M,
	input  wire 					   cpu_rst_n,

	// 来自取指阶段的信息  
	input  wire [`INST_ADDR_BUS]       if_pc,
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
    input  wire [`WORD_BUS     ]       if_inst,
    input  wire                        if_delay,
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
	
	// 送至译码阶段的信息  
	output reg  [`INST_ADDR_BUS]       id_pc,
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
    output reg  [`WORD_BUS     ]       id_inst,
    output reg                         id_delay,
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
/************************转移指令添加 begin*******************************/
	input  wire [`INST_ADDR_BUS]       if_pc_plus_4,
    output reg  [`INST_ADDR_BUS] 	   id_pc_plus_4,
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
    input  wire [`STALL_BUS    ]       stall,
/************************流水线暂停 end***********************************/
/************************异常处理 begin*******************************/
	input  wire [`EXC_CODE_BUS ]       if_exccode,
    output reg  [`EXC_CODE_BUS ]       id_exccode,
    input  wire [`WORD_BUS     ]       if_badvaddr,
    output reg  [`WORD_BUS     ]       id_badvaddr,
	input  wire						   flush,			// 清空流水线信号
/************************UPDATE--延长异常发生时的清空流水线信号*******************************/
	input  wire                        flush_t
/************************UPDATE--延长异常发生时的清空流水线信号*******************************/
/************************异常处理 end*********************************/
	);

	always @(posedge cpu_clk_50M) begin
	    // 复位或清空流水线时，将送至译码阶段的信息清0
/************************异常处理 begin*******************************/
/************************UPDATE--添加对延时异常信号的判断*******************************/
		if (cpu_rst_n == `RST_ENABLE || flush || flush_t) begin
/************************UPDATE--添加对延时异常信号的判断*******************************/
			id_exccode   <= `EXC_NONE;
			id_badvaddr  <= `ZERO_WORD;
/************************异常处理 end*********************************/
			id_pc 	     <= `PC_INIT;
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
            id_inst      <= `ZERO_WORD;
			id_pc_plus_4 <= `PC_INIT;
            id_delay     <= 1'b0;
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
/************************流水线暂停 begin*********************************/
		end 
		else if(stall[1] == `STOP && stall[2] == `NOSTOP) begin
		// 取指阶段暂停时pc为0
			id_exccode  <= `EXC_NONE;
			id_badvaddr  <= `ZERO_WORD;
			id_pc   	 <= `PC_INIT; 	
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
            id_inst      <= `ZERO_WORD;
			id_pc_plus_4 <= `PC_INIT;
            id_delay     <= 1'b0;
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
		end
		else if(stall[1] == `NOSTOP) begin
/************************流水线暂停 end***********************************/
		// 将来自取指阶段的信息寄存并送至译码阶段
			id_exccode   <= if_exccode;
			id_badvaddr  <= if_badvaddr;
			id_pc	     <= if_pc;		
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
            id_inst      <= if_inst;
			id_pc_plus_4 <= if_pc_plus_4;
            id_delay     <= if_delay;
/************************UPDATE--将读出的指令传入IF/ID寄存器*******************************/
		end
	end

endmodule
