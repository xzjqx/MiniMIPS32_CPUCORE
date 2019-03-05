`include "defines.v"

module scu(
    input  wire              cpu_rst_n,

/************************UPDATE--添加取指暂停信号*******************************/
    input  wire              stallreq_if,
/************************UPDATE--添加取指暂停信号*******************************/
    input  wire              stallreq_id,
    input  wire              stallreq_exe,
/************************UPDATE--添加访存暂停信号*******************************/
    input  wire              stallreq_mem,
/************************UPDATE--添加访存暂停信号*******************************/

    output wire [`STALL_BUS] stall
    );

/************************UPDATE--修改以添加取指和访存暂停*******************************/
    assign stall = (cpu_rst_n == `RST_ENABLE) ? 6'b000000 :
                   (stallreq_mem == `STOP   ) ? 6'b011111 :
                   (stallreq_exe == `STOP   ) ? 6'b001111 :
                   (stallreq_id  == `STOP   ) ? 6'b000111 :
                   (stallreq_if  == `STOP   ) ? 6'b000111 : 6'b000000;
/************************UPDATE--修改以添加取指和访存暂停*******************************/

endmodule
