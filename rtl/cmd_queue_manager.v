module cmd_queue_manager #(
    parameter DATA_WIDTH = 32,
    parameter QDEPTH     = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Host submission interface
    input  wire                  sub_valid,
    input  wire [DATA_WIDTH-1:0] sub_cmd,
    input  wire [7:0]            sub_crc,
    input  wire                  sub_integrity_ok,
    output reg                   sub_ready,

    // Completion interface
    output reg                   comp_valid,
    output reg  [DATA_WIDTH-1:0] comp_data,
    input  wire                  comp_ready,

    // DMA engine
    output reg                   dma_start,
    output reg  [DATA_WIDTH-1:0] dma_cmd,
    input  wire                  dma_done,
    input  wire [DATA_WIDTH-1:0] dma_result,

    // Fault/recovery interface
    input  wire                  fault_detected,
    input  wire                  active_fault,
    input  wire [DATA_WIDTH-1:0] fault_replay_cmd,
    output reg                   fault_ack,

    // Simulation-only SEU injection control.
    input  wire                  fault_inject,
    input  wire [DATA_WIDTH-1:0] fault_mask,

    // Active command presented to the fault unit.
    output reg                   active_valid,
    output reg  [DATA_WIDTH-1:0] active_cmd,
    output reg  [7:0]            active_crc,
    output reg  [DATA_WIDTH-1:0] shadow_cmd
);

    reg [DATA_WIDTH-1:0] sq_cmd [0:QDEPTH-1];
    reg [7:0]            sq_crc [0:QDEPTH-1];
    reg [2:0] sq_head, sq_tail;
    reg [3:0] sq_count;

    localparam IDLE      = 3'd0;
    localparam CHECK     = 3'd1;
    localparam WAIT_DMA  = 3'd2;
    localparam COMPLETE  = 3'd3;
    localparam RECOVER   = 3'd4;

    reg [2:0] state;
    reg injection_consumed;
    integer i;

    wire enqueue_cmd = sub_valid && sub_ready && sub_integrity_ok && (sq_count < QDEPTH);
    wire issue_cmd   = (state == IDLE) && (sq_count > 0);

    always @(posedge clk) begin
        if (!rst_n) begin
            sq_head            <= 3'd0;
            sq_tail            <= 3'd0;
            sq_count           <= 4'd0;
            sub_ready          <= 1'b1;
            state              <= IDLE;
            dma_start           <= 1'b0;
            dma_cmd             <= {DATA_WIDTH{1'b0}};
            comp_valid          <= 1'b0;
            comp_data           <= {DATA_WIDTH{1'b0}};
            fault_ack           <= 1'b0;
            active_valid        <= 1'b0;
            active_cmd          <= {DATA_WIDTH{1'b0}};
            active_crc          <= 8'h00;
            shadow_cmd          <= {DATA_WIDTH{1'b0}};
            injection_consumed  <= 1'b0;
            for (i = 0; i < QDEPTH; i = i + 1) begin
                sq_cmd[i] <= {DATA_WIDTH{1'b0}};
                sq_crc[i] <= 8'h00;
            end
        end else begin
            dma_start <= 1'b0;
            fault_ack <= 1'b0;

            // Only commands that pass ingress integrity are queued.
            if (enqueue_cmd) begin
                sq_cmd[sq_tail] <= sub_cmd;
                sq_crc[sq_tail] <= sub_crc;
                sq_tail <= sq_tail + 1'b1;
            end

            // Maintain queue count for simultaneous enqueue/dequeue.
            case ({enqueue_cmd, issue_cmd})
                2'b10: sq_count <= sq_count + 1'b1;
                2'b01: sq_count <= sq_count - 1'b1;
                default: sq_count <= sq_count;
            endcase

            sub_ready <= (sq_count < QDEPTH);

            case (state)
                IDLE: begin
                    active_valid <= 1'b0;
                    injection_consumed <= 1'b0;

                    if (sq_count > 0) begin
                        active_cmd   <= sq_cmd[sq_head];
                        active_crc   <= sq_crc[sq_head];
                        shadow_cmd   <= sq_cmd[sq_head];
                        active_valid <= 1'b1;
                        sq_head      <= sq_head + 1'b1;
                        state        <= CHECK;
                    end
                end

                CHECK: begin
                    active_valid <= 1'b1;

                    // Inject simulated corruption before integrity verification.
                    if (fault_inject && !injection_consumed) begin
                        active_cmd <= active_cmd ^ fault_mask;
                        injection_consumed <= 1'b1;
                    end
                    // Replay the shadow command if active integrity fails.
                    else if (active_fault || fault_detected) begin
                        active_cmd <= fault_replay_cmd;
                        dma_cmd    <= fault_replay_cmd;
                        dma_start  <= 1'b1;
                        fault_ack  <= 1'b1;
                        state      <= WAIT_DMA;
                    end
                    // No detected fault: execute the active command.
                    else begin
                        dma_cmd   <= active_cmd;
                        dma_start <= 1'b1;
                        state     <= WAIT_DMA;
                    end
                end

                WAIT_DMA: begin
                    active_valid <= 1'b0;
                    if (dma_done) begin
                        comp_data  <= dma_result;
                        comp_valid <= 1'b1;
                        state      <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    if (comp_valid && comp_ready) begin
                        comp_valid <= 1'b0;
                        state      <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
