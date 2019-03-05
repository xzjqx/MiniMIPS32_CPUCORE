`include "defines.v"

module scu(
    input  wire              cpu_rst_n,

/************************UPDATE--���ȡָ��ͣ�ź�*******************************/
    input  wire              stallreq_if,
/************************UPDATE--���ȡָ��ͣ�ź�*******************************/
    input  wire              stallreq_id,
    input  wire              stallreq_exe,
/************************UPDATE--��ӷô���ͣ�ź�*******************************/
    input  wire              stallreq_mem,
/************************UPDATE--��ӷô���ͣ�ź�*******************************/

    output wire [`STALL_BUS] stall
    );

/************************UPDATE--�޸������ȡָ�ͷô���ͣ*******************************/
    assign stall = (cpu_rst_n == `RST_ENABLE) ? 6'b000000 :
                   (stallreq_mem == `STOP   ) ? 6'b011111 :
                   (stallreq_exe == `STOP   ) ? 6'b001111 :
                   (stallreq_id  == `STOP   ) ? 6'b000111 :
                   (stallreq_if  == `STOP   ) ? 6'b000111 : 6'b000000;
/************************UPDATE--�޸������ȡָ�ͷô���ͣ*******************************/

endmodule
