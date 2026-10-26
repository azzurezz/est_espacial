# Dados do Projeto: Estatística Espacial Eleitoral

Esta pasta armazena os dados brutos e tratados utilizados nas análises espaciais de resultados eleitorais.

## Estrutura

- `raw/`: Dados brutos obtidos diretamente das fontes oficiais (ex.: arquivos CSV do TSE, shapefiles originais). **Não devem ser alterados manualmente**.
- `processed/`: Bases limpas, agregadas (por município, zona eleitoral ou setor censitário) e já unificadas às geometrias espaciais (`.gpkg`, `.rds`, `.parquet` ou `.csv`).

## Principais Fontes de Dados

1. **Tribunal Superior Eleitoral (TSE)**
   - [Portal de Dados Abertos do TSE](https://dadosabertos.tse.jus.br/)
   - Resultados de votação por município e zona eleitoral (boletins de urna, perfil do eleitorado, votação nominal).
2. **IBGE / Pacote `geobr`**
   - Malhas municipais, estaduais e de setores censitários do Brasil.
   - Variáveis socioeconômicas (Censo Demográfico) para controle econométrico.
3. **CEPESP Data / Base dos Dados**
   - Bases eleitorais históricas limpas e padronizadas por código de município IBGE.
