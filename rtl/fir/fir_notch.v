`include "coeff_pkg.vh"   // puxa os coeficientes H0..H15

module fir_notch (
    input  wire        clk,           // clock principal do sistema
    input  wire        rst_n,         // reset ativo em nível baixo
    input  wire [11:0] entrada,       // amostra vinda do ADC (12 bits)
    input  wire        nova_amostra,  // pulso que avisa que chegou nova amostra
    output reg  [11:0] saida,         // resultado filtrado (12 bits)
    output reg         saida_valida   // pulso que avisa que a saida está pronta
);

    // as 16 amostras mais recentes guardadas em registradores separados
    reg [11:0] x0,  x1,  x2,  x3;
    reg [11:0] x4,  x5,  x6,  x7;
    reg [11:0] x8,  x9,  x10, x11;
    reg [11:0] x12, x13, x14, x15;

    reg [31:0] soma;       // acumulador da soma MAC
    reg [3:0]  par;        // conta de 0 a 15 (16 multiplicações)
    reg        calculando; // flag: indica que o MAC está em andamento

   
    // BLOCO 1: shift register
    // guarda as 16 amostras mais recentes
  
	 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // zera tudo no reset
            x0  <= 0; x1  <= 0; x2  <= 0; x3  <= 0;
            x4  <= 0; x5  <= 0; x6  <= 0; x7  <= 0;
            x8  <= 0; x9  <= 0; x10 <= 0; x11 <= 0;
            x12 <= 0; x13 <= 0; x14 <= 0; x15 <= 0;
        end else if (nova_amostra && !calculando) begin
		  
            // empurra todas as amostras uma posição para frente
            // x15 é a mais antiga, x0 é a mais nova
				
            x15 <= x14; x14 <= x13; x13 <= x12;
            x12 <= x11; x11 <= x10; x10 <= x9;
            x9  <= x8;  x8  <= x7;  x7  <= x6;
            x6  <= x5;  x5  <= x4;  x4  <= x3;
            x3  <= x2;  x2  <= x1;  x1  <= x0;
            x0  <= entrada; // nova amostra entra direto em x0, sem conversao
        end
    end

 
    // BLOCO 2: MAC sequencial (Multiply-Accumulate)
    // calcula a convolução em 16 passos, um por amostra

	 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            soma         <= 0;
            par          <= 0;
            calculando   <= 0;
            saida        <= 0;
            saida_valida <= 0;
        end else begin
            saida_valida <= 0; // por padrão saida_valida fica em 0

            if (nova_amostra && !calculando) begin
                // chegou nova amostra: zera acumulador e começa cálculo
                soma       <= 0;
                par        <= 0;
                calculando <= 1;
            end

            if (calculando) begin
				
                // a cada ciclo de clock processa uma amostra com seu coeficiente
                case (par)
                    0:  soma <= soma + x0  * `H0;
                    1:  soma <= soma + x1  * `H1;
                    2:  soma <= soma + x2  * `H2;
                    3:  soma <= soma + x3  * `H3;
                    4:  soma <= soma + x4  * `H4;
                    5:  soma <= soma + x5  * `H5;
                    6:  soma <= soma + x6  * `H6;
                    7:  soma <= soma + x7  * `H7;
                    8:  soma <= soma + x8  * `H8;
                    9:  soma <= soma + x9  * `H9;
                    10: soma <= soma + x10 * `H10;
                    11: soma <= soma + x11 * `H11;
                    12: soma <= soma + x12 * `H12;
                    13: soma <= soma + x13 * `H13;
                    14: soma <= soma + x14 * `H14;
                    15: soma <= soma + x15 * `H15;
						  
                endcase

                if (par == 15) begin
					 
                    // processou as 16 amostras: resultado pronto
						  
                    saida        <= soma[27:16]; // pega bits 27 a 16 (descarta crescimento de bits da multiplicação)
                    saida_valida <= 1;           // avisa que a saida está pronta
                    calculando   <= 0;           // libera para próxima amostra
                end else begin
                    par <= par + 1; // avança para a próxima amostra
                end
            end
        end
    end

endmodule