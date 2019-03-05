`include "defines.v"

module mem_stage (
    input  wire                         cpu_rst_n,

    // 从执行阶段获得的信息
    input  wire [`ALUOP_BUS     ]       mem_aluop_i,
    input  wire [`REG_ADDR_BUS  ]       mem_wa_i,
    input  wire                         mem_wreg_i,
    input  wire [`REG_BUS       ]       mem_wd_i,

    input  wire                         mem_mreg_i,
    input  wire [`REG_BUS       ]       mem_din_i,
    
    input  wire                         mem_whilo_i,
    input  wire [`DOUBLE_REG_BUS]       mem_hilo_i,
    
    // 送至写回阶段的信息
    output wire [`REG_ADDR_BUS  ]       mem_wa_o,
    output wire                         mem_wreg_o,
    output wire [`REG_BUS       ]       mem_dreg_o,

    output wire                         mem_mreg_o,
    output wire [`BSEL_BUS      ]       dre,
    
    output wire                         mem_whilo_o,
    output wire [`DOUBLE_REG_BUS]       mem_hilo_o,

    // 送至数据存储器的信号
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
/************************异常处理 begin*******************************/
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
/************************异常处理 end*********************************/
/************************有无符号加载存储器 begin*******************************/
    output wire                         sign,
/************************有无符号加载存储器 end*********************************/
/************************UPDATE--添加访存阶段暂停*******************************/
/************************流水线暂停 begin*********************************/
    // 访存阶段暂停信号
    output wire                         stallreq_mem,
    input  wire                         mem_data_ok
/************************流水线暂停 end***********************************/
/************************UPDATE--添加访存阶段暂停*******************************/

    );

    // 获得数据存储器的访问地址
    assign daddr = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : mem_wd_i;

    wire [`INST_ADDR_BUS] mem_unaligned_addr = daddr;
    wire word_aligned = mem_unaligned_addr[1:0] == 2'b00;
    wire half_aligned = mem_unaligned_addr[0]   == 1'b0 ;

    // 如果当前不是访存指令，则只需要把从执行阶段获得的信息直接输出
    assign mem_wa_o     = (cpu_rst_n == `RST_ENABLE) ? 5'b0  : mem_wa_i;
    assign mem_wreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_wreg_i;
    assign mem_dreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_wd_i;
    assign mem_whilo_o  = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_whilo_i;
    assign mem_hilo_o   = (cpu_rst_n == `RST_ENABLE) ? 64'b0 : mem_hilo_i;
    assign mem_mreg_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_mreg_i;
/************************MFC0,MTC0 begin*******************************/
    // 直接送至写回阶段的信号
	assign cp0_we_o     = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : cp0_we_i;
	assign cp0_waddr_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_waddr_i;
	assign cp0_wdata_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_wdata_i;
/************************MFC0,MTC0 end*********************************/
/************************异常处理 begin*******************************/
    // CP0中status寄存器和cause寄存器的最新值
    wire [`WORD_BUS] status;
    wire [`WORD_BUS] cause;

    // 判断是否存在针对CP0中寄存器的数据相关，并获得CP0中寄存器的最新值
    assign status = (wb2mem_cp0_we == `WRITE_ENABLE && wb2mem_cp0_wa == `CP0_STATUS) ? wb2mem_cp0_wd : cp0_status;
    assign cause = (wb2mem_cp0_we == `WRITE_ENABLE && wb2mem_cp0_wa == `CP0_CAUSE) ? wb2mem_cp0_wd : cp0_cause;

    // 生成输入到CP0协处理器的信号
    assign cp0_in_delay = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : mem_in_delay_i;
/************************UPDATE--修改复位时exccode应该为`EXC_NONE的bug，添加软中断的判断*******************************/
    assign cp0_exccode = (cpu_rst_n == `RST_ENABLE) ? `EXC_NONE : 
                          ((status[15:8] & cause[15:8]) != 8'h00 && status[1] == 1'b0 && status[0] == 1'b1) ? `EXC_INT : 
/************************UPDATE--修改复位时exccode应该为`EXC_NONE的bug，添加软中断的判断*******************************/
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
/************************异常处理 end*********************************/

    // 确定当前的访存指令
    wire inst_lb = (mem_aluop_i == 8'h90);
    wire inst_lw = (mem_aluop_i == 8'h92);
    wire inst_sb = (mem_aluop_i == 8'h98);
    wire inst_sw = (mem_aluop_i == 8'h9A);
    wire inst_lh = (mem_aluop_i == 8'h91);
    wire inst_lbu= (mem_aluop_i == 8'h94);
    wire inst_lhu= (mem_aluop_i == 8'h95);
    wire inst_sh = (mem_aluop_i == 8'h99);

/************************有无符号加载存储器 begin*******************************/
    assign sign   = inst_lb | inst_lw | inst_lh;
/************************有无符号加载存储器 end*********************************/

    // 获得数据存储器读字节使能信号
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

    // 获得数据存储器使能信号
    assign dce   = (cpu_rst_n == `RST_ENABLE || cp0_exccode != `EXC_NONE || mem_data_ok == 1'b1) ? 1'b0 : 
                   (inst_lb | inst_lw | inst_sb | inst_sw | inst_lbu | inst_lh | inst_lhu | inst_sh);

    // 获得访存阶段暂停信号
    assign stallreq_mem = dce;
    
    // 获得数据存储器写字节使能信号
    assign we[3] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b00)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b00)));
    assign we[2] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b01)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b00)));
    assign we[1] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b10)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b10)));
    assign we[0] = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : 
                   ((inst_sb & (daddr[1 : 0] == 2'b11)) | inst_sw | (inst_sh & (daddr[1 : 0] == 2'b10)));
                   
    // 确定待写入数据存储器的数据
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
