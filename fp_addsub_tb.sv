`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.11.2026 13:57:41
// Design Name: 
// Module Name: fp_addsub_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module fp_addsub_tb;

    logic clk;
    logic reset;
    logic in_valid;
    logic sub;
    logic [31:0] a, b;

    logic out_valid;
    logic [31:0] result;

    fp_addsub dut (
        .clk(clk),
        .reset(reset),
        .in_valid(in_valid),
        .sub(sub),
        .a(a),
        .b(b),
        .out_valid(out_valid),
        .result(result)
    );

    always #5 clk = ~clk;

    task automatic test_operation(
        input logic [31:0] x,
        input logic [31:0] y,
        input logic operation,
        input logic [31:0] expected
    );
    begin

        @(negedge clk);

        a = x;
        b = y;
        sub = operation;
        in_valid = 1;

        @(negedge clk);

        in_valid = 0;
        a = 32'h98143525;
        b = 32'h12345678;

        if (out_valid !== 1'b1)
            $display("FAIL: out_valid not asserted");

        else if (result !== expected)
            $display("FAIL: A=%h B=%h SUB=%b GOT=%h EXPECTED=%h",
                     x, y, operation, result, expected);

        else
            $display("PASS: RESULT=%h", result);

        @(negedge clk);
        @(negedge clk);

    end
    endtask

    initial begin

        clk = 0;
        reset = 1;
        in_valid = 0;
        sub = 0;
        a = 0;
        b = 0;

        repeat (3) @(negedge clk);
        reset = 0;

        test_operation(32'h40600000, 32'h40200000, 0, 32'h40C00000);
        test_operation(32'h40E00000, 32'h40400000, 1, 32'h40800000);
        test_operation(32'h3F800000, 32'h3F800000, 0, 32'h40000000);
        test_operation(32'h3F800000, 32'h3F800000, 1, 32'h00000000);

        test_operation(32'h00000001, 32'h00000001, 0, 32'h00000002);
        test_operation(32'h7F800000, 32'h3F800000, 0, 32'h7F800000);
        test_operation(32'h7F800000, 32'hFF800000, 0, 32'h7FC00000);

        test_operation(32'h80000000, 32'h80000000, 0, 32'h80000000);
        test_operation(32'h00000000, 32'h80000000, 0, 32'h00000000);

        $display("TESTING COMPLETED");
        $finish;

    end

endmodule

