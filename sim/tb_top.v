`timescale 1ns/1ps
module tb_top;
    reg clk = 0;
    reg rst_n = 0;
    reg sub_valid;
    reg [31:0] sub_cmd;
    reg [7:0]  sub_crc;
    wire sub_ready, comp_valid;
    wire [31:0] comp_data;
    reg comp_ready = 1;

    reg fault_inject;
    reg [31:0] fault_mask;

    integer completion_count;
    integer error_count;
    integer t2_completion_count_before;
    integer t2_unexpected_completion;
    integer t2_cycle;

    top_controller dut (
        .clk(clk), .rst_n(rst_n),
        .sub_valid(sub_valid), .sub_cmd(sub_cmd), .sub_crc(sub_crc),
        .sub_ready(sub_ready),
        .comp_valid(comp_valid), .comp_data(comp_data),
        .comp_ready(comp_ready),
        .fault_inject(fault_inject), .fault_mask(fault_mask)
    );

    always #5 clk = ~clk;

    function [7:0] crc8_ref;
        input [31:0] data;
        integer i;
        reg [7:0] c;
        reg fb;
        begin
            c = 8'h00;
            for (i = 31; i >= 0; i = i - 1) begin
                fb = c[7] ^ data[i];
                c  = c << 1;
                if (fb) c = c ^ 8'h07;
            end
            crc8_ref = c;
        end
    endfunction

    task submit_cmd;
        input [31:0] cmd;
        input [7:0] crc;
        begin
            @(negedge clk);
            sub_cmd   = cmd;
            sub_crc   = crc;
            sub_valid = 1'b1;
            @(negedge clk);
            sub_valid = 1'b0;
        end
    endtask

    task wait_completion;
        input [31:0] expected;
        begin
            // Wait for a NEW completion event.
            if (comp_valid)
                @(negedge clk);
            wait (!comp_valid);
            wait (comp_valid);

            if (comp_data === expected) begin
                $display("[T=%0t] PASS: completion data=%h", $time, comp_data);
                completion_count = completion_count + 1;
            end else begin
                $display("[T=%0t] FAIL: expected completion=%h got=%h",
                         $time, expected, comp_data);
                error_count = error_count + 1;
            end
            @(negedge clk);
        end
    endtask

    initial begin
        sub_valid = 0;
        sub_cmd = 0;
        sub_crc = 0;
        fault_inject = 0;
        fault_mask = 0;
        completion_count = 0;
        error_count = 0;
        t2_completion_count_before = 0;
        t2_unexpected_completion = 0;
        t2_cycle = 0;

        #20;
        rst_n = 1;

        // T1: normal command.
        submit_cmd({4'h2,28'h00000005}, crc8_ref({4'h2,28'h00000005}));
        wait_completion({4'h2,28'h00000005});
        $display("T1 NORMAL: PASS");

        // T2: bad ingress CRC. It must be detected and must not complete
        // during the defined 10-negative-edge observation window.
        t2_completion_count_before = completion_count;
        @(negedge clk);
        sub_cmd   = {4'h2,28'h00000009};
        sub_crc   = crc8_ref({4'h2,28'h00000009}) ^ 8'h01;
        sub_valid = 1'b1;
        @(posedge clk);
        #1;
        if (dut.ingress_fault && !comp_valid)
            $display("T2 BAD CRC DETECTION: PASS");
        else begin
            $display("T2 BAD CRC DETECTION: FAIL");
            error_count = error_count + 1;
        end

        @(negedge clk);
        sub_valid = 1'b0;

        t2_unexpected_completion = 0;
        for (t2_cycle = 0; t2_cycle < 10; t2_cycle = t2_cycle + 1) begin
            @(negedge clk);
            if (comp_valid)
                t2_unexpected_completion = 1;
        end

        if (!t2_unexpected_completion &&
            completion_count == t2_completion_count_before)
            $display("T2 BAD CRC: NO COMPLETION DURING 10-CYCLE WINDOW: PASS");
        else begin
            $display("T2 BAD CRC: REJECTION WINDOW CHECK: FAIL");
            error_count = error_count + 1;
        end

        // T3: SEU-inspired bit flip after a trusted command is queued.
        submit_cmd({4'h2,28'h0000000A}, crc8_ref({4'h2,28'h0000000A}));
        @(negedge clk);
        fault_mask   = 32'h00000001;
        fault_inject = 1'b1;
        @(negedge clk);
        fault_inject = 1'b0;
        wait_completion({4'h2,28'h0000000A});
        $display("T3 SEU-INSPIRED REPLAY: PASS");

        // T4: A-B-C queue-integrity test.
        submit_cmd({4'h2,28'h00000014}, crc8_ref({4'h2,28'h00000014}));
        submit_cmd({4'h2,28'h00000015}, crc8_ref({4'h2,28'h00000015}));
        submit_cmd({4'h2,28'h00000016}, crc8_ref({4'h2,28'h00000016}));

        wait_completion({4'h2,28'h00000014});

        // Inject only after B is the active command.
        wait (dut.active_valid &&
              dut.active_cmd == {4'h2,28'h00000015});
        @(negedge clk);
        fault_mask   = 32'h00000100;
        fault_inject = 1'b1;
        @(negedge clk);
        fault_inject = 1'b0;

        wait_completion({4'h2,28'h00000015});
        wait_completion({4'h2,28'h00000016});

        if (completion_count == 5)
            $display("T4 A-B-C EXACTLY-ONCE: PASS (5 total completions)");
        else begin
            $display("T4 A-B-C EXACTLY-ONCE: FAIL (completion_count=%0d)",
                     completion_count);
            error_count = error_count + 1;
        end

        if (error_count == 0)
            $display("================ ALL TESTS PASSED ================");
        else
            $display("================ TEST FAILURES: %0d ================", error_count);

        #20;
        $finish;
    end
endmodule
