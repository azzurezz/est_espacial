# Estatística Espacial Aplicada a Dados Eleitorais & Agronegócio

Este projeto investiga a relação espacial entre a produção agrícola (com foco na **soja** e **agropecuária**) e o comportamento eleitoral em **Minas Gerais**, analisando a votação de **Flávio Roscoe** (PL - 22, Eleições Gerais 2026 para o Governo do Estado) nos **853 municípios** mineiros.

---

## 1. Escopo do Estudo

- **Estado**: Minas Gerais (MG) — Cobertura completa dos 853 municípios.
- **Candidato**: Flávio Roscoe (PL, número 22) — ex-presidente da FIEMG, com plataforma voltada à produção industrial, agronegócio e desenvolvimento regional.
- **Variável Resposta ($y$)**: Percentual de votos nominais válidos obtidos por município ($\% \text{Votos de Flávio}$).
- **Fontes de Dados**:
  - **TSE (Tribunal Superior Eleitoral)**: Dados oficiais da totalização e votação nominal por município e zona eleitoral (2026).
  - **IBGE - PAM (Pesquisa Agrícola Municipal - Tabela 5457)**: Quantidade produzida de soja (toneladas), área colhida (ha) e valor da produção agrícola (mil R$).
  - **IBGE - PIB dos Municípios (Tabela 5938)**: Produto Interno Bruto total e Valor adicionado bruto da agropecuária.
  - **IBGE - Malhas Digitais**: Geometrias vetoriais dos 853 municípios de Minas Gerais.

---

## 2. Resultados das Etapas do Estudo

### 2.1 Percentual de Votação por Município
- **Média Estadual**: $5{,}23\%$ dos votos válidos.
- **Mediana**: $4{,}94\%$.
- **Variação**: De $0{,}00\%$ até $16{,}41\%$ dos votos válidos.
- **Polos de Destaque**: Expressivo desempenho nas regiões do **Triângulo Mineiro / Alto Paranaíba**, **Noroeste de Minas** e polos industriais/agroindustriais.

### 2.2 Mapa Temático Coroplético
- Arquivo gerado: [`outputs/maps/mapa_votacao_flavio_mg.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_votacao_flavio_mg.png)
- Mapa temático da soja: [`outputs/maps/mapa_soja_mg.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_soja_mg.png)

### 2.3 Autocorrelação Espacial Global (Índice de Moran)
A matriz de pesos espaciais $W$ foi construída utilizando os 6 vizinhos mais próximos ($k=6$) padronizada por linhas:
- **Índice de Moran Global ($I$)**: **$0{,}5617$**
- **Valor Esperado sob $H_0$ ($E[I]$)**: $-0{,}0012$
- **Estatística $z$ ($z$-score)**: **$29{,}72$** ($p < 10^{-15}$)
- **Interpretação**: Existe uma forte e estatisticamente significativa dependência espacial positiva na votação. Municípios com alta votação de Flávio estão fortemente cercados por municípios também com alta votação (efeito de contágio/vizinhança regional).
- Gráfico: [`outputs/figures/moran_scatterplot_votos.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/figures/moran_scatterplot_votos.png)

### 2.4 Modelo Econométrico Linear (OLS)
Regressão linear múltipla estimada por Mínimos Quadrados Ordinários:

$$\text{Pct\_Voto\_Flavio}_i = \beta_0 + \beta_1 \log(1 + \text{Soja\_Ton}_i) + \beta_2 \text{Dummy\_Soja}_i + \beta_3 \text{Share\_Agro}_i + \beta_4 \log(\text{PIB\_Total}_i) + \varepsilon_i$$

| Termo | Coeficiente | Erro Padrão | Estatística $t$ | $p$-valor | Significância |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Intercepto** | $-2{,}8357$ | $0{,}7224$ | $-3{,}925$ | $9{,}36 \times 10^{-5}$ | *** |
| **Dummy Soja (`tem_soja`)** | **$+1{,}4391$** | $0{,}5015$ | **$+2{,}869$** | **$0{,}0042$** | **\*\*** |
| **$\log(\text{Soja} + 1)$** | $-0{,}1117$ | $0{,}0604$ | $-1{,}849$ | $0{,}0649$ | . |
| **Share Agro no PIB (`share_agro_pct`)** | $-0{,}0064$ | $0{,}0054$ | $-1{,}178$ | $0{,}2390$ |  |
| **$\log(\text{PIB Total})$** | **$+0{,}6515$** | $0{,}0554$ | **$+11{,}753$** | **$< 2 \times 10^{-16}$** | *** |

- **$R^2$**: $0{,}2403$ ($R^2$ ajustado: $0{,}2367$)
- **Estatística $F$**: $67{,}05$ ($p < 2{,}2 \times 10^{-16}$)
- **Achado Principal**: O cultivo de soja tem impacto positivo e altamente significativo ($+1{,}44$ pontos percentuais na votação do candidato, $p = 0{,}0042$), assim como o porte econômico e industrial do município ($p < 0{,}001$).

### 2.5 Análise dos Resíduos e Dependência Espacial Residual
- Extração do resíduo de estimação: $e_i = y_i - \hat{y}_i$.
- **Índice de Moran nos Resíduos ($I_{\text{res}}$)**: **$0{,}5675$**
- **$z$-score dos Resíduos**: **$30{,}03$** ($p < 10^{-15}$)
- **Diagnóstico Espacial**: Os resíduos da regressão linear OLS violam frontalmente o pressuposto de independência ($\text{Cov}(e_i, e_j) \ne 0$), mantendo forte correlação espacial não explicada pelas variáveis exógenas.
- **Recomendação Metodológica**: Faz-se imperativo o uso de modelos autorregressivos espaciais (como o **Spatial Error Model - SEM** ou **Spatial Lag Model - SAR**) para corrigir erros padrão viesados e incorporar o processo gerador espacial subjacente.
- Mapa dos Resíduos: [`outputs/maps/mapa_residuos_regressao.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/maps/mapa_residuos_regressao.png)
- Moran Scatterplot dos Resíduos: [`outputs/figures/moran_scatterplot_residuos.png`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs/figures/moran_scatterplot_residuos.png)

---

## 3. Como Reproduzir

### 1. Preparar e unificar dados oficiais (TSE + IBGE)
```bash
python3 eleicao/data/prepara_dados.py
```

### 2. Executar análise espacial completa no R
```bash
Rscript eleicao/R/analise_espacial_eleicao.R
```
Todos os mapas, gráficos e diagnósticos em alta resolução serão salvos na pasta [`outputs/`](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/outputs).
