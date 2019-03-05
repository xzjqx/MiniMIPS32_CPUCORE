`include "defines.v"

module ifid_reg (
	input  wire 					   cpu_clk_50M,
	input  wire 					   cpu_rst_n,

	// ����ȡָ�׶ε���Ϣ  
	input  wire [`INST_ADDR_BUS]       if_pc,
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
    input  wire [`WORD_BUS     ]       if_inst,
    input  wire                        if_delay,
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
	
	// ��������׶ε���Ϣ  
	output reg  [`INST_ADDR_BUS]       id_pc,
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
    output reg  [`WORD_BUS     ]       id_inst,
    output reg                         id_delay,
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
/************************ת��ָ����� begin*******************************/
	input  wire [`INST_ADDR_BUS]       if_pc_plus_4,
    output reg  [`INST_ADDR_BUS] 	   id_pc_plus_4,
/*********************** ת��ָ����� end*********************************/
/************************��ˮ����ͣ begin*********************************/
    input  wire [`STALL_BUS    ]       stall,
/************************��ˮ����ͣ end***********************************/
/************************�쳣���� begin*******************************/
	input  wire [`EXC_CODE_BUS ]       if_exccode,
    output reg  [`EXC_CODE_BUS ]       id_exccode,
    input  wire [`WORD_BUS     ]       if_badvaddr,
    output reg  [`WORD_BUS     ]       id_badvaddr,
	input  wire						   flush,			// �����ˮ���ź�
/************************UPDATE--�ӳ��쳣����ʱ�������ˮ���ź�*******************************/
	input  wire                        flush_t
/************************UPDATE--�ӳ��쳣����ʱ�������ˮ���ź�*******************************/
/************************�쳣���� end*********************************/
	);

	always @(posedge cpu_clk_50M) begin
	    // ��λ�������ˮ��ʱ������������׶ε���Ϣ��0
/************************�쳣���� begin*******************************/
/************************UPDATE--��Ӷ���ʱ�쳣�źŵ��ж�*******************************/
		if (cpu_rst_n == `RST_ENABLE || flush || flush_t) begin
/************************UPDATE--��Ӷ���ʱ�쳣�źŵ��ж�*******************************/
			id_exccode   <= `EXC_NONE;
			id_badvaddr  <= `ZERO_WORD;
/************************�쳣���� end*********************************/
			id_pc 	     <= `PC_INIT;
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
            id_inst      <= `ZERO_WORD;
			id_pc_plus_4 <= `PC_INIT;
            id_delay     <= 1'b0;
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
/************************��ˮ����ͣ begin*********************************/
		end 
		else if(stall[1] == `STOP && stall[2] == `NOSTOP) begin
		// ȡָ�׶���ͣʱpcΪ0
			id_exccode  <= `EXC_NONE;
			id_badvaddr  <= `ZERO_WORD;
			id_pc   	 <= `PC_INIT; 	
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
            id_inst      <= `ZERO_WORD;
			id_pc_plus_4 <= `PC_INIT;
            id_delay     <= 1'b0;
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
		end
		else if(stall[1] == `NOSTOP) begin
/************************��ˮ����ͣ end***********************************/
		// ������ȡָ�׶ε���Ϣ�Ĵ沢��������׶�
			id_exccode   <= if_exccode;
			id_badvaddr  <= if_badvaddr;
			id_pc	     <= if_pc;		
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
            id_inst      <= if_inst;
			id_pc_plus_4 <= if_pc_plus_4;
            id_delay     <= if_delay;
/************************UPDATE--��������ָ���IF/ID�Ĵ���*******************************/
		end
	end

endmodule
