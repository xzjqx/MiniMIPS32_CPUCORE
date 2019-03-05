`include "defines.v"

module memwb_reg (
    input  wire                     cpu_clk_50M,
	input  wire                     cpu_rst_n,

	// ���Էô�׶ε���Ϣ
	input  wire [`REG_ADDR_BUS  ]   mem_wa,
	input  wire                     mem_wreg,
	input  wire [`REG_BUS       ] 	mem_dreg,

	input  wire                     mem_mreg,
	input  wire [`BSEL_BUS      ]   mem_dre,
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
    input  wire [`INST_ADDR_BUS ]   mem_daddr,
    input  wire [`REG_BUS       ]   mem_dm,
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
	
	input  wire                     mem_whilo,
	input  wire [`DOUBLE_REG_BUS]   mem_hilo,

	// ����д�ؽ׶ε���Ϣ 
	output reg  [`REG_ADDR_BUS  ]   wb_wa,
	output reg                      wb_wreg,
	output reg  [`REG_BUS       ]   wb_dreg,

	output reg                      wb_mreg,
	output reg  [`BSEL_BUS      ]   wb_dre,
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
    output reg  [`INST_ADDR_BUS ]   wb_daddr,
    output reg  [`REG_BUS       ]   wb_dm,
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
	
	output reg                      wb_whilo,
	output reg  [`DOUBLE_REG_BUS] 	wb_hilo,
/************************UPDATE--���MEM/WB��ͣ�ж�*******************************/
/************************��ˮ����ͣ begin*********************************/
    input wire [`STALL_BUS     ]  stall,
/************************��ˮ����ͣ end***********************************/
/************************UPDATE--���MEM/WB��ͣ�ж�*******************************/
/************************MFC0,MTC0 begin*******************************/
    input  wire                   mem_cp0_we,
    input  wire [`REG_ADDR_BUS  ] mem_cp0_waddr,
    input  wire [`REG_BUS       ] mem_cp0_wdata,

	output reg                    wb_cp0_we,
	output reg  [`REG_ADDR_BUS  ] wb_cp0_waddr,
	output reg  [`REG_BUS       ] wb_cp0_wdata,
/************************MFC0,MTC0 end*********************************/
/************************�쳣���� begin*******************************/
	input  wire					  flush,
/************************�쳣���� end*********************************/
/************************���޷��ż��ش洢�� begin*******************************/
    input  wire                     mem_sign,
	output reg                      wb_sign
/************************���޷��ż��ش洢�� end*********************************/
    );

    always @(posedge cpu_clk_50M) begin
		// ��λ�������ˮ��ʱ������������׶ε���Ϣ��0
/************************�쳣���� begin*******************************/
		if (cpu_rst_n == `RST_ENABLE || flush) begin
/************************�쳣���� end*********************************/
			wb_wa         <= `REG_NOP;
			wb_wreg       <= `WRITE_DISABLE;
			wb_dreg       <= `ZERO_WORD;
			wb_dre        <= 4'b0;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
            wb_daddr      <= `ZERO_WORD;
            wb_dm         <= `ZERO_WORD;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
			wb_mreg       <= `WRITE_DISABLE;
			wb_whilo      <= `WRITE_DISABLE;
			wb_hilo       <= `ZERO_DWORD;
/************************MFC0,MTC0 begin*******************************/
	    	wb_cp0_we     <= `FALSE_V;
	    	wb_cp0_waddr  <= `ZERO_WORD;
	    	wb_cp0_wdata  <= `ZERO_WORD;
/************************MFC0,MTC0 end*********************************/
            wb_sign     <= `FALSE_V;
		end
/************************UPDATE--��ӷô���ͣ�ж�*******************************/
        else if(stall[4] == `STOP && stall[5] == `NOSTOP) begin
			wb_wa         <= `REG_NOP;
			wb_wreg       <= `WRITE_DISABLE;
			wb_dreg       <= `ZERO_WORD;
			wb_dre        <= 4'b0;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
            wb_daddr      <= `ZERO_WORD;
            wb_dm         <= `ZERO_WORD;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
			wb_mreg       <= `WRITE_DISABLE;
			wb_whilo      <= `WRITE_DISABLE;
			wb_hilo       <= `ZERO_DWORD;
/************************MFC0,MTC0 begin*******************************/
	    	wb_cp0_we     <= `FALSE_V;
	    	wb_cp0_waddr  <= `ZERO_WORD;
	    	wb_cp0_wdata  <= `ZERO_WORD;
/************************MFC0,MTC0 end*********************************/
            wb_sign     <= `FALSE_V;
		end
		// �����Էô�׶ε���Ϣ�Ĵ沢����д�ؽ׶�
		else if(stall[4] == `NOSTOP)begin
/************************UPDATE--��ӷô���ͣ�ж�*******************************/
			wb_wa 	      <= mem_wa;
			wb_wreg       <= mem_wreg;
			wb_dreg       <= mem_dreg;
			wb_dre        <= mem_dre;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
            wb_daddr      <= mem_daddr;
            wb_dm         <= mem_dm;
/************************UPDATE--�����������ݴ���MEM/WB�Ĵ���*******************************/
			wb_mreg       <= mem_mreg;
			wb_whilo      <= mem_whilo;
			wb_hilo       <= mem_hilo;
/************************MFC0,MTC0 begin*******************************/
	    	wb_cp0_we     <= mem_cp0_we;
	    	wb_cp0_waddr  <= mem_cp0_waddr;
	    	wb_cp0_wdata  <= mem_cp0_wdata;
/************************MFC0,MTC0 end*********************************/
			wb_sign     <= mem_sign;
		end
	end

endmodule
