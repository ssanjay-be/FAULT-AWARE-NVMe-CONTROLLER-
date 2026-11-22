module fault_unit #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Command entering the controller.
    input  wire                  cmd_valid,
    input  wire [DATA_WIDTH-1:0] cmd_in,
    input  wire [7:0]            crc_expected,
    output wire                  cmd_integrity_ok,
    output wire                  ingress_fault,

    // Active command verification.
    input  wire                  active_valid,
    input  wire [DATA_WIDTH-1:0] active_cmd,
    input  wire [7:0]            active_crc,
    input  wire [DATA_WIDTH-1:0] shadow_cmd,
    output wire                  active_fault,
    output wire [DATA_WIDTH-1:0] fault_replay_cmd,

    // Registered fault indication used by the queue manager.
    output reg                   fault_detected,
    input  wire                  fault_ack
);

    // CRC-8 with polynomial x^8 + x^2 + x + 1 (0x07).
    function [7:0] crc8;
        input [DATA_WIDTH-1:0] data;
        integer i;
        reg [7:0] c;
        reg fb;
        begin
            c = 8'h00;
            for (i = DATA_WIDTH-1; i >= 0; i = i - 1) begin
                fb = c[7] ^ data[i];
                c  = c << 1;
                if (fb)
                    c = c ^ 8'h07;
            end
            crc8 = c;
        end
    endfunction

    wire [7:0] ingress_crc_calc = crc8(cmd_in);
    wire [7:0] active_crc_calc  = crc8(active_cmd);

    assign cmd_integrity_ok = cmd_valid && (ingress_crc_calc == crc_expected);
    assign ingress_fault    = cmd_valid && (ingress_crc_calc != crc_expected);

    // A mismatch indicates active-command corruption after acceptance.
    assign active_fault     = active_valid && (active_crc_calc != active_crc);
    assign fault_replay_cmd = shadow_cmd;

    always @(posedge clk) begin
        if (!rst_n) begin
            fault_detected <= 1'b0;
        end else begin
            if (fault_ack)
                fault_detected <= 1'b0;
            else if (active_fault)
                fault_detected <= 1'b1;
        end
    end
endmodule
