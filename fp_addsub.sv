`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.11.2026 13:53:38
// Design Name: 
// Module Name: fp_addsub
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

module fp_addsub (
    input  logic        clk,
    input  logic        reset,
    input  logic        in_valid,
    input  logic        sub,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic        out_valid,
    output logic [31:0] result
);

    function automatic logic [31:0] fp_calculate (
        input logic [31:0] operand_a,
        input logic [31:0] operand_b,
        input logic        do_sub
    );

        logic sign_a;
        logic sign_b;
        logic result_sign;

        logic [7:0] exp_a;
        logic [7:0] exp_b;

        logic [22:0] frac_a;
        logic [22:0] frac_b;

        logic [23:0] sig_a;
        logic [23:0] sig_b;

        logic [279:0] mag_a;
        logic [279:0] mag_b;
        logic [279:0] magnitude;

        logic signed [280:0] signed_a;
        logic signed [280:0] signed_b;
        logic signed [280:0] sum_signed;

        logic [24:0] rounded;

        logic guard_bit;
        logic sticky_bit;

        integer shift_a;
        integer shift_b;
        integer shift_amt;
        integer highest;
        integer exp_field;
        integer i;

        begin

           
            // 1. Unpack operands
         

            sign_a = operand_a[31];

            // Subtraction is a + (-b).
            sign_b = operand_b[31] ^ do_sub;

            exp_a  = operand_a[30:23];
            exp_b  = operand_b[30:23];

            frac_a = operand_a[22:0];
            frac_b = operand_b[22:0];

            fp_calculate = 32'h00000000;

            // 2. NaN detection

            if (((exp_a == 8'hFF) && (frac_a != 0)) ||
                ((exp_b == 8'hFF) && (frac_b != 0))) begin

                fp_calculate = 32'h7FC00000;

            end

            
            // 3. Infinity detection
            

            else if ((exp_a == 8'hFF) || (exp_b == 8'hFF)) begin

                if ((exp_a == 8'hFF) && (exp_b == 8'hFF)) begin

                    // Infinity + opposite infinity = NaN

                    if (sign_a != sign_b)
                        fp_calculate = 32'h7FC00000;

                    else
                        fp_calculate = {sign_a, 8'hFF, 23'b0};

                end

                else if (exp_a == 8'hFF) begin

                    fp_calculate = {sign_a, 8'hFF, 23'b0};

                end

                else begin

                    fp_calculate = {sign_b, 8'hFF, 23'b0};

                end

            end

           
            // 4. Finite operands
       

            else begin

                // Normal: 1.fraction
                // Subnormal: 0.fraction

                if (exp_a == 0) begin

                    sig_a   = {1'b0, frac_a};
                    shift_a = 0;

                end
                else begin

                    sig_a   = {1'b1, frac_a};
                    shift_a = exp_a - 1;

                end

                if (exp_b == 0) begin

                    sig_b   = {1'b0, frac_b};
                    shift_b = 0;

                end
                else begin

                    sig_b   = {1'b1, frac_b};
                    shift_b = exp_b - 1;

                end

                // Convert to common exact scale: 2^-149.

                mag_a = 280'b0;
                mag_b = 280'b0;

                mag_a = sig_a;
                mag_b = sig_b;

                mag_a = mag_a << shift_a;
                mag_b = mag_b << shift_b;

                // Apply signs.

                if (sign_a)
                    signed_a = -$signed({1'b0, mag_a});
                else
                    signed_a = $signed({1'b0, mag_a});

                if (sign_b)
                    signed_b = -$signed({1'b0, mag_b});
                else
                    signed_b = $signed({1'b0, mag_b});

                // Exact signed addition.

                sum_signed = signed_a + signed_b;

                
                // 5. Determine result sign and zero
                

                if (sum_signed == 0) begin

                    // Only (-0) + (-0) produces -0.

                    if ((mag_a == 0) &&
                        (mag_b == 0) &&
                        sign_a &&
                        sign_b)

                        fp_calculate = 32'h80000000;

                    else

                        fp_calculate = 32'h00000000;

                end

                else begin

                    result_sign = sum_signed[280];

                    // Obtain absolute magnitude.

                    if (result_sign)
                        magnitude = $unsigned(-sum_signed);
                    else
                        magnitude = sum_signed[279:0];

                   
                    // 6. Find highest set bit
                  

                    highest = -1;

                    for (i = 0; i < 280; i = i + 1) begin

                        if (magnitude[i])
                            highest = i;

                    end

                   
                    // 7. Subnormal output
                  

                    if (highest < 23) begin

                        // Exact integer units of 2^-149.
                        // No bits are discarded here.

                        fp_calculate = {
                            result_sign,
                            8'b0,
                            magnitude[22:0]
                        };

                    end

                    // 8. Normalization

                    else begin

                        shift_amt = highest - 23;

                        // Keep 24 significant bits.

                        rounded = magnitude >> shift_amt;

                        guard_bit  = 1'b0;
                        sticky_bit = 1'b0;

                        
                        // 9. Guard, round and sticky information
                      

                        if (shift_amt > 0) begin

                            guard_bit = magnitude[shift_amt - 1];

                            for (i = 0; i < 280; i = i + 1) begin

                                if (i < (shift_amt - 1))
                                    sticky_bit =
                                        sticky_bit | magnitude[i];

                            end

                        end

                     
                        // 10. Round to nearest, ties to even
                        

                        if (guard_bit &&
                            (sticky_bit || rounded[0])) begin

                            rounded = rounded + 1'b1;

                        end

                        // Biased exponent.

                        exp_field = highest - 22;

                        // Handle rounding carry.

                        if (rounded[24]) begin

                            rounded = rounded >> 1;

                            exp_field = exp_field + 1;

                        end

                      
                        // 11. Overflow
                        

                        if (exp_field >= 255) begin

                            fp_calculate = {
                                result_sign,
                                8'hFF,
                                23'b0
                            };

                        end

                       
                        // 12. Pack binary32 result
                    
                        else begin

                            fp_calculate = {
                                result_sign,
                                exp_field[7:0],
                                rounded[22:0]
                            };

                        end

                    end

                end

            end

        end

    endfunction


    // Sequential interface
   
    always_ff @(posedge clk) begin

        if (reset) begin

            result    <= 32'b0;
            out_valid <= 1'b0;

        end

        else begin

            // One-cycle valid pulse.

            out_valid <= in_valid;

            if (in_valid) begin

                result <= fp_calculate(a, b, sub);

            end

        end

    end

endmodule

