pkgs <- c("gstat", "geoR", "sf", "ggplot2", "dplyr", "tidyr", "gridExtra")
missing_pkgs <- pkgs[!(pkgs %in% installed.packages()[, "Package"])]

if (length(missing_pkgs) > 0) {
  cat("Instalando pacotes ausentes:", paste(missing_pkgs, collapse = ", "), "\n")
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
} else {
  cat("Todos os pacotes necessários já estão instalados!\n")
}

# Testar se todos os pacotes carregam com sucesso
for (pkg in pkgs) {
  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
  cat("Pacote carregado com sucesso:", pkg, "\n")
}
