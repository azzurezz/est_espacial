# Estatística Espacial: Eleição Presidencial (1º Turno) & Agronegócio da Soja em MG

Este estudo investiga a relação espacial entre a produção de **soja**, o **agronegócio** e o comportamento eleitoral em **Minas Gerais**, analisando a votação de **Flávio Nantes Bolsonaro** (PL - 22, Eleição Presidencial de 2026 - 1º Turno, 04/10/2026) em todos os **853 municípios** mineiros.

---

## 1. Dados e Fontes Utilizadas

1. **Dados Eleitorais Oficiais (TSE)**:
   - Votação oficial por seção eleitoral da Eleição Presidencial de 2026 (1º Turno - 04/10/2026), agregada nos **853 municípios de Minas Gerais**.
   - Votos nominais de **Flávio Bolsonaro (22)**, **Luiz Inácio Lula da Silva (13)** e demais concorrentes.
2. **Dados da Soja (IBGE - Tabela 1612)**:
   - Arquivo oficial [`soja_mg_municipios.csv`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/soja_mg_municipios.csv): Área plantada de soja em grãos (Hectares) para os municípios mineiros (com $302$ municípios produtores de soja).
3. **Dados Econômicos e Malha Territorial (IBGE)**:
   - PIB municipal e participação percentual do Valor Adicionado da Agropecuária no PIB (`share_agro_pct`).
   - Geometrias vetoriais dos 853 municípios e centroides geográficos.

---

## 2. Resultados Principais

### 2.1 Desempenho Eleitoral de Flávio Bolsonaro (1º Turno - MG)
- **Votos Válidos Totais em MG**: $11.954.836$ votos.
- **Flávio Bolsonaro (PL - 22)**: **$5.769.600$ votos ($48{,}26\%$)** — venceu o 1º turno em Minas Gerais.
- **Luiz Inácio Lula da Silva (PT - 13)**: $5.176.282$ votos ($43{,}30\%$).
- **Média Municipal**: $44{,}57\%$ dos votos válidos nos municípios, atingindo picos de até **$74{,}66\%$** em municípios do Triângulo, Alto Paranaíba e Sul de Minas.

### 2.2 Mapas Temáticos
- **Mapa da Votação de Flávio Bolsonaro**: [`outputs/maps/mapa_votacao_flavio_mg.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_votacao_flavio_mg.png)
- **Mapa da Área Plantada de Soja**: [`outputs/maps/mapa_soja_mg.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_soja_mg.png)

### 2.3 Autocorrelação Espacial Global (Índice de Moran)
Com a Matriz de Vizinhança Espacial $W$ ($k=6$ vizinhos mais próximos, padronizada por linhas):
- **Índice de Moran Global ($I$)**: **$0{,}6973$**
- **Valor Esperado sob $H_0$ ($E[I]$)**: $-0{,}0012$
- **Desvio-Padrão Teórico**: $0{,}0189$
- **Estatística $z$ ($z$-score)**: **$36{,}89$** ($p < 10^{-15}$)
- **Conclusão**: Há uma **fortíssima dependência espacial positiva** na votação ($I \approx 0{,}70$). Municípios com expressiva votação pró-Flávio Bolsonaro concentram-se em grandes aglomerados espaciais contíguos (*Alto-Alto* no Noroeste, Triângulo e Sul de Minas).
- **Gráfico de Dispersão de Moran**: [`outputs/figures/moran_scatterplot_votos.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/figures/moran_scatterplot_votos.png)

### 2.4 Modelo de Regressão Linear Múltipla (OLS)
Relação entre a votação percentual e os indicadores agrícolas e econômicos:

$$\text{Pct\_Voto\_Flavio}_i = \beta_0 + \beta_1 \log(1 + \text{Area\_Soja\_ha}_i) + \beta_2 \text{Dummy\_Soja}_i + \beta_3 \text{Share\_Agro}_i + \beta_4 \log(\text{PIB\_Total}_i) + \varepsilon_i$$

| Covariável | Estimativa ($\hat{\beta}$) | Erro Padrão | Estatística $t$ | $p$-valor | Significância |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Intercepto** | $+8{,}0109$ | $3{,}7402$ | $+2{,}142$ | $0{,}0325$ | * |
| **Presença de Soja (`tem_soja`)** | **$+4{,}1052$** | **$2{,}2748$** | **$+1{,}805$** | **$0{,}0715$** | . (Tendência a 10%) |
| **$\log(\text{Área de Soja} + 1)$** | $+0{,}6287$ | $0{,}6737$ | $+0{,}933$ | $0{,}3510$ |  |
| **Share Agropecuária no PIB (`share_agro_pct`)** | **$+0{,}0784$** | **$0{,}0287$** | **$+2{,}734$** | **$0{,}0064$** | **\*\*** ($p < 0{,}01$) |
| **$\log(\text{PIB Total})$** | **$+2{,}6554$** | **$0{,}2896$** | **$+9{,}170$** | **$< 2 \times 10^{-16}$** | *** |

- **$R^2$**: $0{,}2298$ ($F = 63{,}27$, $p < 2{,}2 \times 10^{-16}$).
- **Interpretação**:
  - A **participação do agronegócio no PIB municipal** tem impacto positivo e altamente significativo ($p = 0{,}0064$): para cada $10$ pontos percentuais a mais de peso do agro na economia local, o percentual de votos de Flávio Bolsonaro sobe cerca de $+0{,}8$ p.p.
  - Municípios com cultivo de soja têm, em média, **$+4{,}1$ pontos percentuais** a mais de votação em Flávio Bolsonaro comparados a municípios sem soja.
- **Gráfico de Dispersão**: [`outputs/figures/regressao_voto_vs_soja.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/figures/regressao_voto_vs_soja.png)

### 2.5 Resíduos e Correlação Espacial Residual
- Extração do resíduo de ajuste: $e_i = y_i - \hat{y}_i$.
- **Índice de Moran nos Resíduos ($I_{\text{res}}$)**: **$0{,}5849$**
- **Estatística $z$ dos Resíduos**: **$30{,}95$** ($p < 10^{-15}$)
- **Diagnóstico Crítico**: Os resíduos da regressão linear OLS mantêm fortíssima autocorrelação espacial ($I_{\text{res}} \approx 0{,}58$), violando o pressuposto de erros independentes. Fatores regionais, contágio político de vizinhança e variáveis não observadas atuam espacialmente, recomendando o uso de modelos de econometria espacial (SAR / SEM).
- **Mapa dos Resíduos**: [`outputs/maps/mapa_residuos_regressao.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_residuos_regressao.png)
- **Moran Scatterplot dos Resíduos**: [`outputs/figures/moran_scatterplot_residuos.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/figures/moran_scatterplot_residuos.png)

---

## 3. Estrutura Limpa e Organizada de Arquivos

```text
eleicao/
├── README.md                      # Documentação dos resultados e diagnósticos espaciais
├── soja_mg_municipios.csv         # Dados oficiais de área de soja (Tabela 1612 IBGE)
├── votacao_secao_2026_MG/         # Pasta oficial de seções eleitorais do TSE
│   ├── votacao_secao_2026_MG.csv
│   └── leiame.pdf
│
├── R/
│   ├── 00_setup_packages.R        # Setup de bibliotecas
│   └── analise_espacial_eleicao.R # Script R de análise espacial, mapas e modelos
│
├── data/
│   ├── processa_eleicao_soja.py   # Script de consolidação das bases
│   ├── raw/                       # Bases brutas do IBGE (malhas e PIB)
│   └── processed/                 # Bases tratadas finais (.csv, .geojson e matriz W)
│
└── outputs/
    ├── diagnosticos_espaciais_summary.csv # Tabela síntese dos indicadores
    ├── maps/                      # Mapas temáticos coropléticos
    └── figures/                   # Diagramas de Moran e gráficos de regressão
```
