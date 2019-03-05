`include "defines.v"

module wb_stage(
    input  wire                   cpu_rst_n,
    // �ӷô�׶λ�õ���Ϣ
    input  wire                   wb_mreg_i,
    input  wire [`BSEL_BUS      ] wb_dre_i,
	input  wire [`REG_ADDR_BUS  ] wb_wa_i,
	input  wire                   wb_wreg_i,
	input  wire [`REG_BUS       ] wb_dreg_i,
    input  wire                   wb_whilo_i,
	input  wire [`DOUBLE_REG_BUS] wb_hilo_i,

/************************UPDATE--��ַ�����ж��Ƿ�Ϊ�ⲿ�豸*******************************/
    input  wire [`INST_ADDR_BUS ] daddr,
    // ��MEM/WB�Ĵ��������ĵ�����
    input  wire [`WORD_BUS      ] dm,
/************************UPDATE--��ַ�����ж��Ƿ�Ϊ�ⲿ�豸*******************************/
    // д��Ŀ�ļĴ���������
    output wire [`REG_ADDR_BUS  ] wb_wa_o,
	output wire                   wb_wreg_o,
    output wire [`WORD_BUS      ] wb_wd_o,
    output wire                   wb_whilo_o,
	output wire [`DOUBLE_REG_BUS] wb_hilo_o,
/************************MFC0,MTC0 begin*******************************/
    input  wire                     cp0_we_i,
    input  wire [`REG_ADDR_BUS  ]   cp0_waddr_i,
    input  wire [`REG_BUS       ]   cp0_wdata_i,

	output wire                     cp0_we_o,
	output wire [`REG_ADDR_BUS  ]   cp0_waddr_o,
	output wire [`REG_BUS       ] 	cp0_wdata_o,
/************************MFC0,MTC0 end*********************************/
/************************���޷��ż��ش洢�� begin*******************************/
    input  wire                     sign,
/************************���޷��ż��ش洢�� end*********************************/
    input  wire                     stallreq_mem,
    input  wire 				    flush
    );

    assign wb_wa_o      = (cpu_rst_n == `RST_ENABLE) ? 5'b0 : wb_wa_i;
    assign wb_wreg_o    = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : wb_wreg_i;
    assign wb_whilo_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : wb_whilo_i;
    assign wb_hilo_o    = (cpu_rst_n == `RST_ENABLE) ? 64'b0 : wb_hilo_i;
/************************MFC0,MTC0 begin*******************************/
    // ֱ������CP0Э���������ź�
	assign cp0_we_o     = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : cp0_we_i;
	assign cp0_waddr_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_waddr_i;
	assign cp0_wdata_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_wdata_i;
/************************MFC0,MTC0 end*********************************/

    wire [`WORD_BUS] data  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                             (|wb_dre_i == 1'b0       ) ? `ZERO_WORD :
/************************UPDATE--�������ⲿ�豸������Ҫ����dm*******************************/
                             (daddr[31:28] != 4'h8 && daddr[31:28] != 4'h0 && daddr[31:20] != 12'hbfc) ? dm :
/************************UPDATE--�������ⲿ�豸������Ҫ����dm*******************************/
                             (wb_dre_i == 4'b1111     ) ? {dm[7:0], dm[15:8], dm[23:16], dm[31:24]} :
                             (wb_dre_i == 4'b1000 && sign) ? {{24{dm[31]}}, dm[31:24]} :
                             (wb_dre_i == 4'b0100 && sign) ? {{24{dm[23]}}, dm[23:16]} :
                             (wb_dre_i == 4'b0010 && sign) ? {{24{dm[15]}}, dm[15:8 ]} :
                             (wb_dre_i == 4'b0001 && sign) ? {{24{dm[7 ]}}, dm[7 :0 ]} : 
                             (wb_dre_i == 4'b1100 && sign) ? {{16{dm[23]}}, dm[23:16], dm[31:24]} :
                             (wb_dre_i == 4'b0011 && sign) ? {{16{dm[7 ]}}, dm[7 :0 ], dm[15:8 ]} : 
                             (wb_dre_i == 4'b1000 &&~sign) ? {{24{1'b0}}, dm[31:24]} :
                             (wb_dre_i == 4'b0100 &&~sign) ? {{24{1'b0}}, dm[23:16]} :
                             (wb_dre_i == 4'b0010 &&~sign) ? {{24{1'b0}}, dm[15:8 ]} :
                             (wb_dre_i == 4'b0001 &&~sign) ? {{24{1'b0}}, dm[7 :0 ]} : 
                             (wb_dre_i == 4'b1100 &&~sign) ? {{16{1'b0}}, dm[23:16], dm[31:24]} :
                             (wb_dre_i == 4'b0011 &&~sign) ? {{16{1'b0}}, dm[7 :0 ], dm[15:8 ]} : `ZERO_WORD;

    assign wb_wd_o = (cpu_rst_n == `RST_ENABLE ) ? `ZERO_WORD : 
                     (wb_mreg_i == `MREG_ENABLE) ? data : wb_dreg_i;
endmodule
