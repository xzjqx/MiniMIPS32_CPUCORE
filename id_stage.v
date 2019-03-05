`include "defines.v"

module id_stage(
    input  wire                     cpu_rst_n,

/************************转移指令添加 begin*******************************/
    // 从取指阶段获得的PC值
    input  wire [`INST_ADDR_BUS]    id_pc_i,
    input  wire [`INST_ADDR_BUS]    pc_plus_4,
/*********************** 转移指令添加 end*********************************/

    // 从指令存储器读出的指令字
    input  wire [`INST_BUS     ]    id_inst_i,

    // 从通用寄存器堆读出的数据 
    input  wire [`REG_BUS      ]    rd1,
    input  wire [`REG_BUS      ]    rd2,

/***********************消除数据相关添加 begin************************/
    // 从执行阶段获得的写回信号
    input  wire                     exe2id_wreg,
    input  wire [`REG_ADDR_BUS ]    exe2id_wa,
    input  wire [`INST_BUS     ]    exe2id_wd,

    // 从访存阶段获得的写回信号
    input  wire                     mem2id_wreg,
    input  wire [`REG_ADDR_BUS ]    mem2id_wa,
    input  wire [`INST_BUS     ]    mem2id_wd,
/***********************消除数据相关添加 end***************************/

    // 送至执行阶段的译码信息
    output wire [`ALUTYPE_BUS  ]    id_alutype_o,
    output wire [`ALUOP_BUS    ]    id_aluop_o,
    output wire                     id_whilo_o,
    output wire                     id_mreg_o,
    output wire [`REG_ADDR_BUS ]    id_wa_o,
    output wire                     id_wreg_o,
    output wire [`REG_BUS      ]    id_din_o,

    // 送至执行阶段的源操作数1、源操作数2
    output wire [`REG_BUS      ]    id_src1_o,
    output wire [`REG_BUS      ]    id_src2_o,
      
    // 送至读通用寄存器堆端口的使能和地址
    output wire                     rreg1,
    output wire [`REG_ADDR_BUS ]    ra1,
    output wire                     rreg2,
    output wire [`REG_ADDR_BUS ]    ra2,

/************************转移指令添加 begin*******************************/
    // 转移信号
    output wire [`INST_ADDR_BUS]    jump_addr_1,
    output wire [`INST_ADDR_BUS]    jump_addr_2,
    output wire [`INST_ADDR_BUS]    jump_addr_3,
    output wire [`JTSEL_BUS    ]    jtsel,
    output wire [`INST_ADDR_BUS]    ret_addr,
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
    input  wire                     exe2id_mreg,
    input  wire                     mem2id_mreg,
    // 译码阶段暂停信号
    output wire                     stallreq_id,
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
    output wire [`REG_ADDR_BUS ]    cp0_addr,       // CP0中寄存器的地址
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
    input  wire                     id_in_delay_i,  // 处于译码阶段的指令是延迟槽指令
    output wire [`INST_ADDR_BUS]    id_pc_o,        // 处于译码阶段的指令的PC值
    output wire                     id_in_delay_o,  // 处于译码阶段的指令是延迟槽指令
    output wire                     next_delay_o,   // 下一条进入译码阶段的指令是延迟槽指令
    // 异常信号
    input  wire [`EXC_CODE_BUS  ]   id_exccode_i,   // 处于译码阶段的指令的异常类型编码
    output wire [`EXC_CODE_BUS  ]   id_exccode_o,   // 处于译码阶段的指令的异常类型编码
    input  wire [`WORD_BUS      ]   id_badvaddr_i,  // 处于译码阶段的指令的错误地址
    output wire [`WORD_BUS      ]   id_badvaddr_o   // 处于译码阶段的指令的错误地址
/************************异常处理 end*********************************/
    );
/************************异常处理 begin*******************************/
    // 直接送至下一阶段的信号
    assign id_pc_o       = (cpu_rst_n == `RST_ENABLE) ? `PC_INIT : id_pc_i;
    assign id_in_delay_o = (cpu_rst_n == `RST_ENABLE) ? `FALSE_V : id_in_delay_i;
/************************异常处理 end*********************************/

/************************UPDATE--取消对异常信号的判断*******************************/
    wire [`INST_BUS] id_inst = {id_inst_i[7:0], id_inst_i[15:8], id_inst_i[23:16], id_inst_i[31:24]};
/************************UPDATE--取消对异常信号的判断*******************************/

    // 提取指令字中各个字段的信息
    wire [5 :0] op   = id_inst[31:26];
    wire [5 :0] func = id_inst[5 : 0];
    wire [4 :0] rd   = id_inst[15:11];
    wire [4 :0] rs   = id_inst[25:21];
    wire [4 :0] rt   = id_inst[20:16];
    wire [4 :0] sa   = id_inst[10: 6];
    wire [15:0] imm  = id_inst[15: 0]; 

    // 第一级译码逻辑产生SYSCALL、ERET、MFC0和MTC0指令的识别信号
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
/************************转移和除法指令添加 begin*******************************/
    wire inst_j    =~op[5]&~op[4]&~op[3]&~op[2]& op[1]&~op[0];
    wire inst_jal  =~op[5]&~op[4]&~op[3]&~op[2]& op[1]& op[0];
    wire inst_jr   = inst_reg&~func[5]&~func[4]& func[3]&~func[2]&~func[1]&~func[0];
    wire inst_beq  =~op[5]&~op[4]&~op[3]& op[2]&~op[1]&~op[0];
    wire inst_bne  =~op[5]&~op[4]&~op[3]& op[2]&~op[1]& op[0];
    wire inst_div  = inst_reg&~func[5]& func[4]& func[3]&~func[2]& func[1]&~func[0];
/*********************** 转移和除法指令添加 end*********************************/
/************************异常处理添加 begin*******************************/
    wire inst_syscall = inst_reg&~func[5]&~func[4]& func[3]& func[2]&~func[1]&~func[0];
    wire inst_eret    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]&~func[5]& func[4]& func[3]&~func[2]&~func[1]&~func[0];
    wire inst_mfc0    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]&~id_inst[23];
    wire inst_mtc0    =~op[5]& op[4]&~op[3]&~op[2]&~op[1]&~op[0]& id_inst[23];
/************************异常处理添加 end*********************************/
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

    // 第二级译码逻辑产生译码控制信号
	// 操作类型alutype
/************************转移和除法指令，异常处理修改 begin*******************************/
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

    // 内部操作码aluop
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

    // 目的寄存器写使能信号
    assign id_wreg_o       = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                             (inst_add | inst_subu | inst_slt | inst_and | inst_mfhi | inst_mflo | inst_sll | 
                             inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_jal | inst_mfc0 |
                             inst_or | inst_xor | inst_nor | inst_srl | inst_sra | inst_srlv | inst_srav | inst_addu |
                             inst_sub | inst_sltu | inst_jalr | inst_andi | inst_xori | inst_addi | inst_slti | inst_lbu |
                             inst_lh | inst_lhu | inst_bgezal | inst_bltzal | inst_sllv);
/*********************** 转移和除法指令，异常处理修改 end*********************************/

    // 写HILO寄存器使能信号
/*********************** 除法指令修改 begin*******************************/
    assign id_whilo_o      = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : (inst_mult  | inst_div | inst_mthi | inst_mtlo | inst_multu | inst_divu);
/*********************** 除法指令修改 end*********************************/
    // 移位使能指令
    wire shift = inst_sll | inst_sra | inst_srl;
    // 立即数使能信号
    wire immsel = inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw | 
                  inst_addi | inst_andi | inst_xori | inst_slti | inst_lh | inst_lbu | inst_lhu | inst_sh;
    // 目的寄存器选择信号
    wire rtsel  = inst_ori | inst_lui | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_mfc0 | inst_addi | inst_andi |
                  inst_xori | inst_slti | inst_lh | inst_lbu | inst_lhu;
    // 符号扩展使能信号
    wire sext   = inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw | inst_addi | inst_slti | 
                  inst_lh | inst_lbu | inst_lhu | inst_sh;
    // 加载高半字使能信号
    wire upper  = inst_lui;
    // 存储器到寄存器使能信号
    assign id_mreg_o       = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : (inst_lb | inst_lw | inst_lh | inst_lbu | inst_lhu);
    // 通用寄存器堆读端口1使能信号
/*********************** 转移和除法指令,MTC0修改 begin*******************************/
    assign rreg1 = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   (inst_add | inst_subu | inst_slt | inst_and | inst_mult | 
                   inst_ori | inst_addiu | inst_sltiu | inst_lb | inst_lw | inst_sb | inst_sw |
                   inst_jr | inst_beq | inst_bne | inst_div | inst_mthi | inst_mtlo |
                   inst_sllv | inst_srlv | inst_srav | inst_multu | inst_divu | inst_addi | inst_addu |
                   inst_sub | inst_andi | inst_or | inst_xor | inst_xori | inst_nor | inst_slti | inst_sltu |
                   inst_jalr | inst_blez | inst_bgez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal |
                   inst_lh | inst_lbu | inst_lhu | inst_sh);
    // 通用寄存器堆读端口2使能信号
    assign rreg2 = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   (inst_add | inst_subu | inst_slt | inst_and | inst_mult | inst_sll | 
                   inst_sllv | inst_srlv | inst_srav | 
                   inst_sb | inst_sw | inst_beq | inst_bne | inst_div | inst_mtc0 | inst_srl | inst_sra | 
                   inst_multu | inst_divu | inst_addu | inst_sub | inst_or | inst_xor | inst_nor | inst_sltu | inst_sh);
/*********************** 转移和除法指令，MTC0修改 end*********************************/
    /*------------------------------------------------------------------------------*/

    // 读通用寄存器堆端口1的地址为rs字段，读端口2的地址为rt字段
    assign ra1   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : rs;
    assign ra2   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : rt;
    
    // 获得指令操作所需的立即数 
    wire [31:0] imm_ext = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD :
                          (upper == `UPPER_ENABLE  ) ? (imm << 16) :
                          (sext  == `SIGNED_EXT    ) ? {{16{imm[15]}}, imm} : {{16{1'b0}}, imm};
                                            
    // 获得待写入目的寄存器的地址（可能来自rt字段、可能来自rd字段、也可能是31号寄存器的地址）
/*********************** 转移指令,MFC0修改 begin*******************************/
    wire jal = inst_jal | inst_bgezal | inst_bltzal;
    // 目的寄存器的地址
    assign id_wa_o   = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                       (rtsel == `RT_ENABLE || inst_mfc0) ? rt :
                       (jal   == `TRUE_V        ) ? 5'b11111 : rd;
/*********************** 转移指令,MFC0修改 end*********************************/

/***********************消除数据相关添加 begin************************/
    // 获得源操作数选择信号（源操作数也可能来自执行与访存阶段，定向前推）
    wire [1:0] fwrd1 = (cpu_rst_n == `RST_ENABLE) ? 2'b00 :
                       (exe2id_wreg == `WRITE_ENABLE && exe2id_wa == rs && rreg1 == `READ_ENABLE) ? 2'b01 : 
                       (mem2id_wreg == `WRITE_ENABLE && mem2id_wa == rs && rreg1 == `READ_ENABLE) ? 2'b10 : 
                       (rreg1 == `READ_ENABLE) ? 2'b11 : 2'b00;
    wire [1:0] fwrd2 = (cpu_rst_n == `RST_ENABLE) ? 2'b00 :
                       (exe2id_wreg == `WRITE_ENABLE && exe2id_wa == rt && rreg2 == `READ_ENABLE) ? 2'b01 : 
                       (mem2id_wreg == `WRITE_ENABLE && mem2id_wa == rt && rreg2 == `READ_ENABLE) ? 2'b10 : 
                       (rreg2 == `READ_ENABLE) ? 2'b11 : 2'b00;
/***********************消除数据相关添加 end**************************/

    // 获得访存阶段要存入数据存储器的数据（可能来自执行阶段前推的数据、可能来自访存阶段前推的数据、也可能来自通用寄存器堆的读端口2）
    assign id_din_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                       (fwrd2     == 2'b01        ) ? exe2id_wd : 
                       (fwrd2     == 2'b10        ) ? mem2id_wd : 
                       (fwrd2     == 2'b11        ) ? rd2 : `ZERO_WORD;

/***********************消除数据相关修改 begin************************/
    // 获得源操作数1。源操作数1可能是移位位数、可能来自执行阶段前推的数据、可能来自访存阶段前推的数据、也可能来自通用寄存器堆的读端口1
    assign id_src1_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD :
                       (shift     == `SHIFT_ENABLE) ? {27'b0, sa} :
                       (fwrd1     == 2'b01        ) ? exe2id_wd : 
                       (fwrd1     == 2'b10        ) ? mem2id_wd : 
                       (fwrd1     == 2'b11        ) ? rd1 : `ZERO_WORD;

    // 获得源操作数2。源操作数1可能是立即数扩展、可能来自执行阶段前推的数据、可能来自访存阶段前推的数据、也可能来自通用寄存器堆的读端口2
    assign id_src2_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD : 
                       (immsel == `IMM_ENABLE     ) ? imm_ext : 
                       (fwrd2     == 2'b01        ) ? exe2id_wd : 
                       (fwrd2     == 2'b10        ) ? mem2id_wd : 
                       (fwrd2     == 2'b11        ) ? rd2 : `ZERO_WORD;
/***********************消除数据相关修改 end**************************/

/*********************** 转移指令添加 begin*******************************/
    // 生成计算转移地址所需信号
    wire [`INST_ADDR_BUS] pc_plus_8   = pc_plus_4 + 4;
    wire [`JUMP_BUS     ] instr_index = id_inst[25:0];
    wire [`INST_ADDR_BUS] imm_jump    = {{14{imm[15]}}, imm, 2'b00};
    // 获得转移地址
    assign jump_addr_1 = {pc_plus_4[31:28], instr_index, 2'b00};
    assign jump_addr_2 = pc_plus_4 + imm_jump;
    assign jump_addr_3 = id_src1_o;
    assign ret_addr    = pc_plus_8;
    // 获得转移控制信号
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
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
    // 译码阶段暂停信号，解决加载相关
    // 如果当前处于执行阶段的指令是加载指令，并且与处于译码阶段指令存在数据相关，则这种数据相关属于加载相关
    // 如果当前处于访存阶段的指令是加载指令，并且与处于译码阶段指令存在数据相关，则这种数据相关也属于加载相关
    assign stallreq_id = (cpu_rst_n == `RST_ENABLE) ? `NOSTOP :
                         ((fwrd1 == 2'b01 || fwrd2 == 2'b01) && (exe2id_mreg == `TRUE_V)) ? `STOP :
                         ((fwrd1 == 2'b10 || fwrd2 == 2'b10) && (mem2id_mreg == `TRUE_V)) ? `STOP : `NOSTOP;
/************************流水线暂停 end***********************************/
/************************异常处理 begin*******************************/
    // 判断下一条指令是否为延迟槽指令
    assign next_delay_o = (cpu_rst_n == `RST_ENABLE) ? `FALSE_V : 
                          (inst_j | inst_jr | inst_jal | inst_beq | inst_bne | inst_jalr |
                          inst_blez | inst_bgez | inst_bltz | inst_bgtz | inst_bgezal | inst_bltzal);
    // 判断当前处于译码阶段指令是否存在异常，并设置相应的异常类型编码
    assign id_exccode_o = (cpu_rst_n == `RST_ENABLE) ? `EXC_NONE : 
                       (id_exccode_i != `EXC_NONE  ) ? id_exccode_i :
                       (inst_break == `TRUE_V   ) ? `EXC_BREAK : 
					   (inst_syscall == `TRUE_V ) ? `EXC_SYS : 
                       (inst_eret == `TRUE_V    ) ? `EXC_ERET : 
                       (inst_invalid == `TRUE_V ) ? `EXC_RI : `EXC_NONE;
    assign id_badvaddr_o = (cpu_rst_n == `RST_ENABLE  ) ? `ZERO_WORD : id_badvaddr_i;
/************************异常处理 end*********************************/
/************************MFC0,MTC0 begin*******************************/
    assign cp0_addr = (cpu_rst_n == `RST_ENABLE) ? `REG_NOP : rd;       // 获得CP0寄存器的访问地址
/************************MFC0,MTC0 end*********************************/
endmodule
