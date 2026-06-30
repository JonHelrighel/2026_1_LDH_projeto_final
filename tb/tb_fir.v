`timescale 1ns/1ps


module tb_fir();
    reg        clk;
    reg        rst_n;
    reg [11:0] entrada;
    reg        nova_amostra;
    wire [11:0] saida;
    wire        saida_valida;

    fir_notch uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .entrada      (entrada),
        .nova_amostra (nova_amostra),
        .saida        (saida),
        .saida_valida (saida_valida)
    );

    // Clock 50MHz
    always #10 clk = ~clk;

    initial begin
        clk          = 0;
        rst_n        = 0;
        entrada      = 0;
        nova_amostra = 0;

        // Reset
        #40;
        rst_n = 1;
        #20;

        // Zeros antes do pulso
        repeat(4) begin
            entrada = 12'd0;
            nova_amostra = 1; #20; nova_amostra = 0;
            #400;   // tempo aumentado para dar tempo das 16 multiplicacoes
        end

        // Pulso unico
        entrada = 12'd2047;
        nova_amostra = 1; #20; nova_amostra = 0;
        #400;

        // Zeros depois do pulso (cauda do filtro)
        repeat(20) begin
            entrada = 12'd0;
            nova_amostra = 1; #20; nova_amostra = 0;
            #400;
        end
    end

    // Printa no terminal sempre que sair resultado
    always @(posedge saida_valida) begin
        $display("%0t, %0d, %0d", $time, entrada, saida);
    end

endmodule