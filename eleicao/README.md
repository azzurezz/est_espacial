# Estatística Espacial Aplicada a Dados Eleitorais

Este projeto é dedicado à investigação, modelagem e visualização espacial do comportamento eleitoral, padrões de votação e determinantes socioespaciais no Brasil utilizando **R**.

---

## Objetivos do Projeto

1. **Análise Exploratória de Dados Espaciais (ESDA)**:
   - Identificar padrões de concentração espacial, fragmentação e segregação do voto.
   - Mapear o desempenho de partidos, coligações ou candidatos em diferentes escalas geográficas (municípios, zonas eleitorais, estados).

2. **Detecção de Autocorrelação Espacial e Clusters**:
   - Construção de matrizes de ponderação espacial ($W$) por contiguidade (Rainha/Torre) e por distância ($k$-vizinhos mais próximos ou decaimento inverso).
   - Cálculo do **Índice de Moran Global** para verificar a presença de dependência espacial na distribuição dos votos.
   - Identificação de clusters locais e outliers com **LISA** (*Local Indicators of Spatial Association*): Alto-Alto, Baixo-Baixo, Alto-Baixo, Baixo-Alto.

3. **Modelagem Econométrica Espacial**:
   - Modelos de regressão linear clássica (OLS) com diagnósticos de dependência espacial residual (testes dos Multiplicadores de Lagrange - LM).
   - Estimação de modelos espaciais:
     - **Spatial Autoregressive Model (SAR / Spatial Lag)**: Efeito de contágio ou transbordamento direto entre vizinhos.
     - **Spatial Error Model (SEM)**: Dependência espacial capturada nos termos de erro não observados.
     - **Spatial Durbin Model (SDM)**: Efeitos espaciais tanto na variável resposta quanto nas variáveis explicativas.

---

## Estrutura do Diretório `eleicao/`

```text
eleicao/
├── README.md                 # Documentação e objetivos do projeto
├── R/                        # Scripts de análise, processamento e modelagem
│   └── 00_setup_packages.R   # Script de setup e verificação de pacotes R
├── data/                     # Dados eleitorais e malhas geoespaciais
│   ├── raw/                  # Dados brutos originais do TSE / IBGE
│   ├── processed/            # Bases tratadas e vinculadas aos dados espaciais
│   └── README.md             # Guia de fontes e download das bases
└── outputs/                  # Resultados gerados pelas análises
    ├── maps/                 # Mapas coropléticos e cartogramas temáticos
    └── figures/              # Gráficos de dispersão de Moran e diagnósticos
```

---

## Fluxo de Trabalho Recomendado

1. **Ambiente**: Execute `Rscript R/00_setup_packages.R` para garantir todas as bibliotecas instaladas.
2. **Dados**: Download e unificação dos dados de votação do TSE aos códigos de município IBGE (`geobr`).
3. **Exploração**: Mapas temáticos de proporção de votos válidos e cálculo da matriz de vizinhança $W$.
4. **Modelagem**: Testes LM e ajuste dos modelos SAR/SEM para explicar os determinantes do voto.
