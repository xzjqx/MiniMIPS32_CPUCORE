`include "defines.v"

module exemem_reg (
    input  wire 				cpu_clk_50M,
    input  wire 				cpu_rst_n,

    // ����ִ�н׶ε���Ϣ
    input  wire [`ALUOP_BUS   ] exe_aluop,
    input  wire [`REG_ADDR_BUS] exe_wa,
    input  wire                 exe_wreg,
    input  wire [`REG_BUS 	  ] exe_wd,
    input  wire                 exe_mreg,
    input  wire [`REG_BUS 	  ] exe_din,
    
    input  wire                 exe_whilo,
    input  wire [`DOUBLE_REG_BUS] exe_hilo,
    
    // �͵��ô�׶ε���Ϣ 
    output reg  [`ALUOP_BUS   ] mem_aluop,
    output reg  [`REG_ADDR_BUS] mem_wa,
    output reg                  mem_wreg,
    output reg  [`REG_BUS 	  ] mem_wd,
    output reg                  mem_mreg,
    output reg  [`REG_BUS 	  ] mem_din,
    
    output reg 					mem_whilo,
    output reg  [`DOUBLE_REG_BUS] mem_hilo,
/************************��ˮ����ͣ begin*********************************/
    input  wire [`STALL_BUS   ] stall,
/************************��ˮ����ͣ end***********************************/
/************************MFC0,MTC0 begin*******************************/
    input  wire                   exe_cp0_we,
    input  wire [`REG_ADDR_BUS  ] exe_cp0_waddr,
    input  wire [`REG_BUS       ] exe_cp0_wdata,

	output reg                    mem_cp0_we,
	output reg  [`REG_ADDR_BUS  ] mem_cp0_waddr,
	output reg  [`REG_BUS       ] mem_cp0_wdata,
/************************MFC0,MTC0 end*********************************/
/************************�쳣���� begin*******************************/
    input  wire                 flush,
    input  wire [`INST_ADDR_BUS ] exe_pc,
    output reg  [`INST_ADDR_BUS ] mem_pc,
    input  wire                   exe_in_delay,
    output reg                    mem_in_delay,

    input  wire [`EXC_CODE_BUS] exe_exccode,
    output reg  [`EXC_CODE_BUS] mem_exccode,
    input  wire [`WORD_BUS    ] exe_badvaddr,
    output reg  [`WORD_BUS    ] mem_badvaddr
/************************�쳣���� end*********************************/
    );

    always @(posedge cpu_clk_50M) begin
/************************�쳣���� begin*******************************/
    if (cpu_rst_n == `RST_ENABLE || flush) begin
/************************�쳣���� end*********************************/
        mem_aluop              <= `MINIMIPS32_SLL;
        mem_wa 				   <= `REG_NOP;
        mem_wreg   			   <= `WRITE_DISABLE;
        mem_wd   			   <= `ZERO_WORD;
        mem_mreg  			   <= `WRITE_DISABLE;
        mem_din   			   <= `ZERO_WORD;
        mem_whilo 			   <= `WRITE_DISABLE;
        mem_hilo 		       <= `ZERO_DWORD;
/************************�쳣���� begin*******************************/
        mem_pc                 <= `PC_INIT;
        mem_in_delay           <= `FALSE_V;
        mem_exccode            <= `EXC_NONE;
        mem_badvaddr           <= `ZERO_WORD;
/************************�쳣���� end*********************************/
/************************MFC0,MTC0 begin*******************************/
	    mem_cp0_we             <= `FALSE_V;
	    mem_cp0_waddr          <= `ZERO_WORD;
	    mem_cp0_wdata          <= `ZERO_WORD;
/************************MFC0,MTC0 end*********************************/
    end
/************************��ˮ����ͣ begin*********************************/
/************************UPDATE--��Ӷ�stall[4]���ж�*******************************/
    else if(stall[3] == `STOP  && stall[4] == `NOSTOP) begin
/************************UPDATE--��Ӷ�stall[4]���ж�*******************************/
/************************�쳣���� end*********************************/
        mem_aluop              <= `MINIMIPS32_SLL;
        mem_wa 				   <= `REG_NOP;
        mem_wreg   			   <= `WRITE_DISABLE;
        mem_wd   			   <= `ZERO_WORD;
        mem_mreg  			   <= `WRITE_DISABLE;
        mem_din   			   <= `ZERO_WORD;
        mem_whilo 			   <= `WRITE_DISABLE;
        mem_hilo 		       <= `ZERO_DWORD;
/************************�쳣���� begin*******************************/
        mem_pc                 <= `PC_INIT;
        mem_in_delay           <= `FALSE_V;
        mem_exccode            <= `EXC_NONE;
        mem_badvaddr           <= `ZERO_WORD;
/************************�쳣���� end*********************************/
/************************MFC0,MTC0 begin*******************************/
	    mem_cp0_we             <= `FALSE_V;
	    mem_cp0_waddr          <= `ZERO_WORD;
	    mem_cp0_wdata          <= `ZERO_WORD;
/************************MFC0,MTC0 end*********************************/
    end
/************************��ˮ����ͣ end***********************************/
    else if(stall[3] == `NOSTOP) begin
        mem_aluop              <= exe_aluop;
        mem_wa 				   <= exe_wa;
        mem_wreg 			   <= exe_wreg;
        mem_wd 		    	   <= exe_wd;
        mem_mreg  			   <= exe_mreg;
        mem_din   			   <= exe_din;
        mem_whilo 			   <= exe_whilo;
        mem_hilo 		       <= exe_hilo;
/************************�쳣���� begin*******************************/
        mem_pc                 <= exe_pc;
        mem_in_delay           <= exe_in_delay;
        mem_exccode            <= exe_exccode;
        mem_badvaddr           <= exe_badvaddr;
/************************�쳣���� end*********************************/
/************************MFC0,MTC0 begin*******************************/
	    mem_cp0_we             <= exe_cp0_we;
	    mem_cp0_waddr          <= exe_cp0_waddr;
	    mem_cp0_wdata          <= exe_cp0_wdata;
/************************MFC0,MTC0 end*********************************/
    end
  end

endmodule
