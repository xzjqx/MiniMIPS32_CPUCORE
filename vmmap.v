`include "defines.v"

module vmmap(
    input  wire [`DATA_ADDR_BUS	] i_addr,
    output wire [`DATA_ADDR_BUS	] o_addr
    );
    assign o_addr = {3'b000, i_addr[28:0]};
endmodule
