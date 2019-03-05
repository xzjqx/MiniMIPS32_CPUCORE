`include "defines.v"

module cp0_reg(
    input  wire 				 cpu_clk_50M,
	input  wire 				 cpu_rst_n,
	input  wire 				 we,
	input  wire 				 re,
	input  wire [`REG_ADDR_BUS ] raddr,
	input  wire [`REG_ADDR_BUS ] waddr,
	input  wire [`REG_BUS      ] wdata,
	input  wire [`CP0_INT_BUS  ] int_i,
	
	input  wire [`EXC_CODE_BUS ] exccode_i,
	input  wire [`REG_BUS      ] exc_badvaddr_i,
	 
	output wire 				 flush,
	output wire [`INST_ADDR_BUS] cp0_excaddr,

	output wire	[`REG_BUS      ] data_o,
	
	output wire [`REG_BUS 	   ] status_o,
	output wire [`REG_BUS 	   ] cause_o,
	
	input  wire [`INST_ADDR_BUS] pc_i,
	input  wire 				 in_delay_i,
/************************UPDATE--添加时钟中断信号*******************************/
    output reg                   timer_int
/************************UPDATE--添加时钟中断信号*******************************/
    );

	reg [`REG_BUS] badvaddr;	// CP0的badvaddr寄存器
/************************UPDATE--添加两个CP0寄存器*******************************/
	reg [`REG_BUS] count;	    // CP0的count寄存器
    reg [`REG_BUS] compare;  	// CP0的compare寄存器
/************************UPDATE--添加两个CP0寄存器*******************************/
	reg [`REG_BUS] status;		// CP0的status寄存器
	reg [`REG_BUS] cause;		// CP0的cause寄存器
	reg [`REG_BUS] epc;			// CP0的epc寄存器

	assign status_o = status;
	assign cause_o = cause;

    // 根据异常信息生成清空流水线信号flush
    assign flush = (cpu_rst_n == `RST_ENABLE) ? `NOFLUSH : 
                   (exccode_i != `EXC_NONE ) ? `FLUSH : `NOFLUSH;

    // 处理异常
    task do_exc; begin
		if (status[1] == 0) begin
			if(in_delay_i) begin        // 判断异常发生指令是否为延迟槽指令
				cause[31] <= 1;   		// 若为延迟槽指令，cause[31]置为1
				epc       <= pc_i - 4;
			end else begin	
				cause[31] <= 0;
				epc       <= pc_i;
			end
		end
		status[1]  <= 1'b1;
		cause[6:2] <= exccode_i;
		badvaddr <= exc_badvaddr_i;
	end
	endtask

    // 处理ERET指令
	task do_eret; begin
		status[1]   <= 0;
	end
	endtask

	// 产生异常处理程序入口地址
/************************UPDATE--修改复位时，excaddr应该为`PC_INIT*******************************/
	assign cp0_excaddr = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT :
/************************UPDATE--修改复位时，excaddr应该为`PC_INIT*******************************/
						 (exccode_i == `EXC_INT   ) ? `EXC_INT_ADDR :
						 (exccode_i == `EXC_ERET && waddr == `CP0_EPC && we == `WRITE_ENABLE) ? wdata :
						 (exccode_i == `EXC_ERET  ) ? epc :
						 (exccode_i != `EXC_NONE  ) ? `EXC_ADDR : `ZERO_WORD;

    // 更新CP0寄存器数据
    always @ (posedge cpu_clk_50M) begin
		if(cpu_rst_n == `RST_ENABLE) begin
            badvaddr 	  <= `ZERO_WORD;
/************************UPDATE--添加两个CP0寄存器*******************************/
            compare       <= `ZERO_WORD;
            count         <= `ZERO_WORD;
/************************UPDATE--添加两个CP0寄存器*******************************/
            status 	      <= 32'h10000000;              // status[28]为1，表示使能CP0协处理器
/************************UPDATE--修改复位时，cause中exccode段因为`EXC_NONE的bug*******************************/
            cause 	      <= {25'b0, `EXC_NONE, 2'b0};
/************************UPDATE--修改复位时，cause中exccode段因为`EXC_NONE的bug*******************************/
            epc 		  <= `ZERO_WORD;
/************************UPDATE--添加时钟中断信号*******************************/
            timer_int     <= 0;
/************************UPDATE--添加时钟中断信号*******************************/
		end 
        else begin
/************************UPDATE--count寄存器每周期加一*******************************/
            count <= count + 1;
/************************UPDATE--count寄存器每周期加一*******************************/
			cause[15:10] <= int_i;

/************************UPDATE--compare与count相等时产生时钟中断*******************************/
            if(compare != `ZERO_WORD && count == compare) begin
				timer_int <= `TRUE_V;
			end
/************************UPDATE--compare与count相等时产生时钟中断*******************************/
			if (we == `WRITE_ENABLE) begin
				case(waddr)
				 	`CP0_BADVADDR: badvaddr     <= wdata;
/************************UPDATE--添加两个CP0寄存器*******************************/
                    `CP0_COUNT:    count        <= wdata;
                    `CP0_COMPARE:  begin
                                   compare      <= wdata;
                                   timer_int    <= `FALSE_V; end
/************************UPDATE--添加两个CP0寄存器*******************************/
/************************UPDATE--修改以符合CP0寄存器部分位只读的情况*******************************/
					`CP0_STATUS:   begin // status 寄存器只有15..8和1..0可读可写，其他位只读
								   status[15:8] <= wdata[15:8]; 
							       status[ 1:0] <= wdata[ 1:0]; end
					`CP0_CAUSE:    cause[9:8]   <= wdata[9:8];// cause 寄存器只有9..8（软中断标识位）可读可写，exccode位在处理异常时修改，其他位只读
/************************UPDATE--修改以符合CP0寄存器部分位只读的情况*******************************/
                    `CP0_EPC:      epc      <= wdata;
				 	default : compare	<= compare; // do nothing
				endcase
			end
			case (exccode_i)
				`EXC_NONE:       // 无异常发生时，判断是否为写寄存器指令，写入数据
					if (we == `WRITE_ENABLE) begin
						case(waddr)
						 	`CP0_BADVADDR: badvaddr     <= wdata;
/************************UPDATE--添加两个CP0寄存器*******************************/
                            `CP0_COUNT:    count        <= wdata;
                            `CP0_COMPARE:  begin
                                           compare      <= wdata;
                                           timer_int    <= `FALSE_V; end
/************************UPDATE--添加两个CP0寄存器*******************************/
/************************UPDATE--修改以符合CP0寄存器部分位只读的情况*******************************/
						 	`CP0_STATUS:   begin // status 寄存器只有15..8和1..0可读可写，其他位只读
								           status[15:8] <= wdata[15:8]; 
								           status[ 1:0] <= wdata[ 1:0]; end
						 	`CP0_CAUSE:    cause[9:8]   <= wdata[9:8];// cause 寄存器只有9..8（软中断标识位）可读可写，exccode位在处理异常时修改，其他位只读
/************************UPDATE--修改以符合CP0寄存器部分位只读的情况*******************************/
                            `CP0_EPC:      epc      <= wdata;
						 	default : compare	<= compare; // do nothing
						endcase
					end
				`EXC_ERET:       // ERET指令
					do_eret();
				default:        // 异常发生时，处理对应异常
					do_exc();
			endcase
		end
	end

	// 读CP0中的寄存器
    assign data_o = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                    (re != `READ_ENABLE      ) ? `ZERO_WORD :
                    (raddr == `CP0_BADVADDR  ) ? badvaddr :
				    (raddr == `CP0_STATUS    ) ? status :
				    (raddr == `CP0_CAUSE     ) ? cause :
				    (raddr == `CP0_EPC       ) ? epc : 
/************************UPDATE--添加两个CP0寄存器*******************************/
                    (raddr == `CP0_COUNT     ) ? count :
					(raddr == `CP0_COMPARE   ) ? compare :`ZERO_WORD;
/************************UPDATE--添加两个CP0寄存器*******************************/

endmodule
