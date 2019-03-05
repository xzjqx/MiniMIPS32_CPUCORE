`include "defines.v"

module id_stage(
    input  wire                     cpu_rst_n,

/************************ת��ָ����� begin*******************************/
    // ��ȡָ�׶λ�õ�PCֵ
    input  wire [`INST_ADDR_BUS]    id_pc_i,
    input  wire [`INST_ADDR_BUS]    pc_plus_4,
/*********************** ת��ָ����� end*********************************/

    // ��ָ��洢��������ָ����
    input  wire [`INST_BUS     ]    id_inst_i,

    // ��ͨ�üĴ����Ѷ��������� 
    input  wire [`REG_BUS      ]    rd1,
    input  wire [`REG_BUS      ]    rd2,

/***********************�������������� begin************************/
    // ��ִ�н׶λ�õ�д���ź�
    input  wire                     exe2id_wreg,
    input  wire [`REG_ADDR_BUS ]    exe2id_wa,
    input  wire [`INST_BUS     ]    exe2id_wd,

    // �ӷô�׶λ�õ�д���ź�
    input  wire                     mem2id_wreg,
    input  wire [`REG_ADDR_BUS ]    mem2id_wa,
    input  wire [`INST_BUS     ]    mem2id_wd,
/***********************�������������� end***************************/

    // ����ִ�н׶ε�������Ϣ
    output wire [`ALUTYPE_BUS  ]    id_alutype_o,
    output wire [`ALUOP_BUS    ]    id_aluop_o,
    output wire                     id_whilo_o,
    output wire                     id_mreg_o,
    output wire [`REG_ADDR_BUS ]    id_wa_o,
    output wire                     id_wreg_o,
    output wire [`REG_BUS      ]    id_din_o,

    // ����ִ�н׶ε�Դ������1��Դ������2
    output wire [`REG_BUS      ]    id_src1_o,
    output wire [`REG_BUS      ]    id_src2_o,
      
    // ������ͨ�üĴ����Ѷ˿ڵ�ʹ�ܺ͵�ַ
    output wire                     rreg1,
    output wire [`REG_ADDR_BUS ]    ra1,
    output wire                     rreg2,
    output wire [`REG_ADDR_BUS ]    ra2,

/************************ת��ָ����� begin*******************************/
    // ת���ź�
    output wire [`INST_ADDR_BUS]    jump_addr_1,
    output wire [`INST_ADDR_BUS]    jump_addr_2,
    output wire [`INST_ADDR_BUS]    jump_addr_3,
    output wire [`JTSEL_BUS    ]    jtsel,
    output wire [`INST_ADDR_BUS]    ret_addr,
/*********************** ת��ָ����� end*********************************/
/************************��ˮ����ͣ begin*********************************/
    input  wire                     exe2id_mreg,
    input  wire                     mem2id_mreg,
    // ����׶���ͣ�ź�
    output wire                     stallreq_id,
/************************��ˮ����ͣ end***********************************/
/************************MFC0,MTC0 begin*******************************/
    output wire [`REG_ADDR_BUS ]    cp0_addr,       // CP0�мĴ����ĵ�ַ
/************************MFC0,MTC0 end*********************************/
/************************�쳣���� begin*******************************/
    input  wire                     id_in_delay_i,  // ��������׶ε�ָ�����ӳٲ�ָ��
    output wire [`INST_ADDR_BUS]    id_pc_o,        // ��������׶ε�ָ���PCֵ
    output wire                     id_in_delay_o,  // ��������׶ε�ָ�����ӳٲ�ָ��
    output wire                     next_delay_o,   // ��һ����������׶ε�ָ�����ӳٲ�ָ��
    // �쳣�ź�
    input  wire [`EXC_CODE_BUS  ]   id_exccode_i,   // ��������׶ε�ָ����쳣���ͱ���
    output wire [`EXC_CODE_BUS  ]   id_exccode_o,   // ��������׶ε�ָ����쳣���ͱ���
    input  wire [`WORD_BUS      ]   id_badvaddr_i,  // ��������׶ε�ָ��Ĵ����ַ
    output wire [`WORD_BUS      ]   id_badvaddr_o   // ��������׶ε�ָ��Ĵ����ַ
/************************�쳣���� end*********************************/
    );
/************************�쳣���� begin*******************************/
    // ֱ��������һ�׶ε��ź�
    assign id_pc_o       = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT : id_pc_i;
    assign id_in_delay_o = (cpu_rst_n == `RST_ENABLE) ? `FALSE_V : id_in_delay_i;
/************************�쳣���� end*********************************/

/************************UPDATE--ȡ�����쳣�źŵ��ж�*******************************/
    wire [`INST_BUS] id_inst = {id_inst_i[7:0], id_inst_i[15:8], id_inst_i[23:16], id_inst_i[31:24]};
/************************UPDATE--ȡ�����쳣�źŵ��ж�*******************************/

    // ��ȡָ�����и����ֶε���Ϣ
    wire [5 :0] op   = id_inst[31:26];
    wire [5 :0] func = id_inst[5 : 0];
    wire [4 :0] rd   = id_inst[15:11];
    wire [4 :0] rs   = id_inst[25:21];
    wire [4 :0] rt   = id_inst[20:16];
    wire [4 :0] sa   = id_inst[10: 6];
    wire [15:0] imm  = id_inst[15: 0]; 

    // ��һ�������߼�����SYSCALL��ERET��MFC0��MTC0ָ���ʶ���ź�
    wire inst_reg  = ~|op;
    wire inst_add  = inst_reg& func[5]&~func[4]&~func[3]&~func[2]&~func[1]&~func[0];
    wire inst_subu = inst_reg& func[5]&~func[4]&~func[3]&~func[2]& func[1]& func[0];
    wire inst_slt  = inst_reg& func[5]&~func[4]& func[3]&~func[2]& func[1]&~func[0];
    wire inst_and  = inst_reg& func[5]&~func[4]&~func[3]& func[2]&~func[1]&~func[0];
    wire inst_mult = inst_reg&~func[5]& func[4]& func[3]&~func[2]&~func[1]&~func[0];
    wire inst_mfhi = inst_reg&~func[5]& func[4]&~func[3]&~func[2]&~func[1]&~func[0];
    wire inst_mflo = inst_reg&~func[5]& func[4]&~func[3]&~func[2]& func[1]&~func[0];
    wire inst_sll  = inst_reg&~func[5]&~func[4]&~func[3]&~func[2]&~func[1]&~func[0];
    wire inst_ori  =~op[5]&~op[4]& op[3]& op[2]&~op[1]& op[0];
    wire inst_lui  =~op[5]&~op[4]& op[3]& op[2]& op[1]& op[0];
    wire inst_addiu=~op[5]&~op[4]& op[3]&~op[2]&~op[1]& op[0];
    wire inst_sltiu=~op[5]&~op[4]& op[3]&~op[2]& op[1]& op[0];
    wire inst_lb   = op[5]&~op[4]&~op[3]&~op[2]&~op[1]&~op[0];
    wire inst_lw   = op[5]&~op[4]&~op[3]&~op[2]& op[1]& op[0];
    wire inst_sb   = op[5]&~op[4]& op[3]&~op[2]&~op[1]&~op[0];
    wire inst_sw   = op[5]&~op[4]& op[3]&~op[2]& op[1]& op[0];
/************************ת�ƺͳ���ָ����� begin*******************************/
    wire inst_j    =~op[5]&~op[4]&~op[3]&~op[2]& op[1]&~op[0];
    wire inst_jal  =~op[5]&~op[4]&~op[3]&~op[2]& op[1]& op[0];
    wire inst_jr   = inst_reg&~func[5]&~func[4]& func[3]&~func[2]&~func[1]&~func[0];
    wire inst_beq  =~op[5]&~op[4]&~op[3]& op[2]&~op[1]&~op[0];
    wire inst_bne  =~op[5]&~op[4]&~op[3]& op[2]&~op[1]& op[0];
    wire inst_div  = inst_reg&~func[5]& func[4]& func[3]&~func[2]& func[1]&~func[0];
/*********************** ת�ƺͳ���ָ����� end*********************************/
/************************�쳣������� begin*******************************/
    wire inst_syscall = inst_reg&~func[5]&~func[4]& func[3]& func[2]&~func[1]&~func[0];
    wire inst_eret    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]&~func[5]& func[4]& func[3]&~func[2]&~func[1]&~func[0];
    wire inst_mfc0    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]&~id_inst[23];
    wire inst_mtc0    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]& id_inst[23];
/************************�쳣������� end*********************************/
    wire inst_mthi    =inst_reg&~func[5]& func[4]&~func[3]&~func[2]&~func[1]& func[0];
    wire inst_mtlo    =inst_reg&~func[5]& func[4]&~func[3]&~func[2]& func[1]& func[0];
    wire inst_sllv    =inst_reg&~func[5]&~func[4]&~func[3]& func[2]&~func[1]&~func[0];
    wire inst_srl     =inst_reg&~func[5]&~func[4]&~func[3]&~func[2]& func[1]&~func[0];
    wire inst_srlv    =inst_reg&~func[5]&~func[4]&~func[3]& func[2]& func[1]&~func[0];
    wire inst_sra     =inst_reg&~func[5]&~func[4]&~func[3]&~func[2]& func[1]& func[0];
    wire inst_srav    =inst_reg&~func[5]&~func[4]&~func[3]& func[2]& func[1]& func[0];
    wire inst_multu   =inst_reg&~func[5]& func[4]& func[3]&~func[2]&~func[1]& func[0];
    wire inst_divu    =inst_reg&~func[5]& func[4]& func[3]&~func[2]& func[1]& func[0];
    wire inst_addi    =~op[5]&~op[4]& op[3]&~op[2]&~op[1]&~op[0];
    wire inst_addu    =inst_reg& func[5]&~func[4]&~func[3]&~func[2]&~func[1]& func[0];
    wire inst_sub     =inst_reg& func[5]&~func[4]&~func[3]&~func[2]& func[1]&~func[0];
    wire inst_andi    =~op[5]&~op[4]& op[3]& op[2]&~op[1]&~op[0];
    wire inst_or      =inst_reg& func[5]&~func[4]&~func[3]& func[2]&~func[1]& func[0];
    wire inst_xor     =inst_reg& func[5]&~func[4]&~func[3]& func[2]& func[1]&~func[0];
    wire inst_xori    =~op[5]&~op[4]& op[3]& op[2]& op[1]&~op[0];
    wire inst_nor     =inst_reg& func[5]&~func[4]&~func[3]& func[2]& func[1]& func[0];
    wire inst_slti    =~op[5]&~op[4]& op[3]&~op[2]& op[1]&~op[0];
    wire inst_sltu    =inst_reg& func[5]&~func[4]& func[3]&~func[2]& func[1]& func[0];
    wire inst_jalr    =inst_reg&~func[5]&~func[4]& func[3]&~func[2]&~func[1]& func[0];
    wire inst_blez    =~op[5]&~op[4]&~op[3]& op[2]& op[1]&~op[0];
    wire inst_bgtz    =~op[5]&~op[4]&~op[3]& op[2]& op[1]& op[0];
    wire inst_bltz    =~op[5]&~op[4]&~op[3]&~op[2]&~op[1]& op[0]&~id_inst[20]&~id_inst[16];
    wire inst_bgez    =~op[5]&~op[4]&~op[3]&~op[2]&~op[1]& op[0]&~id_inst[20]& id_inst[16];
    wire inst_bltzal  =~op[5]&~op[4]&~op[3]&~op[2]&~op[1]& op[0]& id_inst[20]&~id_inst[16];
    wire inst_bgezal  =~op[5]&~op[4]&~op[3]&~op[2]&~op[1]& op[0]& id_inst[20]& id_inst[16];
    wire inst_lh      = op[5]&~op[4]&~op[3]&~op[2]&~op[1]& op[0];
    wire inst_lbu     = op[5]&~op[4]&~op[3]& op[2]&~op[1]&~op[0];
    wire inst_lhu     = op[5]&~op[4]&~op[3]& op[2]&~op[1]& op[0];
    wire inst_sh      = op[5]&~op[4]& op[3]&~op[2]&~op[1]& op[0];
    wire inst_break   =inst_reg&~func[5]&~func[4]& func[3]& func[2]&~func[1]& func[0];

    wire inst_invalid   =  !(inst_addiu|inst_addu|inst_slt|inst_slti
                        |inst_sltiu|inst_sltu|inst_subu|inst_mult
                        |inst_beq|inst_bgez|inst_bgtz|inst_blez|inst_bltz
                        |inst_bne|inst_j|inst_jr|inst_jal|inst_jalr|inst_lw
                        |inst_sb|inst_lbu|inst_lhu|inst_and|inst_andi
                        |inst_lui|inst_nor|inst_or|inst_ori|inst_xor
                        |inst_xori|inst_mfhi|inst_lb|inst_multu|inst_sw
                        |inst_mflo|inst_mthi|inst_mtlo|inst_sll
                        |inst_sllv|inst_sra|inst_srav|inst_srl|inst_srlv
                        |inst_syscall|inst_eret|inst_mfc0|inst_mtc0
                        |inst_div|inst_divu|inst_add|inst_addi|inst_sub
                        |inst_bltzal|inst_bgezal|inst_lh|inst_sh|inst_break);
    /*------------------------------------------------------------------------------*/

    // �ڶ��������߼�������������ź�
	// ��������alutype
/************************ת�ƺͳ���ָ��쳣�����޸� begin*******************************/
    assign id_alutype_o[2] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_sll | inst_j | inst_jal | inst_jr | inst_beq | inst_bne |
                             inst_syscall | inst_eret | inst_mtc0 |
                             inst_sllv | inst_srl | inst_srlv | inst_sra | inst_srav | inst_jalr |
                             inst_blez | inst_bgtz | inst_bltz | inst_bgez | inst_bltzal | inst_bgezal | inst_break);
    assign id_alutype_o[1] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_and | inst_mfhi | inst_mflo | inst_ori | inst_lui |
                             inst_syscall | inst_eret | inst_mfc0 | inst_mtc0 | inst_mthi | inst_mtlo |
                             inst_andi | inst_or | inst_xor | inst_xori | inst_nor | inst_break);
    assign id_alutype_o[0] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_add | inst_subu | inst_slt | inst_mfhi | inst_mflo | 
                             inst_addiu | inst_sltiu | inst_lb |inst_lw | inst_sb | inst_sw | 
                             inst_j | inst_jal | inst_jr | inst_beq | inst_bne | inst_mthi | inst_mtlo | 
                             inst_addi | inst_addu | inst_sub | inst_jalr | inst_mfc0 |
                             inst_blez | inst_bgtz | inst_bltz | inst_bgez | inst_bltzal | inst_bgezal |
                             inst_lh | inst_lbu | inst_lhu | inst_sh | inst_slti | inst_sltu);

    // �ڲ�������aluop
    assign id_aluop_o[7]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_lb | inst_lw | inst_sb | inst_sw |
                             inst_syscall | inst_eret | inst_mfc0 | inst_mtc0 | inst_lh | inst_lbu | inst_lhu | inst_sh);
    assign id_aluop_o[6]   = 1'b0;
    assign id_aluop_o[5]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_slt | inst_sltiu | inst_j | inst_jal | inst_jr | inst_beq | inst_bne | 
                             inst_slti | inst_sltu | inst_blez | inst_bgtz | inst_bltz | inst_bgez | inst_bltzal | inst_bgezal | inst_jalr);
    assign id_aluop_o[4]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_add | inst_subu | inst_and | inst_mult | inst_sll |
                             inst_ori | inst_addiu | inst_lb | inst_lw | inst_sb | inst_sw |
                             inst_beq | inst_bne | inst_div  | inst_sllv | inst_srl | inst_srlv | inst_sra | inst_srav |
                             inst_multu | inst_divu | inst_addi | inst_addu | inst_sub | inst_andi | inst_or | 
                             inst_xor | inst_xori | inst_nor | inst_blez | inst_bgtz | inst_bltz | inst_bgez | inst_bltzal | inst_bgezal |
                             inst_lh | inst_lbu | inst_lhu | inst_sh);
    assign id_aluop_o[3]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_add | inst_subu | inst_and | inst_mfhi | inst_mflo | 
                             inst_ori | inst_addiu | inst_sb | inst_sw | inst_j | inst_jal | inst_jr |
                             inst_mfc0 | inst_mtc0 | inst_mthi | inst_mtlo | inst_addi | inst_addu | inst_sub | inst_andi |
                             inst_or | inst_xor | inst_xori | inst_nor | inst_sh | inst_jalr);
    assign id_aluop_o[2]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_slt | inst_and | inst_mult | inst_mfhi | inst_mflo | 
                             inst_ori | inst_lui | inst_sltiu | inst_j | inst_jal | inst_jr | inst_div |
                             inst_syscall | inst_eret | inst_mfc0 | inst_mtc0 | inst_mthi | inst_mtlo | inst_multu | inst_divu |
                             inst_andi | inst_or | inst_xor | inst_xori | inst_nor | inst_slti | inst_sltu | inst_bltz | inst_bgez |
                             inst_bltzal | inst_bgezal | inst_lbu | inst_lhu | inst_jalr);
    assign id_aluop_o[1]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_subu | inst_slt | inst_sltiu | inst_lw | inst_sw | inst_jal | inst_div |
                             inst_syscall | inst_eret | inst_mthi | inst_mtlo | inst_srl | inst_srlv | inst_sra | inst_srav |
                             inst_divu | inst_sub | inst_xor | inst_xori | inst_nor | inst_slti | inst_sltu |
                             inst_blez | inst_bgtz | inst_bltzal | inst_bgezal | inst_jalr);
    assign id_aluop_o[0]   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_subu | inst_mflo | inst_sll |
                             inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_jr | inst_bne | 
                             inst_eret | inst_mtc0 | inst_mtlo | inst_sllv | inst_sra | inst_srav | inst_multu | inst_divu |
                             inst_addu | inst_or | inst_nor | inst_sltu | inst_bgtz | inst_bgez | inst_bgezal | inst_lh | inst_lhu | inst_sh |
                             inst_jalr);

    // Ŀ�ļĴ���дʹ���ź�
    assign id_wreg_o       = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_add | inst_subu | inst_slt | inst_and | inst_mfhi | inst_mflo | inst_sll | 
                             inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_jal | inst_mfc0 |
                             inst_or | inst_xor | inst_nor | inst_srl | inst_sra | inst_srlv | inst_srav | inst_addu |
                             inst_sub | inst_sltu | inst_jalr | inst_andi | inst_xori | inst_addi | inst_slti | inst_lbu |
                             inst_lh | inst_lhu | inst_bgezal | inst_bltzal | inst_sllv);
/*********************** ת�ƺͳ���ָ��쳣�����޸� end*********************************/

    // дHILO�Ĵ���ʹ���ź�
/*********************** ����ָ���޸� begin*******************************/
    assign id_whilo_o      = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : (inst_mult  | inst_div | inst_mthi | inst_mtlo | inst_multu | inst_divu);
/*********************** ����ָ���޸� end*********************************/
    // ��λʹ��ָ��
    wire shift = inst_sll | inst_sra | inst_srl;
    // ������ʹ���ź�
    wire immsel = inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw | 
                  inst_addi | inst_andi | inst_xori | inst_slti | inst_lh | inst_lbu | inst_lhu | inst_sh;
    // Ŀ�ļĴ���ѡ���ź�
    wire rtsel  = inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_mfc0 | inst_addi | inst_andi |
                  inst_xori | inst_slti | inst_lh | inst_lbu | inst_lhu;
    // ������չʹ���ź�
    wire sext   = inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw | inst_addi | inst_slti | 
                  inst_lh | inst_lbu | inst_lhu | inst_sh;
    // ���ظ߰���ʹ���ź�
    wire upper  = inst_lui;
    // �洢�����Ĵ���ʹ���ź�
    assign id_mreg_o       = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : (inst_lb | inst_lw | inst_lh | inst_lbu | inst_lhu);
    // ͨ�üĴ����Ѷ��˿�1ʹ���ź�
/*********************** ת�ƺͳ���ָ��,MTC0�޸� begin*******************************/
    assign rreg1 = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   (inst_add | inst_subu | inst_slt | inst_and | inst_mult | 
                   inst_ori | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw |
                   inst_jr | inst_beq | inst_bne | inst_div | inst_mthi | inst_mtlo |
                   inst_sllv | inst_srlv | inst_srav | inst_multu | inst_divu | inst_addi | inst_addu |
                   inst_sub | inst_andi | inst_or | inst_xor | inst_xori | inst_nor | inst_slti | inst_sltu |
                   inst_jalr | inst_blez | inst_bgez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal |
                   inst_lh | inst_lbu | inst_lhu | inst_sh);
    // ͨ�üĴ����Ѷ��˿�2ʹ���ź�
    assign rreg2 = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   (inst_add | inst_subu | inst_slt | inst_and | inst_mult | inst_sll | 
                   inst_sllv | inst_srlv | inst_srav | 
                   inst_sb | inst_sw | inst_beq | inst_bne | inst_div | inst_mtc0 | inst_srl | inst_sra | 
                   inst_multu | inst_divu | inst_addu | inst_sub | inst_or | inst_xor | inst_nor | inst_sltu | inst_sh);
/*********************** ת�ƺͳ���ָ�MTC0�޸� end*********************************/
    /*------------------------------------------------------------------------------*/

    // ��ͨ�üĴ����Ѷ˿�1�ĵ�ַΪrs�ֶΣ����˿�2�ĵ�ַΪrt�ֶ�
    assign ra1   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : rs;
    assign ra2   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : rt;
    
    // ���ָ���������������� 
    wire [31:0] imm_ext = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD :
                          (upper == `UPPER_ENABLE  ) ? (imm << 16) :
                          (sext  == `SIGNED_EXT    ) ? {{16{imm[15]}}, imm} : {{16{1'b0}}, imm};
                                            
    // ��ô�д��Ŀ�ļĴ����ĵ�ַ����������rt�ֶΡ���������rd�ֶΡ�Ҳ������31�żĴ����ĵ�ַ��
/*********************** ת��ָ��,MFC0�޸� begin*******************************/
    wire jal = inst_jal | inst_bgezal | inst_bltzal;
    // Ŀ�ļĴ����ĵ�ַ
    assign id_wa_o   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                       (rtsel == `RT_ENABLE || inst_mfc0) ? rt :
                       (jal   == `TRUE_V        ) ? 5'b11111 : rd;
/*********************** ת��ָ��,MFC0�޸� end*********************************/

/***********************�������������� begin************************/
    // ���Դ������ѡ���źţ�Դ������Ҳ��������ִ����ô�׶Σ�����ǰ�ƣ�
    wire [1:0] fwrd1 = (cpu_rst_n == `RST_ENABLE) ? 2'b00 :
                       (exe2id_wreg == `WRITE_ENABLE && exe2id_wa == rs && rreg1 == `READ_ENABLE) ? 2'b01 : 
                       (mem2id_wreg == `WRITE_ENABLE && mem2id_wa == rs && rreg1 == `READ_ENABLE) ? 2'b10 : 
                       (rreg1 == `READ_ENABLE) ? 2'b11 : 2'b00;
    wire [1:0] fwrd2 = (cpu_rst_n == `RST_ENABLE) ? 2'b00 :
                       (exe2id_wreg == `WRITE_ENABLE && exe2id_wa == rt && rreg2 == `READ_ENABLE) ? 2'b01 : 
                       (mem2id_wreg == `WRITE_ENABLE && mem2id_wa == rt && rreg2 == `READ_ENABLE) ? 2'b10 : 
                       (rreg2 == `READ_ENABLE) ? 2'b11 : 2'b00;
/***********************�������������� end**************************/

    // ��÷ô�׶�Ҫ�������ݴ洢�������ݣ���������ִ�н׶�ǰ�Ƶ����ݡ��������Էô�׶�ǰ�Ƶ����ݡ�Ҳ��������ͨ�üĴ����ѵĶ��˿�2��
    assign id_din_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                       (fwrd2     == 2'b01        ) ? exe2id_wd : 
                       (fwrd2     == 2'b10        ) ? mem2id_wd : 
                       (fwrd2     == 2'b11        ) ? rd2 : `ZERO_WORD;

/***********************������������޸� begin************************/
    // ���Դ������1��Դ������1��������λλ������������ִ�н׶�ǰ�Ƶ����ݡ��������Էô�׶�ǰ�Ƶ����ݡ�Ҳ��������ͨ�üĴ����ѵĶ��˿�1
    assign id_src1_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD :
                       (shift     == `SHIFT_ENABLE) ? {27'b0, sa} :
                       (fwrd1     == 2'b01        ) ? exe2id_wd : 
                       (fwrd1     == 2'b10        ) ? mem2id_wd : 
                       (fwrd1     == 2'b11        ) ? rd1 : `ZERO_WORD;

    // ���Դ������2��Դ������1��������������չ����������ִ�н׶�ǰ�Ƶ����ݡ��������Էô�׶�ǰ�Ƶ����ݡ�Ҳ��������ͨ�üĴ����ѵĶ��˿�2
    assign id_src2_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD : 
                       (immsel == `IMM_ENABLE     ) ? imm_ext : 
                       (fwrd2     == 2'b01        ) ? exe2id_wd : 
                       (fwrd2     == 2'b10        ) ? mem2id_wd : 
                       (fwrd2     == 2'b11        ) ? rd2 : `ZERO_WORD;
/***********************������������޸� end**************************/

/*********************** ת��ָ����� begin*******************************/
    // ���ɼ���ת�Ƶ�ַ�����ź�
    wire [`INST_ADDR_BUS] pc_plus_8   = pc_plus_4 + 4;
    wire [`JUMP_BUS     ] instr_index = id_inst[25:0];
    wire [`INST_ADDR_BUS] imm_jump    = {{14{imm[15]}}, imm, 2'b00};
    // ���ת�Ƶ�ַ
    assign jump_addr_1 = {pc_plus_4[31:28], instr_index, 2'b00};
    assign jump_addr_2 = pc_plus_4 + imm_jump;
    assign jump_addr_3 = id_src1_o;
    assign ret_addr    = pc_plus_8;
    // ���ת�ƿ����ź�
    wire equ = (cpu_rst_n == `RST_ENABLE) ? 1'b0 :
               (inst_beq   ) ? (id_src1_o == id_src2_o) :
               (inst_bne   ) ? (id_src1_o != id_src2_o) : 
               (inst_blez  ) ? (id_src1_o[31] == 1'b1 || id_src1_o == `ZERO_WORD) : 
               (inst_bgez  ) ? (id_src1_o[31] == 1'b0) :
               (inst_bltz  ) ? (id_src1_o[31] == 1'b1) :
               (inst_bgtz  ) ? (id_src1_o[31] == 1'b0 && id_src1_o != `ZERO_WORD) : 
               (inst_bgezal) ? (id_src1_o[31] == 1'b0) :
               (inst_bltzal) ? (id_src1_o[31] == 1'b1) : 1'b0;
    assign jtsel[1] = inst_jr | inst_beq & equ | inst_bne & equ | inst_jalr | 
                      inst_blez & equ | inst_bgez & equ | inst_bltz & equ | inst_bgtz & equ | inst_bgezal & equ | inst_bltzal & equ;
    assign jtsel[0] = inst_j | inst_jal | inst_beq & equ | inst_bne & equ |
                      inst_blez & equ | inst_bgez & equ | inst_bltz & equ | inst_bgtz & equ | inst_bgezal & equ | inst_bltzal & equ;
/*********************** ת��ָ����� end*********************************/
/************************��ˮ����ͣ begin*********************************/
    // ����׶���ͣ�źţ�����������
    // �����ǰ����ִ�н׶ε�ָ���Ǽ���ָ������봦������׶�ָ�����������أ�����������������ڼ������
    // �����ǰ���ڷô�׶ε�ָ���Ǽ���ָ������봦������׶�ָ�����������أ��������������Ҳ���ڼ������
    assign stallreq_id = (cpu_rst_n == `RST_ENABLE) ? `NOSTOP :
                         ((fwrd1 == 2'b01 || fwrd2 == 2'b01) && (exe2id_mreg == `TRUE_V)) ? `STOP :
                         ((fwrd1 == 2'b10 || fwrd2 == 2'b10) && (mem2id_mreg == `TRUE_V)) ? `STOP : `NOSTOP;
/************************��ˮ����ͣ end***********************************/
/************************�쳣���� begin*******************************/
    // �ж���һ��ָ���Ƿ�Ϊ�ӳٲ�ָ��
    assign next_delay_o = (cpu_rst_n == `RST_ENABLE) ? `FALSE_V : 
                          (inst_j | inst_jr | inst_jal | inst_beq | inst_bne | inst_jalr |
                          inst_blez | inst_bgez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal);
    // �жϵ�ǰ��������׶�ָ���Ƿ�����쳣����������Ӧ���쳣���ͱ���
    assign id_exccode_o = (cpu_rst_n == `RST_ENABLE) ? `EXC_NONE : 
                       (id_exccode_i != `EXC_NONE  ) ? id_exccode_i :
                       (inst_break == `TRUE_V   ) ? `EXC_BREAK : 
					   (inst_syscall == `TRUE_V ) ? `EXC_SYS : 
                       (inst_eret == `TRUE_V    ) ? `EXC_ERET : 
                       (inst_invalid == `TRUE_V ) ? `EXC_RI : `EXC_NONE;
    assign id_badvaddr_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD : id_badvaddr_i;
/************************�쳣���� end*********************************/
/************************MFC0,MTC0 begin*******************************/
    assign cp0_addr = (cpu_rst_n == `RST_ENABLE) ? `REG_NOP : rd;       // ���CP0�Ĵ����ķ��ʵ�ַ
/************************MFC0,MTC0 end*********************************/
endmodule
