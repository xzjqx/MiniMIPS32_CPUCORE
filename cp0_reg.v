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
/************************UPDATE--���ʱ���ж��ź�*******************************/
    output reg                   timer_int
/************************UPDATE--���ʱ���ж��ź�*******************************/
    );

	reg [`REG_BUS] badvaddr;	// CP0��badvaddr�Ĵ���
/************************UPDATE--�������CP0�Ĵ���*******************************/
	reg [`REG_BUS] count;	    // CP0��count�Ĵ���
    reg [`REG_BUS] compare;  	// CP0��compare�Ĵ���
/************************UPDATE--�������CP0�Ĵ���*******************************/
	reg [`REG_BUS] status;		// CP0��status�Ĵ���
	reg [`REG_BUS] cause;		// CP0��cause�Ĵ���
	reg [`REG_BUS] epc;			// CP0��epc�Ĵ���

	assign status_o = status;
	assign cause_o = cause;

    // �����쳣��Ϣ���������ˮ���ź�flush
    assign flush = (cpu_rst_n == `RST_ENABLE) ? `NOFLUSH : 
                   (exccode_i != `EXC_NONE ) ? `FLUSH : `NOFLUSH;

    // �����쳣
    task do_exc; begin
		if (status[1] == 0) begin
			if(in_delay_i) begin        // �ж��쳣����ָ���Ƿ�Ϊ�ӳٲ�ָ��
				cause[31] <= 1;   		// ��Ϊ�ӳٲ�ָ�cause[31]��Ϊ1
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

    // ����ERETָ��
	task do_eret; begin
		status[1]   <= 0;
	end
	endtask

	// �����쳣���������ڵ�ַ
/************************UPDATE--�޸ĸ�λʱ��excaddrӦ��Ϊ`PC_INIT*******************************/
	assign cp0_excaddr = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT :
/************************UPDATE--�޸ĸ�λʱ��excaddrӦ��Ϊ`PC_INIT*******************************/
						 (exccode_i == `EXC_INT   ) ? `EXC_INT_ADDR :
						 (exccode_i == `EXC_ERET && waddr == `CP0_EPC && we == `WRITE_ENABLE) ? wdata :
						 (exccode_i == `EXC_ERET  ) ? epc :
						 (exccode_i != `EXC_NONE  ) ? `EXC_ADDR : `ZERO_WORD;

    // ����CP0�Ĵ�������
    always @ (posedge cpu_clk_50M) begin
		if(cpu_rst_n == `RST_ENABLE) begin
            badvaddr 	  <= `ZERO_WORD;
/************************UPDATE--�������CP0�Ĵ���*******************************/
            compare       <= `ZERO_WORD;
            count         <= `ZERO_WORD;
/************************UPDATE--�������CP0�Ĵ���*******************************/
            status 	      <= 32'h10000000;              // status[28]Ϊ1����ʾʹ��CP0Э������
/************************UPDATE--�޸ĸ�λʱ��cause��exccode����Ϊ`EXC_NONE��bug*******************************/
            cause 	      <= {25'b0, `EXC_NONE, 2'b0};
/************************UPDATE--�޸ĸ�λʱ��cause��exccode����Ϊ`EXC_NONE��bug*******************************/
            epc 		  <= `ZERO_WORD;
/************************UPDATE--���ʱ���ж��ź�*******************************/
            timer_int     <= 0;
/************************UPDATE--���ʱ���ж��ź�*******************************/
		end 
        else begin
/************************UPDATE--count�Ĵ���ÿ���ڼ�һ*******************************/
            count <= count + 1;
/************************UPDATE--count�Ĵ���ÿ���ڼ�һ*******************************/
			cause[15:10] <= int_i;

/************************UPDATE--compare��count���ʱ����ʱ���ж�*******************************/
            if(compare != `ZERO_WORD && count == compare) begin
				timer_int <= `TRUE_V;
			end
/************************UPDATE--compare��count���ʱ����ʱ���ж�*******************************/
			if (we == `WRITE_ENABLE) begin
				case(waddr)
				 	`CP0_BADVADDR: badvaddr     <= wdata;
/************************UPDATE--�������CP0�Ĵ���*******************************/
                    `CP0_COUNT:    count        <= wdata;
                    `CP0_COMPARE:  begin
                                   compare      <= wdata;
                                   timer_int    <= `FALSE_V; end
/************************UPDATE--�������CP0�Ĵ���*******************************/
/************************UPDATE--�޸��Է���CP0�Ĵ�������λֻ�������*******************************/
					`CP0_STATUS:   begin // status �Ĵ���ֻ��15..8��1..0�ɶ���д������λֻ��
								   status[15:8] <= wdata[15:8]; 
							       status[ 1:0] <= wdata[ 1:0]; end
					`CP0_CAUSE:    cause[9:8]   <= wdata[9:8];// cause �Ĵ���ֻ��9..8�����жϱ�ʶλ���ɶ���д��exccodeλ�ڴ����쳣ʱ�޸ģ�����λֻ��
/************************UPDATE--�޸��Է���CP0�Ĵ�������λֻ�������*******************************/
                    `CP0_EPC:      epc      <= wdata;
				 	default : compare	<= compare; // do nothing
				endcase
			end
			case (exccode_i)
				`EXC_NONE:       // ���쳣����ʱ���ж��Ƿ�Ϊд�Ĵ���ָ�д������
					if (we == `WRITE_ENABLE) begin
						case(waddr)
						 	`CP0_BADVADDR: badvaddr     <= wdata;
/************************UPDATE--�������CP0�Ĵ���*******************************/
                            `CP0_COUNT:    count        <= wdata;
                            `CP0_COMPARE:  begin
                                           compare      <= wdata;
                                           timer_int    <= `FALSE_V; end
/************************UPDATE--�������CP0�Ĵ���*******************************/
/************************UPDATE--�޸��Է���CP0�Ĵ�������λֻ�������*******************************/
						 	`CP0_STATUS:   begin // status �Ĵ���ֻ��15..8��1..0�ɶ���д������λֻ��
								           status[15:8] <= wdata[15:8]; 
								           status[ 1:0] <= wdata[ 1:0]; end
						 	`CP0_CAUSE:    cause[9:8]   <= wdata[9:8];// cause �Ĵ���ֻ��9..8�����жϱ�ʶλ���ɶ���д��exccodeλ�ڴ����쳣ʱ�޸ģ�����λֻ��
/************************UPDATE--�޸��Է���CP0�Ĵ�������λֻ�������*******************************/
                            `CP0_EPC:      epc      <= wdata;
						 	default : compare	<= compare; // do nothing
						endcase
					end
				`EXC_ERET:       // ERETָ��
					do_eret();
				default:        // �쳣����ʱ�������Ӧ�쳣
					do_exc();
			endcase
		end
	end

	// ��CP0�еļĴ���
    assign data_o = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                    (re != `READ_ENABLE      ) ? `ZERO_WORD :
                    (raddr == `CP0_BADVADDR  ) ? badvaddr :
				    (raddr == `CP0_STATUS    ) ? status :
				    (raddr == `CP0_CAUSE     ) ? cause :
				    (raddr == `CP0_EPC       ) ? epc : 
/************************UPDATE--�������CP0�Ĵ���*******************************/
                    (raddr == `CP0_COUNT     ) ? count :
					(raddr == `CP0_COMPARE   ) ? compare :`ZERO_WORD;
/************************UPDATE--�������CP0�Ĵ���*******************************/

endmodule
