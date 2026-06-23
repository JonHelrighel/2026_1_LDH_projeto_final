`include "coeff_pkg.vh"

module fir_notch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] entrada,
    input  wire        nova_amostra,
    output reg  [11:0] saida,
    output reg         saida_valida
);

    reg signed [15:0] x0,  x1,  x2,  x3;
    reg signed [15:0] x4,  x5,  x6,  x7;
    reg signed [15:0] x8,  x9,  x10, x11;
    reg signed [15:0] x12, x13, x14, x15;

    reg signed [31:0] soma;
    reg [2:0] par;
    reg calculando;

    // Shift register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x0  <= 0; x1  <= 0; x2  <= 0; x3  <= 0;
            x4  <= 0; x5  <= 0; x6  <= 0; x7  <= 0;
            x8  <= 0; x9  <= 0; x10 <= 0; x11 <= 0;
            x12 <= 0; x13 <= 0; x14 <= 0; x15 <= 0;
        end else if (nova_amostra && !calculando) begin
            x15 <= x14; x14 <= x13; x13 <= x12;
            x12 <= x11; x11 <= x10; x10 <= x9;
            x9  <= x8;  x8  <= x7;  x7  <= x6;
            x6  <= x5;  x5  <= x4;  x4  <= x3;
            x3  <= x2;  x2  <= x1;  x1  <= x0;
            x0  <= {{4{entrada[11]}}, entrada};
        end
    end

    // MAC sequencial
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            soma         <= 0;
            par          <= 0;
            calculando   <= 0;
            saida        <= 0;
            saida_valida <= 0;
        end else begin
            saida_valida <= 0;

            if (nova_amostra && !calculando) begin
                soma       <= 0;
                par        <= 0;
                calculando <= 1;
            end

            if (calculando) begin
                case (par)
                    0: soma <= soma + (x0  + x15) * `H0;
                    1: soma <= soma + (x1  + x14) * `H1;
                    2: soma <= soma + (x2  + x13) * `H2;
                    3: soma <= soma + (x3  + x12) * `H3;
                    4: soma <= soma + (x4  + x11) * `H4;
                    5: soma <= soma + (x5  + x10) * `H5;
                    6: soma <= soma + (x6  + x9 ) * `H6;
                    7: soma <= soma + (x7  + x8 ) * `H7;
                endcase

                if (par == 7) begin
                    saida        <= soma[27:16];
                    saida_valida <= 1;
                    calculando   <= 0;
                end else begin
                    par <= par + 1;
                end
            end
        end
    end

endmodule