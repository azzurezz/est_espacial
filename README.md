# Estudos de Estatística Espacial

Este repositório reúne pesquisas, simulações computacionais e aplicações práticas na área de **Estatística Espacial** em R, cobrindo tanto a vertente de **Geoestatística / Dados Pontuais Contínuos** quanto a de **Dados de Área (Areal Data) / Econometria Espacial**.

O repositório é estruturado em subprojetos modulares:

---

## Estrutura do Repositório

```text
est_espacial/
├── README.md             # Visão geral do repositório e índice dos projetos
├── LICENSE               # Licença do repositório
├── .gitignore            # Regras de exclusão para R, LaTeX e saídas de dados
│
├── modelos/              # [Subprojeto 1] Geoestatística e Métodos de Estimação
│   ├── README.md         # Documentação técnica detalhada das simulações
│   ├── R/                # Scripts de simulação Monte Carlo e variograma empírico
│   │   ├── install_packages.R
│   │   ├── variograma.R
│   │   ├── simulacao_estimacao.R
│   │   └── simulacao_reml.R
│   ├── data/             # Resultados em CSV das simulações WLS, OLS e REML
│   └── presentation/     # Apresentação gerencial em LaTeX Beamer com gráficos
│       ├── apresentacao_gerencial.tex
│       ├── apresentacao_gerencial.pdf
│       └── plots/
│
└── eleicao/              # [Subprojeto 2] Estatística Espacial Aplicada a Dados Eleitorais
    ├── README.md         # Objetivos, metodologia e guia de dados do projeto eleitoral
    ├── R/                # Scripts de análise e processamento de dados eleitorais
    │   └── 00_setup_packages.R
    ├── data/             # Bases brutas (raw) e tratadas (processed)
    │   ├── raw/
    │   └── processed/
    └── outputs/          # Mapas coropléticos e visualizações geradas
        ├── maps/
        └── figures/
```

---

## Visão Geral dos Projetos

### 1. `modelos/` — Geoestatística e Estimação de Parâmetros de Covariância

Estudo comparativo de precisão e eficiência computacional entre métodos de estimação de parâmetros de campos aleatórios gaussianos (nugget $\tau^2$, variância espacial $\sigma^2$ e alcance $\phi$):
- **Abordagens**: Mínimos Quadrados Ordinários (OLS), Mínimos Quadrados Ponderados (WLS) e Máxima Verossimilhança Restrita (REML).
- **Simulação Monte Carlo**: $N = 100$ replicações sob diferentes tamanhos amostrais ($n \in \{50, 100, 200\}$).
- **Apresentação**: Slides gerenciais e acadêmicos compilados em LaTeX Beamer com visualizações em alta resolução.
- Consulte [modelos/README.md](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/modelos/README.md) para detalhes teóricos e instruções de execução.

### 2. `eleicao/` — Estatística Espacial Aplicada a Dados Eleitorais

Análise do comportamento e distribuição geográfica dos votos no Brasil utilizando métodos de dados de área (*Areal Data*):
- **Análise Exploratória de Dados Espaciais (ESDA)** e confecção de mapas temáticos com `sf`, `geobr` e `tmap`.
- **Autocorrelação Espacial**: Matrizes de contiguidade espacial $W$, teste do **I de Moran Global** e mapeamento de clusters locais (**LISA**).
- **Modelos Espaciais**: Modelos autorregressivos espaciais (*Spatial Lag* / SAR e *Spatial Error* / SEM) para compreender fatores contextuais e transbordamento geográfico da votação.
- Consulte [eleicao/README.md](file:///home/thayn-alves/%C3%81rea%20de%20trabalho/estudos/est_espacial/eleicao/README.md) para detalhes.

---

## Requisitos de Sistema

- **R** >= 4.1.0
- Pacotes R principais: `gstat`, `geoR`, `sf`, `spdep`, `spatialreg`, `geobr`, `tidyverse`
- Para compilar os slides em Beamer: Distribuição LaTeX (`pdflatex` / TeX Live)
