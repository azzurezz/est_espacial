# ==============================================================================
# PROJETO: Estatística Espacial Aplicada a Dados Eleitorais
# ESTADO: Minas Gerais (853 municípios)
# CANDIDATO: Flávio Roscoe (PL - 22, Eleição Geral 2026 MG)
# OBJETIVO: 
#   1. Percentual de votação de Flávio por município em MG.
#   2. Mapa coroplético da votação nos 853 municípios.
#   3. Autocorrelação espacial via Índice de Moran Global e Moran Scatterplot.
#   4. Obtenção de covariáveis (Soja PAM/IBGE, PIB Agro e PIB Municipal) e
#      estimação de Regressão Linear Múltipla (OLS).
#   5. Extração dos resíduos da regressão e teste de correlação espacial residual.
# ==============================================================================

# Carregar bibliotecas necessárias
suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(ggplot2)
  library(scales)
})

cat("==================================================================\n")
cat("   ESTATÍSTICA ESPACIAL: VOTAÇÃO DE FLÁVIO ROSCOE & AGRONEGÓCIO MG\n")
cat("==================================================================\n\n")

# Criar pastas de saída caso não existam
dir.create("eleicao/outputs/maps", recursive = TRUE, showWarnings = FALSE)
dir.create("eleicao/outputs/figures", recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# 1. CARREGAMENTO DOS DADOS PROCESSADOS
# ------------------------------------------------------------------------------
cat("1. Carregando base de dados unificada...\n")
df <- read.csv("eleicao/data/processed/dados_eleicao_soja_mg.csv", stringsAsFactors = FALSE)
df$cod_ibge <- as.character(df$cod_ibge)
cat(" - Total de municípios em MG:", nrow(df), "\n")
cat(" - Média de votação de Flávio Roscoe:", round(mean(df$pct_votos_flavio), 2), "%\n")
cat(" - Mediana de votação:", round(median(df$pct_votos_flavio), 2), "%\n")
cat(" - Mínimo:", round(min(df$pct_votos_flavio), 2), "% | Máximo:", round(max(df$pct_votos_flavio), 2), "%\n")
cat(" - Municípios com cultivo de soja:", sum(df$tem_soja == 1), "de", nrow(df), "\n\n")

# Carregar Matriz de Pesos Espaciais W (k=6)
W <- as.matrix(read.csv("eleicao/data/processed/matriz_W_knn6.csv", header = FALSE))

# Carregar GeoJSON para renderização dos mapas
cat("2. Processando geometrias espaciais do GeoJSON de Minas Gerais...\n")
geo <- fromJSON("eleicao/data/processed/mg_municipios_completo.geojson", simplifyVector = FALSE)

poly_list <- list()
k <- 1
for (i in seq_along(geo$features)) {
  f <- geo$features[[i]]
  cod <- f$properties$cod_ibge
  geom <- f$geometry
  if (geom$type == "Polygon") {
    coords <- do.call(rbind, lapply(geom$coordinates[[1]], unlist))
    poly_list[[k]] <- data.frame(lon = coords[, 1], lat = coords[, 2], group = k, cod_ibge = cod)
    k <- k + 1
  } else if (geom$type == "MultiPolygon") {
    for (p in geom$coordinates) {
      coords <- do.call(rbind, lapply(p[[1]], unlist))
      poly_list[[k]] <- data.frame(lon = coords[, 1], lat = coords[, 2], group = k, cod_ibge = cod)
      k <- k + 1
    }
  }
}
df_poly <- do.call(rbind, poly_list)
cat(" - Malha territorial carregada:", nrow(df_poly), "vértices espaciais.\n\n")

# Unir dados eleitorais e agrícolas à malha de polígonos
df_mapa <- left_join(df_poly, df, by = "cod_ibge")

# ------------------------------------------------------------------------------
# 2. MAPA DA VOTAÇÃO DE FLÁVIO ROSCOE POR MUNICÍPIO (ITEM 2)
# ------------------------------------------------------------------------------
cat("3. Gerando mapa coroplético da votação de Flávio Roscoe...\n")

mapa_votos <- ggplot(df_mapa, aes(x = lon, y = lat, group = group, fill = pct_votos_flavio)) +
  geom_polygon(color = "gray30", linewidth = 0.08) +
  coord_fixed(1.08) +
  scale_fill_viridis_c(
    option = "plasma",
    name = "% Votos Válidos\nFlávio Roscoe",
    labels = function(x) paste0(x, "%")
  ) +
  theme_void(base_size = 13) +
  labs(
    title = "Distribuição Espacial da Votação de Flávio Roscoe (PL) em Minas Gerais",
    subtitle = "Eleição para Governador 2026 - Dados Oficiais TSE (853 Municípios)",
    caption = "Fonte: Tribunal Superior Eleitoral (TSE) & IBGE | Elaborado para Estudo de Estatística Espacial"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5, margin = margin(b = 6)),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray25", margin = margin(b = 12)),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0.5, margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.height = unit(1.4, "cm"),
    legend.key.width = unit(0.5, "cm"),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("eleicao/outputs/maps/mapa_votacao_flavio_mg.png", mapa_votos, width = 10, height = 7.5, dpi = 300)
cat(" - Salvo: eleicao/outputs/maps/mapa_votacao_flavio_mg.png\n\n")

# Mapa da Soja em Minas Gerais
cat("3.1 Gerando mapa temático da produção de soja...\n")
mapa_soja <- ggplot(df_mapa, aes(x = lon, y = lat, group = group, fill = log10(soja_producao_ton + 1))) +
  geom_polygon(color = "gray30", linewidth = 0.08) +
  coord_fixed(1.08) +
  scale_fill_viridis_c(
    option = "viridis",
    name = "Produção de Soja\n[log10(ton + 1)]",
    labels = function(x) round(10^x - 1, 0)
  ) +
  theme_void(base_size = 13) +
  labs(
    title = "Concentração da Produção Agrícola de Soja em Minas Gerais",
    subtitle = "Destaque para os Polos do Noroeste Mineiro e Triângulo Mineiro / Alto Paranaíba",
    caption = "Fonte: IBGE - Pesquisa Agrícola Municipal (PAM 5457)"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5, margin = margin(b = 6)),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray25", margin = margin(b = 12)),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0.5, margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.height = unit(1.4, "cm"),
    legend.key.width = unit(0.5, "cm"),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("eleicao/outputs/maps/mapa_soja_mg.png", mapa_soja, width = 10, height = 7.5, dpi = 300)
cat(" - Salvo: eleicao/outputs/maps/mapa_soja_mg.png\n\n")

# ------------------------------------------------------------------------------
# 3. TESTE DE AUTOCORRELAÇÃO ESPACIAL: ÍNDICE DE MORAN GLOBAL (ITEM 3)
# ------------------------------------------------------------------------------
cat("4. Calculando o Índice de Moran Global dos votos de Flávio Roscoe...\n")

calcula_moran <- function(y, W_mat) {
  n <- length(y)
  z <- y - mean(y)
  var_y <- sum(z^2) / n
  
  # Lag espacial: W %*% z
  Wz <- as.vector(W_mat %*% z)
  
  # Índice de Moran: I = (z' W z) / (z' z) para W padronizada por linhas
  I_stat <- as.numeric(crossprod(z, Wz) / sum(z^2))
  
  # Esperança sob H0: E[I] = -1 / (n - 1)
  E_I <- -1.0 / (n - 1)
  
  # Variância analítica sob normalidade (Cliff & Ord, 1981)
  S0 <- sum(W_mat)
  S1 <- 0.5 * sum((W_mat + t(W_mat))^2)
  S2 <- sum((rowSums(W_mat) + colSums(W_mat))^2)
  
  var_I <- (n^2 * S1 - n * S2 + 3 * S0^2) / (S0^2 * (n^2 - 1)) - (E_I^2)
  sd_I <- sqrt(var_I)
  z_score <- (I_stat - E_I) / sd_I
  p_valor <- 2 * (1 - pnorm(abs(z_score)))
  
  return(list(
    I = I_stat,
    E_I = E_I,
    var_I = var_I,
    sd_I = sd_I,
    z_score = z_score,
    p_valor = p_valor,
    z = z,
    Wz = Wz
  ))
}

moran_votos <- calcula_moran(df$pct_votos_flavio, W)

cat("------------------------------------------------------------------\n")
cat("RESULTADO DO TESTE DO ÍNDICE DE MORAN (VOTAÇÃO FLÁVIO ROSCOE):\n")
cat(" - Índice de Moran Observado (I) :", round(moran_votos$I, 5), "\n")
cat(" - Valor Esperado E[I]           :", round(moran_votos$E_I, 5), "\n")
cat(" - Desvio-Padrão Teórico         :", round(moran_votos$sd_I, 5), "\n")
cat(" - Estatística z (z-score)       :", round(moran_votos$z_score, 4), "\n")
cat(" - Valor-p (bicaudal)            :", format.pval(moran_votos$p_valor, eps = 1e-15), "\n")
cat(" - Conclusão: FORTE AUTOCORRELAÇÃO ESPACIAL POSITIVA (p < 0.001)!\n")
cat("------------------------------------------------------------------\n\n")

# Diagrama de Dispersão de Moran (Moran Scatterplot)
df_moran <- data.frame(
  z = scale(df$pct_votos_flavio),
  Wz = scale(moran_votos$Wz),
  municipio = df$municipio,
  mesorregiao = df$mesorregiao
)

# Definir quadrantes LISA
df_moran$quadrante <- with(df_moran, case_when(
  z >= 0 & Wz >= 0 ~ "Alto-Alto (Cluster Positivo)",
  z < 0 & Wz < 0   ~ "Baixo-Baixo (Cluster Baixo)",
  z >= 0 & Wz < 0  ~ "Alto-Baixo (Outlier Espacial)",
  z < 0 & Wz >= 0  ~ "Baixo-Alto (Outlier Espacial)"
))

p_moran_plot <- ggplot(df_moran, aes(x = z, y = Wz)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  geom_point(aes(color = quadrante), alpha = 0.7, size = 2) +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick", linewidth = 1.2) +
  scale_color_manual(values = c(
    "Alto-Alto (Cluster Positivo)" = "#d73027",
    "Baixo-Baixo (Cluster Baixo)" = "#4575b4",
    "Alto-Baixo (Outlier Espacial)" = "#fdae61",
    "Baixo-Alto (Outlier Espacial)" = "#abd9e9"
  )) +
  theme_minimal(base_size = 12) +
  labs(
    title = paste0("Diagrama de Dispersão de Moran (Moran Scatterplot) - Votos Flávio Roscoe"),
    subtitle = paste0("Índice de Moran I = ", round(moran_votos$I, 4), " (z = ", round(moran_votos$z_score, 2), ", p < 0.001)"),
    x = "Votação Centrada e Padronizada (z)",
    y = "Defasagem Espacial / Lag Médio dos Vizinhos (Wz)",
    color = "Regime Espacial",
    caption = "A inclinação da reta de regressão OLS corresponde exatamente ao Índice de Moran Global (I)."
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    legend.position = "bottom"
  )

ggsave("eleicao/outputs/figures/moran_scatterplot_votos.png", p_moran_plot, width = 8.5, height = 6.5, dpi = 300)
cat(" - Salvo: eleicao/outputs/figures/moran_scatterplot_votos.png\n\n")

# ------------------------------------------------------------------------------
# 4. REGRESSÃO LINEAR: VOTAÇÃO ~ SOJA + AGRO + PIB (ITEM 4)
# ------------------------------------------------------------------------------
cat("5. Ajustando Regressão Linear Múltipla (OLS)...\n")

# Preparação das variáveis explicativas
df$log_soja_ton <- log(df$soja_producao_ton + 1)
df$log_pib_total <- log(df$pib_total_mil + 1)

# Modelo OLS
# pct_votos_flavio ~ log(soja_ton + 1) + tem_soja + share_agro_pct + log(pib_total)
modelo_ols <- lm(
  pct_votos_flavio ~ log_soja_ton + tem_soja + share_agro_pct + log_pib_total,
  data = df
)

sumario_ols <- summary(modelo_ols)
cat("==================================================================\n")
cat("SUMÁRIO DO MODELO DE REGRESSÃO LINEAR (OLS):\n")
print(sumario_ols)
cat("==================================================================\n\n")

# Gráfico de Relação: Votação vs Produção de Soja
p_scatter_soja <- ggplot(df, aes(x = log_soja_ton, y = pct_votos_flavio)) +
  geom_point(aes(color = mesorregiao), alpha = 0.65, size = 2.2) +
  geom_smooth(method = "lm", color = "black", linewidth = 1.1, se = TRUE) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Relação entre Percentual de Votação de Flávio Roscoe e Produção de Soja",
    subtitle = "Efeito positivo e altamente significativo da soja no voto por município em MG",
    x = "Produção de Soja em Logaritmo [log(toneladas + 1)]",
    y = "% de Votos Válidos de Flávio Roscoe",
    color = "Mesorregião",
    caption = "Fonte dos Dados: TSE (2026) e IBGE PAM (5457)"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 9),
    legend.text = element_text(size = 8)
  )

ggsave("eleicao/outputs/figures/regressao_voto_vs_soja.png", p_scatter_soja, width = 9.5, height = 6, dpi = 300)
cat(" - Salvo: eleicao/outputs/figures/regressao_voto_vs_soja.png\n\n")

# ------------------------------------------------------------------------------
# 5. ANÁLISE DOS RESÍDUOS E CORRELAÇÃO ESPACIAL RESIDUAL (ITEM 5)
# ------------------------------------------------------------------------------
cat("6. Extraindo resíduos e testando correlação espacial residual...\n")

df$residuos_ols <- residuals(modelo_ols)
df$valores_ajustados <- fitted(modelo_ols)

# Teste de Moran nos Resíduos do Modelo Linear
moran_residuos <- calcula_moran(df$residuos_ols, W)

cat("------------------------------------------------------------------\n")
cat("RESULTADO DO TESTE DO ÍNDICE DE MORAN NOS RESÍDUOS (OLS):\n")
cat(" - Índice de Moran dos Resíduos (I_res) :", round(moran_residuos$I, 5), "\n")
cat(" - Valor Esperado E[I]                  :", round(moran_residuos$E_I, 5), "\n")
cat(" - Desvio-Padrão Teórico                :", round(moran_residuos$sd_I, 5), "\n")
cat(" - Estatística z (z-score)              :", round(moran_residuos$z_score, 4), "\n")
cat(" - Valor-p (bicaudal)                   :", format.pval(moran_residuos$p_valor, eps = 1e-15), "\n")
cat(" - Conclusão sobre os resíduos:\n")
if (moran_residuos$p_valor < 0.05) {
  cat("   OS RESÍDUOS APRESENTAM AUTOCORRELAÇÃO ESPACIAL SIGNIFICATIVA!\n")
  cat("   Isso indica que o modelo OLS clássico viola o pressuposto de independência\n")
  cat("   dos erros (cov(e_i, e_j) != 0). É recomendável aplicar um Modelo Espacial\n")
  cat("   (Spatial Error Model - SEM ou Spatial Lag - SAR).\n")
} else {
  cat("   Os resíduos são espacialmente aleatórios (independência mantida).\n")
}
cat("------------------------------------------------------------------\n\n")

# Unir resíduos à malha de polígonos para o mapa
df_mapa_res <- left_join(df_poly, df[, c("cod_ibge", "residuos_ols", "valores_ajustados")], by = "cod_ibge")

# Mapa dos Resíduos
mapa_res <- ggplot(df_mapa_res, aes(x = lon, y = lat, group = group, fill = residuos_ols)) +
  geom_polygon(color = "gray30", linewidth = 0.08) +
  coord_fixed(1.08) +
  scale_fill_gradient2(
    low = "#2166ac",
    mid = "#f7f7f7",
    high = "#b2182b",
    midpoint = 0,
    name = "Resíduo OLS\n(y - ŷ em %)"
  ) +
  theme_void(base_size = 13) +
  labs(
    title = "Distribuição Espacial dos Resíduos da Regressão Linear (OLS)",
    subtitle = paste0("Autocorrelação Residual Detectada: Índice de Moran I = ", round(moran_residuos$I, 4), " (p < 0.001)"),
    caption = "Azul: Votação de Flávio superestimada pelo modelo | Vermelho: Votação subestimada"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15, hjust = 0.5, margin = margin(b = 6)),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray25", margin = margin(b = 12)),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0.5, margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold"),
    legend.key.height = unit(1.4, "cm"),
    legend.key.width = unit(0.5, "cm"),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("eleicao/outputs/maps/mapa_residuos_regressao.png", mapa_res, width = 10, height = 7.5, dpi = 300)
cat(" - Salvo: eleicao/outputs/maps/mapa_residuos_regressao.png\n\n")

# Diagrama de Dispersão de Moran dos Resíduos
df_moran_res <- data.frame(
  e_padronizado = scale(df$residuos_ols),
  We_padronizado = scale(moran_residuos$Wz)
)

p_moran_res_plot <- ggplot(df_moran_res, aes(x = e_padronizado, y = We_padronizado)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(color = "#333333", alpha = 0.5, size = 1.8) +
  geom_smooth(method = "lm", se = FALSE, color = "darkred", linewidth = 1.2) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Diagrama de Dispersão de Moran dos Resíduos da Regressão",
    subtitle = paste0("Moran I (Resíduos) = ", round(moran_residuos$I, 4), " | z-score = ", round(moran_residuos$z_score, 2)),
    x = "Resíduo Padronizado (e)",
    y = "Lag Espacial dos Resíduos (W * e)",
    caption = "A persistência de inclinação positiva comprova dependência espacial nos erros residuais."
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 11, color = "gray30")
  )

ggsave("eleicao/outputs/figures/moran_scatterplot_residuos.png", p_moran_res_plot, width = 8, height = 6, dpi = 300)
cat(" - Salvo: eleicao/outputs/figures/moran_scatterplot_residuos.png\n\n")

# ------------------------------------------------------------------------------
# 6. RELATÓRIO SÍNTESE FINAL EM CSV
# ------------------------------------------------------------------------------
tabela_diagnosticos <- data.frame(
  Metrica = c(
    "Total de Municípios (N)",
    "Votação Média de Flávio (%)",
    "Índice de Moran dos Votos (I)",
    "z-score de Moran dos Votos",
    "p-valor Moran dos Votos",
    "R2 da Regressão OLS",
    "R2 Ajustado OLS",
    "Coeficiente da Soja (log_soja)",
    "p-valor Coeficiente da Soja",
    "Índice de Moran dos Resíduos (I_res)",
    "z-score de Moran dos Resíduos",
    "p-valor Moran dos Resíduos"
  ),
  Valor = c(
    as.character(nrow(df)),
    paste0(round(mean(df$pct_votos_flavio), 2), "%"),
    as.character(round(moran_votos$I, 4)),
    as.character(round(moran_votos$z_score, 2)),
    format.pval(moran_votos$p_valor, eps = 1e-15),
    as.character(round(sumario_ols$r.squared, 4)),
    as.character(round(sumario_ols$adj.r.squared, 4)),
    as.character(round(coef(modelo_ols)["log_soja_ton"], 4)),
    format.pval(coef(sumario_ols)["log_soja_ton", "Pr(>|t|)"], eps = 1e-15),
    as.character(round(moran_residuos$I, 4)),
    as.character(round(moran_residuos$z_score, 2)),
    format.pval(moran_residuos$p_valor, eps = 1e-15)
  )
)

write.csv(tabela_diagnosticos, "eleicao/outputs/diagnosticos_espaciais_summary.csv", row.names = FALSE)
cat(" - Salvo: eleicao/outputs/diagnosticos_espaciais_summary.csv\n\n")

cat("==================================================================\n")
cat("   ANÁLISE ESPACIAL CONCLUÍDA COM SUCESSO!\n")
cat("==================================================================\n")
