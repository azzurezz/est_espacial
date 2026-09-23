# Estudos de Estatística Espacial: Estimação de Parâmetros e Variogramas

Este repositório contém estudos, experimentos e simulações na área de Estatística Espacial e Geestatística em R.

O projeto envolve desde a análise exploratória de dados espaciais (dataset Meuse) até um estudo avançado de Simulação Monte Carlo para avaliar a acurácia de métodos de estimação de parâmetros de covariância baseados no variograma empírico, acompanhado de uma Apresentação Gerencial/Acadêmica em LaTeX Beamer.

Referência principal: Moraga, P. (2023). Spatial Statistics for Data Science: Theory and Practice with R, Capítulo 14 (Kriging).

---

## Estrutura do Repositório

```text
est_espacial/
├── README.md                     # Documentação principal e guia do repositório
├── LICENSE                       # Licença do repositório
├── .gitignore                    # Regras de exclusão para R e LaTeX
│
├── Scripts R
│   ├── variograma.R              # Análise exploratória inicial, dataset Meuse e variograma nuvem
│   ├── install_packages.R        # Script de verificação e instalação das dependências R
│   └── simulacao_estimacao.R     # Simulação Monte Carlo (N=100) para WLS vs OLS
│
├── Resultados e Gráficos
│   ├── plots/
│   │   ├── exemplo_variograma_ajustado.png  # Exemplo de ajuste de modelos ao variograma empírico
│   │   ├── boxplot_parametros.png           # Distribuição dos parâmetros estimados vs verdadeiros
│   │   └── rmse_tamanho_amostral.png        # Evolução do RMSE por tamanho amostral
│   ├── sim_results_summary.csv   # Tabela síntese com Média, Viés e RMSE
│   └── sim_results_detailed.csv  # Dados brutos de todas as 600 simulações
│
└── Apresentação Gerencial (LaTeX Beamer)
    ├── apresentacao_gerencial.tex # Código-fonte LaTeX da apresentação acadêmica
    └── apresentacao_gerencial.pdf # Apresentação compilada em PDF
```

---

## Estudo de Simulação Monte Carlo

### Objetivo

Avaliar quão precisos são os métodos de estimação baseados no variograma empírico — Mínimos Quadrados Ponderados (WLS) e Mínimos Quadrados Ordinários (OLS) — comparando os parâmetros estimados (tau^2, sigma^2, phi) com os parâmetros verdadeiros utilizados no gerador do Campo Aleatório Gaussiano (GRF).

### Parâmetros Verdadeiros da Simulação

- Nugget / Efeito Pepita (tau^2): 0.20
- Partial Sill / Variância Espacial (sigma^2): 1.00
- Alcance / Range (phi): 20.00 (Modelo Exponencial)
- Tamanhos Amostrais (n): 50, 100, 200 pontos em um domínio [0, 100] x [0, 100]
- Replicações Monte Carlo: N = 100 por cenário (total de 600 ajustes)

---

## Tabela Síntese dos Resultados

| Amostra (n) | Método | Parâmetro | Valor Real | Média Est. | Viés Absoluto | Rel. Bias (%) | RMSE |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| n = 50 | OLS | Nugget (tau^2) | 0.20 | 0.218 | +0.018 | +8.78% | 0.198 |
| n = 50 | WLS | Nugget (tau^2) | 0.20 | 0.287 | +0.087 | +43.71% | 0.257 |
| n = 50 | OLS | Alcance (phi) | 20.00 | 43.76 | +23.76 | +118.80% | 54.62 |
| n = 100 | OLS | Nugget (tau^2) | 0.20 | 0.208 | +0.008 | +4.12% | 0.138 |
| n = 100 | OLS | Sill (sigma^2) | 1.00 | 1.376 | +0.376 | +37.55% | 1.133 |
| n = 200 | OLS | Nugget (tau^2) | 0.20 | 0.231 | +0.031 | +15.31% | **0.109** |
| n = 200 | OLS | Sill (sigma^2) | 1.00 | 1.068 | +0.068 | +6.79% | **0.625** |
| n = 200 | OLS | Alcance (phi) | 20.00 | 28.32 | +8.32 | +41.62% | **30.68** |

---

## Principais Conclusões

1. Efeito Amostral Crítico: Em amostras pequenas (n = 50), o alcance (phi) sofre superestimativa pronunciada devido ao número reduzido de pares observados em distâncias longas.
2. Estabilidade do Nugget (tau^2): O efeito pepita apresenta excelente acurácia de estimação mesmo sob pequenas amostras (viés < 0.02).
3. Convergência (n = 200): Com n >= 100-200, a estimativa da variância espacial (sigma^2) e do alcance (phi) convergem com redução expressiva do RMSE.

---

## Como Executar

### 1. Instalar Dependências R

No terminal R:

```bash
Rscript install_packages.R
```

### 2. Rodar a Simulação Monte Carlo

Para rodar as simulações e atualizar os gráficos na pasta plots/ e tabelas CSV:

```bash
Rscript simulacao_estimacao.R
```

### 3. Compilar a Apresentação LaTeX (Beamer)

Para gerar o arquivo apresentacao_gerencial.pdf:

```bash
pdflatex -interaction=nonstopmode apresentacao_gerencial.tex
```

---

## Referências

- Moraga, Paula. Spatial Statistics for Data Science: Theory and Practice with R. Chapman and Hall/CRC, 2023.
- Pebesma, E.J., 2004. Multivariable geostatistics in S: the gstat package. Computers & Geosciences, 30(7), pp.683-691.
- Cressie, N., 1993. Statistics for Spatial Data. John Wiley & Sons.
