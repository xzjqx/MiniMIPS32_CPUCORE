`include "defines.v"

module wb_stage(
    input  wire                   cpu_rst_n,
    // 从访存阶段获得的信息
    input  wire                   wb_mreg_i,
    input  wire [`BSEL_BUS      ] wb_dre_i,
	input  wire [`REG_ADDR_BUS  ] wb_wa_i,
	input  wire                   wb_wreg_i,
	input  wire [`REG_BUS       ] wb_dreg_i,
    input  wire                   wb_whilo_i,
	input  wire [`DOUBLE_REG_BUS] wb_hilo_i,

/************************UPDATE--地址用于判断是否为外部设备*******************************/
    input  wire [`INST_ADDR_BUS ] daddr,
    // 从MEM/WB寄存器传来的的数据
    input  wire [`WORD_BUS      ] dm,
/************************UPDATE--地址用于判断是否为外部设备*******************************/
    // 写回目的寄存器的数据
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
/************************有无符号加载存储器 begin*******************************/
    input  wire                     sign,
/************************有无符号加载存储器 end*********************************/
    input  wire                     stallreq_mem,
    input  wire 				    flush
    );

    assign wb_wa_o      = (cpu_rst_n == `RST_ENABLE) ? 5'b0 : wb_wa_i;
    assign wb_wreg_o    = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : wb_wreg_i;
    assign wb_whilo_o   = (cpu_rst_n == `RST_ENABLE) ? 1'b0 : wb_whilo_i;
    assign wb_hilo_o    = (cpu_rst_n == `RST_ENABLE) ? 64'b0 : wb_hilo_i;
/************************MFC0,MTC0 begin*******************************/
    // 直接送至CP0协处理器的信号
	assign cp0_we_o     = (cpu_rst_n == `RST_ENABLE) ? 1'b0  : cp0_we_i;
	assign cp0_waddr_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_waddr_i;
	assign cp0_wdata_o  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD  : cp0_wdata_i;
/************************MFC0,MTC0 end*********************************/

    wire [`WORD_BUS] data  = (cpu_rst_n == `RST_ENABLE) ? `ZERO_WORD : 
                             (|wb_dre_i == 1'b0       ) ? `ZERO_WORD :
/************************UPDATE--若访问外部设备，不需要倒置dm*******************************/
                             (daddr[31:28] != 4'h8 && daddr[31:28] != 4'h0 && daddr[31:20] != 12'hbfc) ? dm :
/************************UPDATE--若访问外部设备，不需要倒置dm*******************************/
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
