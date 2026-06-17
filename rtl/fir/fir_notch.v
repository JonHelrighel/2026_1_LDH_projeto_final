module fir_notch (
    input wire clk,
    input wire rst_n,
    input wire [11:0] data_in,     // de ADC (12-bit)
    input wire valid_in,
    output reg [11:0] data_out,
    output reg valid_out
);

    import coeff_pkg::*;

    // Delay line: 16 amostras (12-bit + sign extend se necessário)
    reg signed [15:0] delay[0:15];  // maior bit width para segurança

    // Acumulador (largura suficiente: ~16 + log2(16) + 16 bits coef ~ 30-32 bits)
    reg signed [31:0] acc;
    reg [3:0] k;                    // contador 0..7
    reg processing;

    wire signed [15:0] x_sym;       // x[k] + x[15-k]
    wire signed [31:0] prod;        // multiplicação (ou shift-add no bônus)

    // Shift register quando valid_in
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0; i<16; i++) delay[i] <= 16'd0;
            acc <= 32'd0;
            k <= 4'd0;
            processing <= 1'b0;
            valid_out <= 1'b0;
            data_out <= 12'd0;
        end else begin
            valid_out <= 1'b0;

            if (valid_in && !processing) begin
                // Desloca delay line
                for (int i=15; i>0; i--) delay[i] <= delay[i-1];
                delay[0] <= { {4{data_in[11]}}, data_in };  // sign extend 12->16

                processing <= 1'b1;
                acc <= 32'd0;
                k <= 4'd0;
            end

            if (processing) begin
                // Par simétrico
                x_sym <= delay[k] + delay[15 - k];

                // Multiplicação (padrão) ou shift-add no bônus
                prod <= x_sym * h[k];          // Quartus mapeia para DSP

                acc <= acc + prod;

                if (k == 4'd7) begin
                    // Fim do processamento
                    processing <= 1'b0;
                    // Saída: saturate/truncate para 12-bit
                    data_out <= acc[27:16];     // ajuste bits conforme teste (evita overflow)
                    valid_out <= 1'b1;
                end else begin
                    k <= k + 1;
                end
            end
        end
    end
endmodule