module dma_engine #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] cmd_in,
    output reg                   done,
    output reg  [DATA_WIDTH-1:0] result,

    // Simulation-level memory interface.
    output reg  [DATA_WIDTH-1:0] mem_addr,
    output reg  [DATA_WIDTH-1:0] mem_wdata,
    output reg                   mem_wen,
    input  wire [DATA_WIDTH-1:0] mem_rdata
);

    localparam IDLE = 1'b0, XFER = 1'b1;
    reg state;
    reg [3:0] delay_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= IDLE;
            done      <= 1'b0;
            result    <= {DATA_WIDTH{1'b0}};
            mem_addr  <= {DATA_WIDTH{1'b0}};
            mem_wdata <= {DATA_WIDTH{1'b0}};
            mem_wen   <= 1'b0;
            delay_cnt <= 4'd0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mem_wen <= 1'b0;
                    if (start) begin
                        mem_addr  <= cmd_in[27:0];
                        mem_wdata <= cmd_in;
                        mem_wen   <= (cmd_in[31:28] == 4'h2);
                        delay_cnt <= 4'd3;
                        state     <= XFER;
                    end
                end

                XFER: begin
                    mem_wen <= 1'b0;
                    if (delay_cnt > 0) begin
                        delay_cnt <= delay_cnt - 1'b1;
                    end else begin
                        result <= mem_rdata;
                        done   <= 1'b1;
                        state  <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
