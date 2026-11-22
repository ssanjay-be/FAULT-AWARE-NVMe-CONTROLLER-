module top_controller #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  sub_valid,
    input  wire [DATA_WIDTH-1:0] sub_cmd,
    input  wire [7:0]            sub_crc,
    output wire                  sub_ready,
    output wire                  comp_valid,
    output wire [DATA_WIDTH-1:0] comp_data,
    input  wire                  comp_ready,

    // Simulation-only fault-injection controls.
    input  wire                  fault_inject,
    input  wire [DATA_WIDTH-1:0] fault_mask
);

    wire dma_start, dma_done;
    wire [DATA_WIDTH-1:0] dma_cmd, dma_result;
    wire [DATA_WIDTH-1:0] mem_addr, mem_wdata, mem_rdata;
    wire mem_wen;

    wire fault_detected, fault_ack;
    wire [DATA_WIDTH-1:0] fault_replay_cmd;
    wire cmd_integrity_ok, ingress_fault;

    wire active_valid;
    wire active_fault;
    wire [DATA_WIDTH-1:0] active_cmd;
    wire [7:0] active_crc;
    wire [DATA_WIDTH-1:0] shadow_cmd;

    reg [DATA_WIDTH-1:0] mem [0:255];

    always @(posedge clk) begin
        if (mem_wen)
            mem[mem_addr[7:0]] <= mem_wdata;
    end

    assign mem_rdata = mem[mem_addr[7:0]];

    cmd_queue_manager u_qm (
        .clk(clk),
        .rst_n(rst_n),
        .sub_valid(sub_valid),
        .sub_cmd(sub_cmd),
        .sub_crc(sub_crc),
        .sub_integrity_ok(cmd_integrity_ok),
        .sub_ready(sub_ready),
        .comp_valid(comp_valid),
        .comp_data(comp_data),
        .comp_ready(comp_ready),
        .dma_start(dma_start),
        .dma_cmd(dma_cmd),
        .dma_done(dma_done),
        .dma_result(dma_result),
        .fault_detected(fault_detected),
        .active_fault(active_fault),
        .fault_replay_cmd(fault_replay_cmd),
        .fault_ack(fault_ack),
        .fault_inject(fault_inject),
        .fault_mask(fault_mask),
        .active_valid(active_valid),
        .active_cmd(active_cmd),
        .active_crc(active_crc),
        .shadow_cmd(shadow_cmd)
    );

    dma_engine u_dma (
        .clk(clk),
        .rst_n(rst_n),
        .start(dma_start),
        .cmd_in(dma_cmd),
        .done(dma_done),
        .result(dma_result),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wen(mem_wen),
        .mem_rdata(mem_rdata)
    );

    fault_unit u_fu (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(sub_valid),
        .cmd_in(sub_cmd),
        .crc_expected(sub_crc),
        .cmd_integrity_ok(cmd_integrity_ok),
        .ingress_fault(ingress_fault),
        .active_valid(active_valid),
        .active_cmd(active_cmd),
        .active_crc(active_crc),
        .shadow_cmd(shadow_cmd),
        .active_fault(active_fault),
        .fault_replay_cmd(fault_replay_cmd),
        .fault_detected(fault_detected),
        .fault_ack(fault_ack)
    );

endmodule
