# ==============================================================================
# Projeto: Estatística Espacial Aplicada a Dados Eleitorais
# Script: 00_setup_packages.R
# Objetivo: Instalação e verificação de pacotes necessários para análise
#           espacial de dados de área (Areal Data Analysis) e mapas eleitorais.
# ==============================================================================

pacotes_necessarios <- c(
  # Manipulação e visualização de dados
  "tidyverse",    # dplyr, ggplot2, tidyr, readr, purrr
  "scales",       # Formatação de escalas e porcentagens nos gráficos
  
  # Dados espaciais e geoprocessamento
  "sf",           # Simple Features para manipulação vetorial geoespacial
  "geobr",        # Download oficial de malhas territoriais do IBGE
  
  # Estatística espacial de área (Areal Data / Econometria Espacial)
  "spdep",        # Matrizes de vizinhança (W), I de Moran global e local (LISA)
  "spatialreg",   # Modelos autorregressivos espaciais (SAR, SEM, SDM, SAC)
  
  # Visualização cartográfica e mapas temáticos
  "tmap",         # Mapas coropléticos temáticos elegantes
  "viridis"       # Paletas de cores acessíveis e contínuas/perceptualmente uniformes
)

cat("Verificando e instalando pacotes necessários...\n")

pacotes_faltantes <- pacotes_necessarios[!(pacotes_necessarios %in% installed.packages()[, "Package"])]

if (length(pacotes_faltantes) > 0) {
  cat("Instalando pacotes faltantes:", paste(pacotes_faltantes, collapse = ", "), "\n")
  install.packages(pacotes_faltantes, dependencies = TRUE)
} else {
  cat("Todos os pacotes já estão instalados!\n")
}

cat("\nCarregando bibliotecas essenciais para teste:\n")
for (pkg in c("sf", "spdep", "tidyverse")) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  cat(" -", pkg, ": OK (versão", as.character(packageVersion(pkg)), ")\n")
}

cat("\nAmbiente pronto para o projeto 'eleicao'.\n")
