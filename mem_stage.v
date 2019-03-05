`include "defines.v"

module mem_stage (
    input  wire                         cpu_rst_n,

    // ��ִ�н׶λ�õ���Ϣ
    input  wire [`ALUOP_BUS     ]       mem_aluop_i,
    input  wire [`REG_ADDR_BUS  ]       mem_wa_i,
    input  wire                         mem_wreg_i,
    input  wire [`REG_BUS       ]       mem_wd_i,

    input  wire                         mem_mreg_i,
    input  wire [`REG_BUS       ]       mem_din_i,
    
    input  wire                         mem_whilo_i,
    input  wire [`DOUBLE_REG_BUS]       mem_hilo_i,
    
    // ����д�ؽ׶ε���Ϣ
    output wire [`REG_ADDR_BUS  ]       mem_wa_o,
    output wire                         mem_wreg_o,
    output wire [`REG_BUS       ]       mem_dreg_o,

    output wire                         mem_mreg_o,
    output wire [`BSEL_BUS      ]       dre,
    
    output wire                         mem_whilo_o,
    output wire [`DOUBLE_REG_BUS]       mem_hilo_o,

    // �������ݴ洢�����ź�
    output wire                         dce,
    output wire [`INST_ADDR_BUS ]       daddr,
    output wire [`BSEL_BUS      ]       we,
    output wire [`REG_BUS       ]       din,
/************************MFC0,MTC0 begin*******************************/
    input  wire                         cp0_we_i,
    input  wire [`REG_ADDR_BUS  ]       cp0_waddr_i,
    input  wire [`REG_BUS       ]       cp0_wdata_i,

	output wire                         cp0_we_o,
	output wire [`REG_ADDR_BUS  ]       cp0_waddr_o,
	output wire [`REG_BUS       ] 	    cp0_wdata_o,
/************************MFC0,MTC0 end*********************************/
/************************�쳣���� begin*******************************/
    input  wire                         wb2mem_cp0_we,
    input  wire [`REG_ADDR_BUS  ]       wb2mem_cp0_wa,
    input  wire [`REG_BUS       ]       wb2mem_cp0_wd,

    input  wire [`INST_ADDR_BUS ]       mem_pc_i,
    output wire [`INST_ADDR_BUS ]       cp0_pc,
    input  wire                         mem_in_delay_i,
    output wire                         cp0_in_delay,
    input  wire [`EXC_CODE_BUS  ]       mem_exccode_i,
    output wire [`EXC_CODE_BUS  ]       cp0_exccode,
    input  wire [`INST_ADDR_BUS ]       mem_badvaddr_i,
    output wire [`INST_ADDR_BUS ]       cp0_badvaddr,
    input  wire [`WORD_BUS      ]       cp0_status,
    input  wire [`WORD_BUS      ]       cp0_cause,
/************************�쳣���� end*********************************/
/************************���޷��ż��ش洢�� begin*******************************/
    output wire                         sign,
/************************���޷��ż��ش洢�� end*********************************/
/************************UPDATE--��ӷô�׶���ͣ*******************************/
/************************��ˮ����ͣ begin*********************************/
    // �ô�׶���ͣ�ź�
    output wire                         stallreq_mem,
    input  wire                         mem_data_ok
/************************��ˮ����ͣ end***********************************/
/************************UPDATE--��ӷô�׶���ͣ*******************************/

    );

    // ������ݴ洢���ķ��ʵ�ַ
    assign daddr = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : mem_wd_i;

    wire [`INST_ADDR_BUS] mem_unaligned_addr = daddr;
    wire word_aligned = mem_unaligned_addr[1:0] == 2'b00;
    wire half_aligned = mem_unaligned_addr[0]   == 1'b0 ;

    // �����ǰ���Ƿô�ָ���ֻ��Ҫ�Ѵ�ִ�н׶λ�õ���Ϣֱ�����
    assign mem_wa_o     = (cpu_rst_n == `RST_ENABLE) ? 5'b0  : mem_wa_i;
    assign mem_wreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_wreg_i;
    assign mem_dreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_wd_i;
    assign mem_whilo_o  = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_whilo_i;
    assign mem_hilo_o   = (cpu_rst_n == `RST_ENABLE) ? 64'b0 : mem_hilo_i;
    assign mem_mreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_mreg_i;
/************************MFC0,MTC0 begin*******************************/
    // ֱ������д�ؽ׶ε��ź�
	assign cp0_we_o     = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : cp0_we_i;
	assign cp0_waddr_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_waddr_i;
	assign cp0_wdata_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_wdata_i;
/************************MFC0,MTC0 end*********************************/
/************************�쳣���� begin*******************************/
    // CP0��status�Ĵ�����cause�Ĵ���������ֵ
    wire [`WORD_BUS] status;
    wire [`WORD_BUS] cause;

    // �ж��Ƿ�������CP0�мĴ�����������أ������CP0�мĴ���������ֵ
    assign status = (wb2mem_cp0_we == `WRITE_ENABLE && wb2mem_cp0_wa == `CP0_STATUS) ? wb2mem_cp0_wd : cp0_status;
    assign cause = (wb2mem_cp0_we == `WRITE_ENABLE && wb2mem_cp0_wa == `CP0_CAUSE) ? wb2mem_cp0_wd : cp0_cause;

    // �������뵽CP0Э���������ź�
    assign cp0_in_delay = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_in_delay_i;
/************************UPDATE--�޸ĸ�λʱexccodeӦ��Ϊ`EXC_NONE��bug��������жϵ��ж�*******************************/
    assign cp0_exccode = (cpu_rst_n == `RST_ENABLE) ? `EXC_NONE : 
                          ((status[15:8] & cause[15:8]) != 8'h00 && status[1] == 1'b0 && status[0] == 1'b1) ? `EXC_INT : 
/************************UPDATE--�޸ĸ�λʱexccodeӦ��Ϊ`EXC_NONE��bug��������жϵ��ж�*******************************/
                          ((mem_aluop_i == `MINIMIPS32_LH ) && (!half_aligned))  ? `EXC_ADEL :
                          ((mem_aluop_i == `MINIMIPS32_LHU) && (!half_aligned))  ? `EXC_ADEL :
                          ((mem_aluop_i == `MINIMIPS32_LW ) && (!word_aligned))  ? `EXC_ADEL :
                          ((mem_aluop_i == `MINIMIPS32_SH ) && (!half_aligned))  ? `EXC_ADES :
                          ((mem_aluop_i == `MINIMIPS32_SW ) && (!word_aligned))  ? `EXC_ADES : mem_exccode_i;
    assign cp0_pc       = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT : mem_pc_i;
    assign cp0_badvaddr = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD :
                          ((mem_aluop_i == `MINIMIPS32_LH ) && (!half_aligned))  ? daddr :
                          ((mem_aluop_i == `MINIMIPS32_LHU) && (!half_aligned))  ? daddr :
                          ((mem_aluop_i == `MINIMIPS32_LW ) && (!word_aligned))  ? daddr :
                          ((mem_aluop_i == `MINIMIPS32_SH ) && (!half_aligned))  ? daddr :
                          ((mem_aluop_i == `MINIMIPS32_SW ) && (!word_aligned))  ? daddr : mem_badvaddr_i;
/************************�쳣���� end*********************************/

    // ȷ����ǰ�ķô�ָ��
    wire inst_lb = (mem_aluop_i == 8'h90);
    wire inst_lw = (mem_aluop_i == 8'h92);
    wire inst_sb = (mem_aluop_i == 8'h98);
    wire inst_sw = (mem_aluop_i == 8'h9A);
    wire inst_lh = (mem_aluop_i == 8'h91);
    wire inst_lbu= (mem_aluop_i == 8'h94);
    wire inst_lhu= (mem_aluop_i == 8'h95);
    wire inst_sh = (mem_aluop_i == 8'h99);

/************************���޷��ż��ش洢�� begin*******************************/
    assign sign   = inst_lb | inst_lw | inst_lh;
/************************���޷��ż��ش洢�� end*********************************/

    // ������ݴ洢�����ֽ�ʹ���ź�
    assign dre[3] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                    ((inst_lb & (daddr[1 : 0] == 2'b00)) | inst_lw | (inst_lbu & (daddr[1 : 0] == 2'b00)) | 
                    (inst_lh & (daddr[1 : 0] == 2'b00)) | (inst_lhu & (daddr[1 : 0] == 2'b00)));
    assign dre[2] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                    ((inst_lb & (daddr[1 : 0] == 2'b01)) | inst_lw | (inst_lbu & (daddr[1 : 0] == 2'b01)) | 
                    (inst_lh & (daddr[1 : 0] == 2'b00)) | (inst_lhu & (daddr[1 : 0] == 2'b00)));
    assign dre[1] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                    ((inst_lb & (daddr[1 : 0] == 2'b10)) | inst_lw | (inst_lbu & (daddr[1 : 0] == 2'b10)) | 
                    (inst_lh & (daddr[1 : 0] == 2'b10)) | (inst_lhu & (daddr[1 : 0] == 2'b10)));
    assign dre[0] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                    ((inst_lb & (daddr[1 : 0] == 2'b11)) | inst_lw | (inst_lbu & (daddr[1 : 0] == 2'b11)) | 
                    (inst_lh & (daddr[1 : 0] == 2'b10)) | (inst_lhu & (daddr[1 : 0] == 2'b10)));

    // ������ݴ洢��ʹ���ź�
    assign dce   = (cpu_rst_n == `RST_ENABLE || cp0_exccode != `EXC_NONE || mem_data_ok == 1'b1) ? 1'b0 : 
                   (inst_lb | inst_lw | inst_sb | inst_sw | inst_lbu | inst_lh | inst_lhu | inst_sh);

    // ��÷ô�׶���ͣ�ź�
    assign stallreq_mem = dce;
    
    // ������ݴ洢��д�ֽ�ʹ���ź�
    assign we[3] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b00)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b00)));
    assign we[2] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b01)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b00)));
    assign we[1] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b10)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b10)));
    assign we[0] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b11)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b10)));
                   
    // ȷ����д�����ݴ洢��������
    wire [`WORD_BUS] din_reverse = {mem_din_i[7:0], mem_din_i[15:8], mem_din_i[23:16], mem_din_i[31:24]};
    wire [`WORD_BUS] din_byte    = {mem_din_i[7:0], mem_din_i[7:0], mem_din_i[7:0], mem_din_i[7:0]};
    assign din      = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                      (|we == 1'b0             ) ? `ZERO_WORD :
                      (daddr[31:28] != 4'h8 && daddr[31:28] != 4'h0 && daddr[31:20] != 12'hbfc) ? mem_din_i :
                      (we == 4'b1111           ) ? din_reverse :
                      (we == 4'b1000           ) ? din_byte : 
                      (we == 4'b0100           ) ? din_byte :
                      (we == 4'b0010           ) ? din_byte :
                      (we == 4'b0001           ) ? din_byte : 
                      (we == 4'b1100           ) ? {din_reverse[31:16], {16{1'b0}}} :
                      (we == 4'b0011           ) ? {{16{1'b0}}, din_reverse[31:16]} : `ZERO_WORD;

endmodule
