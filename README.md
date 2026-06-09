# Projeto Final — Linguagens de Descrição de Hardware

**Curso:** Engenharia de Controle e Automação — IFSC Chapecó  
**Unidade Curricular:** Linguagens de Descrição de Hardware (LDH)  
**Semestre:** 2026/2  
**Avaliação:** Nota M3

---

## Visão Geral

Este projeto implementa uma cadeia completa de processamento de áudio em FPGA, utilizando o kit **DE10-Lite** (Intel MAX10) e a ferramenta **Quartus Prime Lite 18.1**. O objetivo é integrar três blocos digitais desenvolvidos em Verilog:

```
Entrada analógica
      │
      ▼
┌─────────────┐     amostras 12-bit @ 48 kHz     ┌──────────────┐     amostras filtradas     ┌──────────────────┐
│  ADC MAX10  │ ─────────────────────────────────► │  Filtro FIR  │ ──────────────────────────► │  Driver SPI DAC  │
│  (IP Core)  │                                   │  Notch 60 Hz │                             │    (MCP4921)     │
└─────────────┘                                   └──────────────┘                             └──────────────────┘
                                                                                                        │
                                                                                                        ▼
                                                                                               Saída analógica
                                                                                               (DAC externo)
```

Cada aluno é responsável por **um bloco principal**, entregue via Pull Request sobre um fork deste repositório.

---

## Hardware Necessário

| Item | Descrição |
|------|-----------|
| DE10-Lite | Kit de desenvolvimento Intel MAX10 (10M50DAF484C7G) |
| MCP4921 | DAC SPI 12-bit, encapsulamento DIP-8 ou SO-8 |
| Fonte de referência | 3,3 V ou 5 V para VREF do MCP4921 |
| Jumpers / protoboard | Conexão GPIO do DE10-Lite ao MCP4921 |
| Sinal de teste | Gerador de funções ou saída de áudio com ruído de rede 60 Hz |

> O MCP4921 opera em SPI modo 0,0 (CPOL=0, CPHA=0), tensão de alimentação 2,7–5,5 V,
> clock SPI máximo de 20 MHz. O frame de 16 bits tem o formato:
> `[0][BUF][/GA][/SHDN][D11..D0]`

---

## Estrutura do Repositório

```
├── README.md
├── docs/
│   ├── especificacao.md       ← requisitos técnicos detalhados por bloco
│   └── workflow_git.md        ← tutorial fork → branch → pull request
├── rtl/
│   ├── top.v                  ← módulo top-level (integração dos blocos)
│   ├── adc/
│   │   └── adc_wrapper.v      ← wrapper do IP MAX10 ADC            [Aluno 1]
│   ├── fir/
│   │   ├── fir_notch.v        ← filtro FIR notch 60 Hz             [Aluno 2]
│   │   └── coeff_pkg.vh       ← coeficientes gerados externamente
│   └── dac_spi/
│       └── spi_dac_driver.v   ← driver SPI para o MCP4921          [Aluno 3]
├── tb/
│   ├── tb_adc_wrapper.v
│   ├── tb_fir_notch.v
│   ├── tb_spi_dac.v
│   └── tb_top.v
├── quartus/
│   ├── projeto_final.qpf
│   ├── projeto_final.qsf      ← pin assignments DE10-Lite
│   └── ip/                    ← arquivos gerados pelo IP Catalog
└── scripts/
    └── gen_fir_coeffs.py      ← script Python para gerar coeficientes
```

---

## Divisão de Tarefas

| Aluno | Bloco | Arquivos principais | Testbench |
|-------|-------|---------------------|-----------|
| 1 | ADC Wrapper | `rtl/adc/adc_wrapper.v` | `tb/tb_adc_wrapper.v` |
| 2 | Filtro FIR Notch 60 Hz | `rtl/fir/fir_notch.v`, `scripts/gen_fir_coeffs.py` | `tb/tb_fir_notch.v` |
| 3 | Driver SPI MCP4921 | `rtl/dac_spi/spi_dac_driver.v` | `tb/tb_spi_dac.v` |

Cada aluno deve abrir **pelo menos um Pull Request** que inclua o módulo RTL e seu testbench.

---

## Especificações Técnicas por Bloco

### Bloco 1 — ADC Wrapper (Aluno 1)

- Instanciar o IP **Modular ADC Core** do MAX10 via IP Catalog do Quartus
- Frequência de amostragem: **48 kHz** (derivada do clock de 50 MHz do DE10-Lite)
- Canal ADC: livre (utilizar qualquer entrada analógica disponível no conector J7)
- Interface de saída: dado de 12 bits válido com sinal `valid` de 1 pulso por amostra
- O sinal `valid` dispara o pipeline downstream (FIR e SPI DAC)

**Interface sugerida do módulo:**
```verilog
module adc_wrapper (
    input  wire        clk,        // 50 MHz
    input  wire        rst_n,
    output wire [11:0] adc_data,   // amostra atual
    output wire        adc_valid   // 1 ciclo de pulso por amostra
);
```

### Bloco 2 — Filtro FIR Notch 60 Hz (Aluno 2)

- Tipo: FIR simétrico (fase linear) com notch centrado em **60 Hz**
- Frequência de amostragem: **48 kHz**
- Ordem mínima recomendada: **64 taps** (ordem 63); quanto maior, mais profundo o notch
- Coeficientes: gerados pelo script `scripts/gen_fir_coeffs.py` (ver abaixo) e declarados em `coeff_pkg.vh`
- Aritmética interna: inteiros com largura suficiente para evitar overflow (os coeficientes são escalados para inteiros de 16 bits com sinal)

**Interface sugerida do módulo:**
```verilog
module fir_notch (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] data_in,
    input  wire        valid_in,
    output wire [11:0] data_out,
    output wire        valid_out
);
```

**Bônus — Implementação Shift-Add:** Em vez de usar multiplicadores genéricos (`*`), implementar as multiplicações por coeficientes usando apenas deslocamentos (`<<`, `>>`) e somas. Isso economiza recursos de DSP no FPGA e demonstra domínio de aritmética de hardware. **(Ponto extra)**

#### Gerando os Coeficientes

O script `scripts/gen_fir_coeffs.py` requer Python 3 com `numpy` e `scipy`:

```bash
pip install numpy scipy
python scripts/gen_fir_coeffs.py
```

O script gera o arquivo `rtl/fir/coeff_pkg.vh` com os coeficientes em formato `localparam`.

### Bloco 3 — Driver SPI MCP4921 (Aluno 3)

- Protocolo: **SPI modo 0,0** (CPOL=0, CPHA=0)
- Clock SPI: recomendado **1 MHz** (facilita visualização no osciloscópio); máximo permitido pelo MCP4921: 20 MHz
- Frame: 16 bits, MSB primeiro
  - Bit 15: `0` (seleciona DAC A, único canal do MCP4921)
  - Bit 14: `BUF` — `0` (VREF sem buffer interno)
  - Bit 13: `/GA` — `1` (ganho 1×)
  - Bit 12: `/SHDN` — `1` (saída ativa)
  - Bits 11–0: dado de 12 bits (amostra filtrada)
- Sinais físicos: `SPI_CLK`, `SPI_MOSI`, `SPI_CS_N` — conectar a pinos GPIO do DE10-Lite

**Interface sugerida do módulo:**
```verilog
module spi_dac_driver (
    input  wire        clk,        // 50 MHz
    input  wire        rst_n,
    input  wire [11:0] data_in,
    input  wire        valid_in,   // pulso disparando transmissão
    output wire        spi_clk,
    output wire        spi_mosi,
    output wire        spi_cs_n,
    output wire        ready       // alto quando livre para nova amostra
);
```

---

## Conexões no DE10-Lite

### ADC (conector J7 — na placa)
- Escolha qualquer canal CH0–CH7; documente no seu PR qual foi utilizado.

### SPI DAC (pinos GPIO — conector JP1 ou JP2)

| Sinal FPGA | Pino GPIO sugerido | MCP4921 |
|------------|-------------------|---------|
| `spi_clk`  | GPIO_0[0]          | SCK (pin 3) |
| `spi_mosi` | GPIO_0[2]          | SDI (pin 4) |
| `spi_cs_n` | GPIO_0[4]          | /CS (pin 2) |
| GND        | GND               | GND (pin 5) |
| 3.3 V      | 3.3 V (JP1 pin 11) | VDD (pin 8), VREF (pin 6) |

> Confirme os pinos no manual do DE10-Lite (disponível no site da Terasic) antes de fazer a ligação física.

---

## Fluxo de Trabalho Git

Instruções detalhadas em [`docs/workflow_git.md`](docs/workflow_git.md). Resumo:

1. **Fork** este repositório para sua conta GitHub pessoal
2. Clone o seu fork localmente
3. Crie uma **branch** com nome descritivo: `aluno1/adc-wrapper`, `aluno2/fir-notch`, `aluno3/spi-dac`
4. Implemente o módulo e o testbench
5. Faça commit com mensagens claras (em português está ótimo)
6. Abra um **Pull Request** do seu fork para este repositório
7. Aguarde revisão e corrija o que for solicitado

---

## Simulação

Todos os módulos devem ser simuláveis com o **ModelSim** incluído no Quartus Prime Lite 18.1.

Para compilar e simular um testbench no ModelSim (linha de comando):
```tcl
vlib work
vlog rtl/fir/fir_notch.v tb/tb_fir_notch.v
vsim -novopt tb_fir_notch
add wave *
run -all
```

O testbench deve, no mínimo:
- Aplicar estímulos representativos (ex: senoide de 60 Hz + senoide de 1 kHz para o FIR)
- Verificar a saída com `$display` ou comparação com valores esperados
- Finalizar com `$finish`

---

## Critérios de Avaliação

| Critério | Peso |
|----------|------|
| Módulo RTL funcional (simulação passa) | 40% |
| Testbench adequado | 20% |
| Síntese sem erros no Quartus | 20% |
| Pull Request organizado e descrição clara | 10% |
| Apresentação oral | 10% |
| **Bônus:** FIR com shift-add | +10% |

---

## Ferramentas e Referências

- [DE10-Lite User Manual](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=218&No=1021&PartNo=4) — Terasic
- [MAX10 ADC User Guide](https://www.intel.com/content/www/us/en/docs/programmable/683596/) — Intel
- [MCP4921 Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/22248a.pdf) — Microchip
- [Quartus Prime Lite 18.1](https://www.intel.com/content/www/us/en/software-kit/661017/intel-quartus-prime-lite-edition-design-software-version-18-1-for-windows.html) — Intel (download gratuito)
- Geração de coeficientes FIR: `scipy.signal.firwin` (Python) ou FDA Tool (MATLAB)
