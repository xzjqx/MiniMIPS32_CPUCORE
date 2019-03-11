`include "defines.v"

module MiniMIPS32(
    input  wire                  cpu_clk_50M,
    input  wire                  cpu_rst_n,
    
    // inst_rom
    output wire [`INST_ADDR_BUS] iaddr,
    output wire                  ice,
    input  wire [`INST_BUS]      inst,
    
    // data_ram
    output wire                  dce,
    output wire [`INST_ADDR_BUS] daddr,
    output wire [`BSEL_BUS     ] we,
    output wire [`INST_BUS     ] din,
    input  wire [`INST_BUS     ] dm,

/************************UPDATE--添加取指令和取数据的OK信号*******************************/
    input  wire                  if_data_ok,
    input  wire                  mem_data_ok,
/************************UPDATE--添加取指令和取数据的OK信号*******************************/

    input  wire [`CP0_INT_BUS  ] int_i
    );

    wire [`WORD_BUS      ] pc;

    // 连接IF/ID模块与译码阶段ID模块的变量 
    wire [`WORD_BUS      ] id_pc_i;
    
    // 连接译码阶段ID模块与通用寄存器Regfile模块的变量 
    wire                   re1;
    wire [`REG_ADDR_BUS  ] ra1;
    wire [`REG_BUS       ] rd1;
    wire                   re2;
    wire [`REG_ADDR_BUS  ] ra2;
    wire [`REG_BUS       ] rd2;
/*********************** 转移指令添加 begin*******************************/
    wire [`WORD_BUS      ] jump_addr_1;
    wire [`WORD_BUS      ] jump_addr_2;
    wire [`WORD_BUS      ] jump_addr_3;
    wire [`JTSEL_BUS     ] jtsel;
    wire [`INST_ADDR_BUS ] if_pc_plus_4;
    wire [`INST_ADDR_BUS ] id_pc_plus_4;
/*********************** 转移指令添加 end*********************************/

    wire [`ALUOP_BUS     ] id_aluop_o;
    wire [`ALUTYPE_BUS   ] id_alutype_o;
    wire [`REG_BUS       ] id_src1_o;
    wire [`REG_BUS       ] id_src2_o;
    wire                   id_wreg_o;
    wire [`REG_ADDR_BUS  ] id_wa_o;
    wire                   id_whilo_o;
    wire                   id_mreg_o;
    wire [`REG_BUS         ] id_din_o;
    wire [`ALUOP_BUS     ] exe_aluop_i;
    wire [`ALUTYPE_BUS   ] exe_alutype_i;
    wire [`REG_BUS       ] exe_src1_i;
    wire [`REG_BUS       ] exe_src2_i;
    wire                   exe_wreg_i;
    wire [`REG_ADDR_BUS  ] exe_wa_i;
    wire                   exe_whilo_i;
    wire                   exe_mreg_i;
    wire [`REG_BUS       ] exe_din_i;

/*********************** 转移指令添加 begin*******************************/
    wire [`REG_BUS       ] id_ret_addr;
    wire [`REG_BUS       ] exe_ret_addr;
/*********************** 转移指令添加 end*********************************/

    wire [`REG_BUS       ] exe_hi_i;
    wire [`REG_BUS       ] exe_lo_i;
    
    wire [`ALUOP_BUS     ] exe_aluop_o;
    wire                   exe_wreg_o;
    wire [`REG_ADDR_BUS  ] exe_wa_o;
    wire [`REG_BUS       ] exe_wd_o;
    wire                   exe_mreg_o;
    wire [`REG_BUS       ] exe_din_o;
    wire                   exe_whilo_o;
    wire [`DOUBLE_REG_BUS] exe_hilo_o;
    wire [`ALUOP_BUS     ] mem_aluop_i;
    wire                   mem_wreg_i;
    wire [`REG_ADDR_BUS  ] mem_wa_i;
    wire [`REG_BUS       ] mem_wd_i;
    wire                   mem_mreg_i;
    wire [`REG_BUS       ] mem_din_i;
    wire                   mem_whilo_i;
    wire [`DOUBLE_REG_BUS] mem_hilo_i;

    wire                   mem_wreg_o;
    wire [`REG_ADDR_BUS  ] mem_wa_o;
    wire [`REG_BUS       ] mem_dreg_o;
    wire                   mem_mreg_o;
    wire [`BSEL_BUS      ] mem_dre_o;
    wire                   mem_whilo_o;
    wire [`DOUBLE_REG_BUS] mem_hilo_o;
    wire                   wb_wreg_i;
    wire [`REG_ADDR_BUS  ] wb_wa_i;
    wire [`REG_BUS       ] wb_dreg_i;
    wire [`BSEL_BUS      ] wb_dre_i;
    wire                   wb_mreg_i;
    wire                   wb_whilo_i;
    wire [`DOUBLE_REG_BUS] wb_hilo_i;

    wire                   wb_wreg_o;
    wire [`REG_ADDR_BUS  ] wb_wa_o;
    wire [`REG_BUS       ] wb_wd_o;
    wire                   wb_whilo_o;
    wire [`DOUBLE_REG_BUS] wb_hilo_o;
/************************流水线暂停 begin*********************************/
    wire [`STALL_BUS     ] stall;
/************************UPDATE--添加取指暂停信号*******************************/
    wire                   stallreq_if;
/************************UPDATE--添加取指暂停信号*******************************/
    wire                   stallreq_id;
    wire                   stallreq_exe;
/************************UPDATE--添加访存暂停信号*******************************/
    wire                   stallreq_mem;
/************************UPDATE--添加访存暂停信号*******************************/
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
    wire [`REG_ADDR_BUS  ] id_cp0_addr_o;
    wire [`REG_ADDR_BUS  ] exe_cp0_addr_i;
    wire                   cp0_re;
    wire [`REG_ADDR_BUS  ] cp0_raddr;
    wire [`REG_BUS       ] cp0_data_o;

    wire                   exe_cp0_we_o;
    wire [`REG_ADDR_BUS  ] exe_cp0_waddr_o;
    wire [`REG_BUS       ] exe_cp0_wdata_o;
    wire                   mem_cp0_we_i;
    wire [`REG_ADDR_BUS  ] mem_cp0_waddr_i;
    wire [`REG_BUS       ] mem_cp0_wdata_i;
    wire                   mem_cp0_we_o;
    wire [`REG_ADDR_BUS  ] mem_cp0_waddr_o;
    wire [`REG_BUS       ] mem_cp0_wdata_o;
    wire                   wb_cp0_we_i;
    wire [`REG_ADDR_BUS  ] wb_cp0_waddr_i;
    wire [`REG_BUS       ] wb_cp0_wdata_i;
    wire                   cp0_we;
    wire [`REG_ADDR_BUS  ] cp0_waddr;
    wire [`REG_BUS       ] cp0_data_i;

    wire                   cp0_in_delay_i;
    wire [`REG_BUS 	     ] status_o;
    wire [`REG_BUS 	     ] cause_o;
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
    wire [`WORD_BUS      ] id_pc_o;
    wire [`WORD_BUS      ] exe_pc_i;
    wire [`WORD_BUS      ] exe_pc_o;
    wire [`WORD_BUS      ] mem_pc_i;
    wire [`WORD_BUS      ] cp0_pc_i;
    wire                   next_delay;
    wire                   id_in_delay_i;
    wire                   id_in_delay_o;
    wire                   exe_in_delay_i;
    wire                   exe_in_delay_o;
    wire                   mem_in_delay_i;

    wire [`EXC_CODE_BUS  ] if_exccode_i;
    wire [`EXC_CODE_BUS  ] if_exccode_o;
    wire [`EXC_CODE_BUS  ] id_exccode_i;
    wire [`EXC_CODE_BUS  ] id_exccode_o;
    wire [`EXC_CODE_BUS  ] exe_exccode_i;
    wire [`EXC_CODE_BUS  ] exe_exccode_o;
    wire [`EXC_CODE_BUS  ] mem_exccode_i;
    wire [`EXC_CODE_BUS  ] cp0_exccode_i;
    wire [`WORD_BUS      ] cp0_epc_i;
    wire [`WORD_BUS      ] if_badvaddr_i;
    wire [`WORD_BUS      ] if_badvaddr_o;
    wire [`WORD_BUS      ] id_badvaddr_i;
    wire [`WORD_BUS      ] id_badvaddr_o;
    wire [`WORD_BUS      ] exe_badvaddr_i;
    wire [`WORD_BUS      ] exe_badvaddr_o;
    wire [`WORD_BUS      ] mem_badvaddr_i;
    wire [`WORD_BUS      ] cp0_badvaddr_i;

    wire                   flush_o;
    wire [`INST_ADDR_BUS ] cp0_excaddr;
/************************异常处理 end*********************************/
/************************有无符号加载存储器 begin*******************************/
    wire                   mem_sign;
    wire                   wb_sign;
/************************有无符号加载存储器 end*********************************/

/************************UPDATE--修改以添加取指暂停*******************************/
    wire flush_t;
    if_stage if_stage0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .pc(pc), .ice(ice), .iaddr(iaddr),
/*********************** 转移指令添加 begin*******************************/
        .pc_plus_4(if_pc_plus_4),
        .jump_addr_1(jump_addr_1), .jump_addr_2(jump_addr_2), 
        .jump_addr_3(jump_addr_3), .jtsel(jtsel),
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
        .stall(stall), .stallreq_if(stallreq_if), .if_data_ok(if_data_ok),
/************************流水线暂停 end***********************************/
/************************异常处理 begin*******************************/
        .if_exccode_o(if_exccode_o), .if_badvaddr_o(if_badvaddr_o),
	    .flush(flush_o), .flush_t(flush_t), .cp0_excaddr(cp0_excaddr)
/************************异常处理 end*********************************/
    );
/************************UPDATE--修改以添加取指暂停*******************************/
    
/************************UPDATE--修改使指令不再直接传给ID阶段*******************************/
    wire [`WORD_BUS] id_inst;
    ifid_reg ifid_reg0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .if_pc(pc), .id_pc(id_pc_i),
        .if_inst(inst), .id_inst(id_inst),
/*********************** 转移指令添加 begin*******************************/
        .if_pc_plus_4(if_pc_plus_4), .id_pc_plus_4(id_pc_plus_4),
        .if_delay(next_delay), .id_delay(id_in_delay_i),
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
        .stall(stall),
/************************流水线暂停 end***********************************/
/************************异常处理 begin*******************************/
        .if_exccode(if_exccode_o), .id_exccode(id_exccode_i),
        .if_badvaddr(if_badvaddr_o), .id_badvaddr(id_badvaddr_i),
	    .flush(flush_o), .flush_t(flush_t)
/************************异常处理 end*********************************/
    );
/************************UPDATE--修改使指令不再直接传给ID阶段*******************************/

    id_stage id_stage0(.cpu_rst_n(cpu_rst_n), .id_pc_i(id_pc_i), 
/*********************** 转移指令添加 begin*******************************/
        .pc_plus_4(id_pc_plus_4),
/*********************** 转移指令添加 end*********************************/     
/************************UPDATE--修改使指令来自IF/ID寄存器*******************************/   
        .id_inst_i(id_inst),
/************************UPDATE--修改使指令来自IF/ID寄存器*******************************/
        .rd1(rd1), .rd2(rd2),
        .rreg1(re1), .rreg2(re2), 	  
        .ra1(ra1), .ra2(ra2), 
/***********************消除数据相关添加 begin************************/
        .exe2id_wreg(exe_wreg_o), .exe2id_wa(exe_wa_o), .exe2id_wd(exe_wd_o),
        .mem2id_wreg(mem_wreg_o), .mem2id_wa(mem_wa_o), .mem2id_wd(mem_dreg_o),
/***********************消除数据相关添加 end**************************/
        .id_aluop_o(id_aluop_o), .id_alutype_o(id_alutype_o),
        .id_src1_o(id_src1_o), .id_src2_o(id_src2_o),
        .id_wa_o(id_wa_o), .id_wreg_o(id_wreg_o),
        .id_whilo_o(id_whilo_o),
        .id_mreg_o(id_mreg_o), .id_din_o(id_din_o), 
/*********************** 转移指令添加 begin*******************************/
        .jump_addr_1(jump_addr_1), .jump_addr_2(jump_addr_2), 
        .jump_addr_3(jump_addr_3), .jtsel(jtsel), .ret_addr(id_ret_addr),
/*********************** 转移指令添加 end*********************************/       
/************************流水线暂停 begin*********************************/
        .exe2id_mreg(exe_mreg_o), .mem2id_mreg(mem_mreg_o),
        .stallreq_id(stallreq_id),
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
        .cp0_addr(id_cp0_addr_o),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
        .id_in_delay_i(id_in_delay_i), .id_in_delay_o(id_in_delay_o),
        .id_pc_o(id_pc_o), .next_delay_o(next_delay),
        .id_exccode_i(id_exccode_i), .id_exccode_o(id_exccode_o),
        .id_badvaddr_i(id_badvaddr_i), .id_badvaddr_o(id_badvaddr_o)
/************************异常处理 end*********************************/
    );
    
    regfile regfile0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .we(wb_wreg_o), .wa(wb_wa_o), .wd(wb_wd_o),
        .re1(re1), .ra1(ra1), .rd1(rd1),
        .re2(re2), .ra2(ra2), .rd2(rd2)
    );
    
    idexe_reg idexe_reg0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n), 
        .id_alutype(id_alutype_o), .id_aluop(id_aluop_o),
        .id_src1(id_src1_o), .id_src2(id_src2_o),
        .id_wa(id_wa_o), .id_wreg(id_wreg_o), .id_whilo(id_whilo_o),
        .id_mreg(id_mreg_o), .id_din(id_din_o), 
/*********************** 转移指令添加 begin*******************************/
        .id_ret_addr(id_ret_addr),
/*********************** 转移指令添加 end*********************************/   
        .exe_alutype(exe_alutype_i), .exe_aluop(exe_aluop_i),
        .exe_src1(exe_src1_i), .exe_src2(exe_src2_i), 
        .exe_wa(exe_wa_i), .exe_wreg(exe_wreg_i), .exe_whilo(exe_whilo_i),
        .exe_mreg(exe_mreg_i), .exe_din(exe_din_i),
/*********************** 转移指令添加 begin*******************************/
        .exe_ret_addr(exe_ret_addr),
/*********************** 转移指令添加 end*********************************/
/************************流水线暂停 begin*********************************/
        .stall(stall),
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
        .id_cp0_addr(id_cp0_addr_o), .exe_cp0_addr(exe_cp0_addr_i),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
        .id_in_delay(id_in_delay_o), .exe_in_delay(exe_in_delay_i),
        .id_pc(id_pc_o), .exe_pc(exe_pc_i),
        .id_exccode(id_exccode_o), .exe_exccode(exe_exccode_i),
        .id_badvaddr(id_badvaddr_o), .exe_badvaddr(exe_badvaddr_i),
	    .flush(flush_o)
/************************异常处理 end*********************************/
    );

    exe_stage exe_stage0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .exe_alutype_i(exe_alutype_i), .exe_aluop_i(exe_aluop_i),
        .exe_src1_i(exe_src1_i), .exe_src2_i(exe_src2_i),
        .exe_wa_i(exe_wa_i), .exe_wreg_i(exe_wreg_i),
        .exe_mreg_i(exe_mreg_i), .exe_din_i(exe_din_i),
        .hi_i(exe_hi_i), .lo_i(exe_lo_i), .exe_whilo_i(exe_whilo_i),
/***********************消除数据相关添加 begin************************/
        .mem2exe_whilo(mem_whilo_o), .mem2exe_hilo(mem_hilo_o),
        .wb2exe_whilo(wb_whilo_i), .wb2exe_hilo(wb_hilo_i),
/***********************消除数据相关添加 end**************************/
        .exe_aluop_o(exe_aluop_o),
        .exe_wa_o(exe_wa_o), .exe_wreg_o(exe_wreg_o), .exe_wd_o(exe_wd_o),
        .exe_mreg_o(exe_mreg_o), .exe_din_o(exe_din_o),
        .exe_whilo_o(exe_whilo_o), .exe_hilo_o(exe_hilo_o),
/*********************** 转移指令添加 begin*******************************/
        .ret_addr(exe_ret_addr),
/*********************** 转移指令添加 end*********************************/  
/************************流水线暂停 begin*********************************/
        .stallreq_exe(stallreq_exe),      
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
        .cp0_addr_i(exe_cp0_addr_i), .cp0_data_i(cp0_data_o),
        .mem2exe_cp0_we(mem_cp0_we_o), .mem2exe_cp0_wa(mem_cp0_waddr_o), .mem2exe_cp0_wd(mem_cp0_wdata_o),
        .wb2exe_cp0_we(cp0_we), .wb2exe_cp0_wa(cp0_waddr), .wb2exe_cp0_wd(cp0_data_i),
        .cp0_re_o(cp0_re), .cp0_raddr_o(cp0_raddr),
	    .cp0_we_o(exe_cp0_we_o), .cp0_waddr_o(exe_cp0_waddr_o), .cp0_wdata_o(exe_cp0_wdata_o),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
        .exe_pc_i(exe_pc_i), .exe_pc_o(exe_pc_o),
        .exe_in_delay_i(exe_in_delay_i), .exe_in_delay_o(exe_in_delay_o),
        .exe_exccode_i(exe_exccode_i), .exe_exccode_o(exe_exccode_o),
        .exe_badvaddr_i(exe_badvaddr_i), .exe_badvaddr_o(exe_badvaddr_o)
/************************异常处理 end*********************************/
    );

    exemem_reg exemem_reg0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .exe_aluop(exe_aluop_o),
        .exe_wa(exe_wa_o), .exe_wreg(exe_wreg_o), .exe_wd(exe_wd_o),
        .exe_mreg(exe_mreg_o), .exe_din(exe_din_o),
        .exe_whilo(exe_whilo_o), .exe_hilo(exe_hilo_o),
        .mem_aluop(mem_aluop_i),
        .mem_wa(mem_wa_i), .mem_wreg(mem_wreg_i), .mem_wd(mem_wd_i),
        .mem_mreg(mem_mreg_i), .mem_din(mem_din_i),
        .mem_whilo(mem_whilo_i), .mem_hilo(mem_hilo_i),
/************************流水线暂停 begin*********************************/
        .stall(stall),
/************************流水线暂停 end***********************************/
/************************MFC0,MTC0 begin*******************************/
        .exe_cp0_we(exe_cp0_we_o), .exe_cp0_waddr(exe_cp0_waddr_o), .exe_cp0_wdata(exe_cp0_wdata_o),
	    .mem_cp0_we(mem_cp0_we_i), .mem_cp0_waddr(mem_cp0_waddr_i), .mem_cp0_wdata(mem_cp0_wdata_i),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
        .exe_pc(exe_pc_o), .mem_pc(mem_pc_i),
        .exe_in_delay(exe_in_delay_o), .mem_in_delay(mem_in_delay_i),
        .exe_exccode(exe_exccode_o), .mem_exccode(mem_exccode_i),
        .exe_badvaddr(exe_badvaddr_o), .mem_badvaddr(mem_badvaddr_i),
	    .flush(flush_o)
/************************异常处理 end*********************************/
    );

    mem_stage mem_stage0(.cpu_rst_n(cpu_rst_n), .mem_aluop_i(mem_aluop_i),
        .mem_wa_i(mem_wa_i), .mem_wreg_i(mem_wreg_i), .mem_wd_i(mem_wd_i),
        .mem_mreg_i(mem_mreg_i), .mem_din_i(mem_din_i),
        .mem_whilo_i(mem_whilo_i), .mem_hilo_i(mem_hilo_i),
        .mem_wa_o(mem_wa_o), .mem_wreg_o(mem_wreg_o), .mem_dreg_o(mem_dreg_o),
        .mem_mreg_o(mem_mreg_o), .dre(mem_dre_o),
        .mem_whilo_o(mem_whilo_o), .mem_hilo_o(mem_hilo_o),
        .dce(dce), .daddr(daddr), .we(we), .din(din),
/************************MFC0,MTC0 begin*******************************/
	    .cp0_we_i(mem_cp0_we_i), .cp0_waddr_i(mem_cp0_waddr_i), .cp0_wdata_i(mem_cp0_wdata_i),
        .cp0_we_o(mem_cp0_we_o), .cp0_waddr_o(mem_cp0_waddr_o), .cp0_wdata_o(mem_cp0_wdata_o),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
        .wb2mem_cp0_we(cp0_we), .wb2mem_cp0_wa(cp0_waddr), .wb2mem_cp0_wd(cp0_data_i),
        .mem_pc_i(mem_pc_i), .cp0_pc(cp0_pc_i),
        .mem_in_delay_i(mem_in_delay_i), .cp0_in_delay(cp0_in_delay_i),
        .mem_exccode_i(mem_exccode_i), .cp0_exccode(cp0_exccode_i),
        .mem_badvaddr_i(mem_badvaddr_i), .cp0_badvaddr(cp0_badvaddr_i),
        .cp0_status(status_o), .cp0_cause(cause_o),
/************************异常处理 end*********************************/
/************************有无符号加载存储器 begin*******************************/
        .sign(mem_sign),
/************************有无符号加载存储器 end*********************************/
/************************UPDATE--添加访存阶段暂停*******************************/
/************************流水线暂停 begin*********************************/
        .stallreq_mem(stallreq_mem), .mem_data_ok(mem_data_ok)
/************************流水线暂停 end***********************************/
/************************UPDATE--添加访存阶段暂停*******************************/
    );

    cp0_reg cp0_reg0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n), 
        .we(cp0_we), 
        .raddr(cp0_raddr),
        .waddr(cp0_waddr), 
        .wdata(cp0_data_i), 
        .int_i(int_i), 
        .exccode_i(cp0_exccode_i), 
        .exc_badvaddr_i(cp0_badvaddr_i), 
        .flush(flush_o), 
        .cp0_excaddr(cp0_excaddr), 
        .data_o(cp0_data_o), 
        .status_o(status_o), 
        .cause_o(cause_o), 
        .re(cp0_re),
        .pc_i(cp0_pc_i),
        .in_delay_i(cp0_in_delay_i)
    );

/************************UPDATE--修改使数据不再直接传给WB阶段*******************************/
    wire [`INST_ADDR_BUS] wb_daddr;
    wire [`REG_BUS      ] wb_dm;
    memwb_reg memwb_reg0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n),
        .mem_wa(mem_wa_o), .mem_wreg(mem_wreg_o), .mem_dreg(mem_dreg_o),
        .mem_mreg(mem_mreg_o), .mem_dre(mem_dre_o), .mem_daddr(daddr),
        .mem_dm(dm),
        .mem_whilo(mem_whilo_o), .mem_hilo(mem_hilo_o),
/************************流水线暂停 begin*********************************/
        .stall(stall),
/************************流水线暂停 end***********************************/
        .wb_wa(wb_wa_i), .wb_wreg(wb_wreg_i), .wb_dreg(wb_dreg_i),
        .wb_mreg(wb_mreg_i), .wb_dre(wb_dre_i), .wb_daddr(wb_daddr),
        .wb_dm(wb_dm),
        .wb_whilo(wb_whilo_i), .wb_hilo(wb_hilo_i),
/************************MFC0,MTC0 begin*******************************/
	    .mem_cp0_we(mem_cp0_we_o), .mem_cp0_waddr(mem_cp0_waddr_o), .mem_cp0_wdata(mem_cp0_wdata_o),
        .wb_cp0_we(wb_cp0_we_i), .wb_cp0_waddr(wb_cp0_waddr_i), .wb_cp0_wdata(wb_cp0_wdata_i),
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
	    .flush(flush_o),
/************************异常处理 end*********************************/
/************************有无符号加载存储器 begin*******************************/
        .mem_sign(mem_sign), .wb_sign(wb_sign)
/************************有无符号加载存储器 end*********************************/
    );
/************************UPDATE--修改使数据不再直接传给WB阶段*******************************/

    wb_stage wb_stage0(.cpu_rst_n(cpu_rst_n),
        .wb_mreg_i(wb_mreg_i), .wb_dre_i(wb_dre_i), 
        .wb_wa_i(wb_wa_i), .wb_wreg_i(wb_wreg_i), .wb_dreg_i(wb_dreg_i), 
        .wb_whilo_i(wb_whilo_i), .wb_hilo_i(wb_hilo_i),
/************************UPDATE--修改使数据来自MEM/WB寄存器*******************************/
        .daddr(wb_daddr), .dm(wb_dm),
/************************UPDATE--修改使数据来自MEM/WB寄存器*******************************/
        .wb_wa_o(wb_wa_o), .wb_wreg_o(wb_wreg_o), .wb_wd_o(wb_wd_o), 
        .wb_whilo_o(wb_whilo_o), .wb_hilo_o(wb_hilo_o),
/************************MFC0,MTC0 begin*******************************/
        .cp0_we_i(wb_cp0_we_i), .cp0_waddr_i(wb_cp0_waddr_i), .cp0_wdata_i(wb_cp0_wdata_i),
        .cp0_we_o(cp0_we), .cp0_waddr_o(cp0_waddr), .cp0_wdata_o(cp0_data_i),
/************************MFC0,MTC0 end*********************************/
/************************有无符号加载存储器 begin*******************************/
        .sign(wb_sign),
/************************有无符号加载存储器 end*********************************/
/************************UPDATE--添加访存阶段暂停*******************************/
        .stallreq_mem(stallreq_mem), .flush(flush_o)
/************************UPDATE--添加访存阶段暂停*******************************/
    );

    hilo hilo0(.cpu_clk_50M(cpu_clk_50M), .cpu_rst_n(cpu_rst_n), 
        .we(wb_whilo_o),
        .hi_i(wb_hilo_o[63:32]), .lo_i(wb_hilo_o[31:0]),
        .hi_o(exe_hi_i), .lo_o(exe_lo_i)
    );
/************************流水线暂停，异常处理 begin*********************************/
    scu scu0(.cpu_rst_n(cpu_rst_n), 
/************************UPDATE--添加取指和访存阶段暂停*******************************/
        .stallreq_if(stallreq_if),
        .stallreq_id(stallreq_id), .stallreq_exe(stallreq_exe), .stallreq_mem(stallreq_mem),
/************************UPDATE--添加取指和访存阶段暂停*******************************/
        .stall(stall)
    );
/************************流水线暂停，异常处理 end***********************************/
endmodule
