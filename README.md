# Estudos de Estatística Espacial: Estimação de Parâmetros e Variogramas

Este repositório contém estudos, experimentos e simulações na área de Estatística Espacial e Geestatística em R.

O projeto envolve desde a análise exploratória de dados espaciais (dataset Meuse) até estudos avançados de Simulação Monte Carlo para avaliar a acurácia e eficiência de métodos de estimação de parâmetros de covariância baseados no variograma empírico (WLS, OLS) e na Máxima Verossimilhança Restrita (REML), acompanhados de uma Apresentação Gerencial/Acadêmica em LaTeX Beamer.

Referência principal: Moraga, P. (2023). Spatial Statistics for Data Science: Theory and Practice with R, Capítulo 14 (Kriging).

---

## Estrutura do Repositório

```text
est_espacial/
├── README.md                     # Documentação principal e guia do repositório
├── LICENSE                       # Licença do repositório
├── .gitignore                    # Regras de exclusão para R e LaTeX
│
├── R/                            # Scripts de análise e simulação em R
│   ├── install_packages.R        # Script de verificação e instalação das dependências R
│   ├── variograma.R              # Análise exploratória inicial, dataset Meuse e variograma nuvem
│   ├── simulacao_estimacao.R     # Simulação Monte Carlo (N=100) para WLS vs OLS
│   └── simulacao_reml.R          # Simulação Monte Carlo (N=100) para REML vs WLS vs OLS
│
├── data/                         # Arquivos CSV de dados e resultados das simulações
│   ├── sim_results_summary.csv   # Tabela síntese WLS vs OLS
│   ├── sim_results_detailed.csv  # Dados brutos das simulações WLS vs OLS
│   ├── sim_reml_summary.csv      # Tabela síntese REML vs WLS vs OLS
│   └── sim_reml_detailed.csv     # Dados brutos das simulações REML vs WLS vs OLS
│
├── plots/                        # Gráficos e visualizações exportadas em PNG
│   ├── exemplo_variograma_ajustado.png  # Exemplo de ajuste de modelos ao variograma empírico
│   ├── boxplot_parametros.png           # Distribuição dos parâmetros estimados (WLS vs OLS)
│   ├── rmse_tamanho_amostral.png        # Evolução do RMSE por tamanho amostral (WLS vs OLS)
│   ├── boxplot_reml_vs_wls.png          # Boxplot comparativo REML vs WLS vs OLS
│   └── rmse_reml_vs_wls.png             # Evolução do RMSE do REML vs WLS vs OLS
│
└── presentation/                 # Apresentação Gerencial/Acadêmica em LaTeX Beamer
    ├── apresentacao_gerencial.tex # Código-fonte LaTeX da apresentação acadêmica
    └── apresentacao_gerencial.pdf # Apresentação compilada em PDF
```

---

## Estudo de Simulação Monte Carlo (WLS vs OLS)

### Objetivo

Avaliar quão precisos são os métodos de estimação baseados no variograma empírico — Mínimos Quadrados Ponderados (WLS) e Mínimos Quadrados Ordinários (OLS) — comparando os parâmetros estimados (tau^2, sigma^2, phi) com os parâmetros verdadeiros utilizados no gerador do Campo Aleatório Gaussiano (GRF).

### Parâmetros Verdadeiros da Simulação

- Nugget / Efeito Pepita (tau^2): 0.20
- Partial Sill / Variância Espacial (sigma^2): 1.00
- Alcance / Range (phi): 20.00 (Modelo Exponencial)
- Tamanhos Amostrais (n): 50, 100, 200 pontos em um domínio [0, 100] x [0, 100]
- Replicações Monte Carlo: N = 100 por cenário (total de 600 ajustes)

---

## Experimento de Máxima Verossimilhança Restrita (REML vs WLS vs OLS)

### Fundamentação Teórica

A Máxima Verossimilhança Restrita (REML) estima os parâmetros de covariância theta = (tau^2, sigma^2, phi) maximizando a verossimilhança no subespaço ortogonal à matriz de desenho X (efeitos fixos/média). Isso elimina o viés de pequena amostra associado à estimativa da média:

l_REML(theta) = -0.5 * log|Sigma| - 0.5 * log|X' Sigma^-1 X| - 0.5 * (y - X beta_hat)' Sigma^-1 (y - X beta_hat) - ((n-p)/2) * log(2 pi)

### Principais Descobertas do REML

1. Acurácia Superior: O método REML reduz drasticamente a superestimativa do alcance (phi) em amostras pequenas (n = 50), apresentando RMSE significativamente inferior a WLS e OLS.
2. Estabilidade do Efeito Pepita: O REML obtém estimativas quase não-viesadas do Nugget (tau^2) mesmo sob n = 50.
3. Eficiência em Amostras Médias/Grandes: Para n >= 100, o REML converge rapidamente para os valores verdadeiros de todos os parâmetros.

---

## Como Executar

### 1. Instalar Dependências R

No terminal:

```bash
Rscript R/install_packages.R
```

### 2. Rodar a Simulação WLS vs OLS

Para rodar as simulações do variograma e atualizar os gráficos na pasta `plots/` e tabelas em `data/`:

```bash
Rscript R/simulacao_estimacao.R
```

### 3. Rodar a Simulação REML vs WLS/OLS

Para executar o experimento comparativo de Máxima Verossimilhança Restrita:

```bash
Rscript R/simulacao_reml.R
```

### 4. Compilar a Apresentação LaTeX (Beamer)

Para gerar o arquivo `apresentacao_gerencial.pdf` localizado na pasta `presentation/`:

```bash
cd presentation && pdflatex -interaction=nonstopmode apresentacao_gerencial.tex
```

---

## Referências

- Moraga, Paula. Spatial Statistics for Data Science: Theory and Practice with R. Chapman and Hall/CRC, 2023.
- Pebesma, E.J., 2004. Multivariable geostatistics in S: the gstat package. Computers & Geosciences, 30(7), pp.683-691.
- Cressie, N., 1993. Statistics for Spatial Data. John Wiley & Sons.
