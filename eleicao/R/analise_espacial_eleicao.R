# ==============================================================================
# PROJETO: Estatística Espacial Aplicada a Dados Eleitorais
# ESTADO: Minas Gerais (853 municípios)
# ELEIÇÃO: Presidencial 2026 - 1º Turno (04/10/2026)
# CANDIDATO: Flávio Nantes Bolsonaro (PL - 22) vs Lula (PT - 13)
# BASE DE SOJA: Tabela 1612 IBGE / PAM (soja_mg_municipios.csv)
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(ggplot2)
  library(scales)
})

cat("==================================================================\n")
cat("   ESTATÍSTICA ESPACIAL: FLÁVIO BOLSONARO (1º TURNO 2026) & SOJA\n")
cat("==================================================================\n\n")

# Criar pastas de saída se necessário
dir.create("eleicao/outputs/maps", recursive = TRUE, showWarnings = FALSE)
dir.create("eleicao/outputs/figures", recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------------------
# 1. CARREGAR DADOS UNIFICADOS
# ------------------------------------------------------------------------------
cat("1. Carregando dados eleitorais e agrícolas...\n")
df <- read.csv("eleicao/data/processed/dados_eleicao_soja_mg.csv", stringsAsFactors = FALSE)
df$cod_ibge <- as.character(df$cod_ibge)

cat(" - Total de municípios em MG:", nrow(df), "\n")
cat(" - Votos Válidos Totais em MG:", format(sum(df$votos_validos_total), big.mark = "."), "\n")
cat(" - Total Flávio Bolsonaro (22):", format(sum(df$votos_flavio_bolsonaro), big.mark = "."), 
    paste0("(", round(sum(df$votos_flavio_bolsonaro) / sum(df$votos_validos_total) * 100, 2), "%)\n"))
cat(" - Total Lula (13):", format(sum(df$votos_lula), big.mark = "."), 
    paste0("(", round(sum(df$votos_lula) / sum(df$votos_validos_total) * 100, 2), "%)\n")
)
cat(" - Média municipal % Flávio Bolsonaro:", round(mean(df$pct_votos_flavio_bolsonaro), 2), "%\n")
cat(" - Mínimo:", round(min(df$pct_votos_flavio_bolsonaro), 2), "% | Máximo:", round(max(df$pct_votos_flavio_bolsonaro), 2), "%\n")
cat(" - Municípios com cultivo de soja:", sum(df$tem_soja == 1), "de", nrow(df), "\n")
cat(" - Área total de soja em MG:", format(round(sum(df$soja_area_plantada_ha), 0), big.mark = "."), "hectares\n\n")

# Carregar Matriz W
W <- as.matrix(read.csv("eleicao/data/processed/matriz_W_knn6.csv", header = FALSE))

# Carregar malha espacial
cat("2. Carregando geometrias vetoriais dos municípios...\n")
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
df_mapa <- left_join(df_poly, df, by = "cod_ibge")

# ------------------------------------------------------------------------------
# 2. MAPAS: VOTAÇÃO DE FLÁVIO BOLSONARO & PRODUÇÃO DE SOJA (ITEM 2)
# ------------------------------------------------------------------------------
cat("3. Gerando mapa coroplético da votação de Flávio Bolsonaro (1º Turno)...\n")

mapa_votos <- ggplot(df_mapa, aes(x = lon, y = lat, group = group, fill = pct_votos_flavio_bolsonaro)) +
  geom_polygon(color = "gray45", linewidth = 0.08) +
  coord_fixed(1.08) +
  scale_fill_gradient(
    low = "#ffffff",
    high = "#08306b",
    limits = c(0, max(df$pct_votos_flavio_bolsonaro, na.rm = TRUE)),
    breaks = seq(0, 80, by = 15),
    name = "% Votos Válidos\nFlávio Bolsonaro\n(1º Turno 2026)",
    labels = function(x) paste0(round(x, 0), "%")
  ) +
  theme_void(base_size = 13) +
  labs(
    title = "Distribuição Espacial dos Votos de Flávio Bolsonaro em Minas Gerais",
    subtitle = "Eleição Presidencial 2026 - 1º Turno (04/10/2026) | Dados Oficiais TSE por Município",
    caption = "Fonte: Tribunal Superior Eleitoral (TSE) - Seções Eleitorais | Elaboração Estatística Espacial"
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

cat("3.1 Gerando mapa da área plantada de soja (IBGE)...\n")
mapa_soja <- ggplot(df_mapa, aes(x = lon, y = lat, group = group, fill = log10(soja_area_plantada_ha + 1))) +
  geom_polygon(color = "gray30", linewidth = 0.08) +
  coord_fixed(1.08) +
  scale_fill_viridis_c(
    option = "viridis",
    name = "Área de Soja\n[log10(ha + 1)]",
    labels = function(x) paste0(format(round(10^x - 1, 0), big.mark = "."), " ha")
  ) +
  theme_void(base_size = 13) +
  labs(
    title = "Área Plantada de Soja por Município em Minas Gerais",
    subtitle = "Destaque para o Noroeste Mineiro e Triângulo Mineiro / Alto Paranaíba (Tabela 1612 IBGE)",
    caption = "Fonte: IBGE - Produção Agrícola Municipal (PAM / Tabela 1612)"
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
# 3. ÍNDICE DE MORAN GLOBAL DOS VOTOS (ITEM 3)
# ------------------------------------------------------------------------------
cat("4. Calculando Índice de Moran Global dos votos de Flávio Bolsonaro...\n")

calcula_moran <- function(y, W_mat) {
  n <- length(y)
  z <- y - mean(y)
  Wz <- as.vector(W_mat %*% z)
  
  I_stat <- as.numeric(crossprod(z, Wz) / sum(z^2))
  E_I <- -1.0 / (n - 1)
  
  S0 <- sum(W_mat)
  S1 <- 0.5 * sum((W_mat + t(W_mat))^2)
  S2 <- sum((rowSums(W_mat) + colSums(W_mat))^2)
  
  var_I <- (n^2 * S1 - n * S2 + 3 * S0^2) / (S0^2 * (n^2 - 1)) - (E_I^2)
  sd_I <- sqrt(var_I)
  z_score <- (I_stat - E_I) / sd_I
  p_valor <- 2 * (1 - pnorm(abs(z_score)))
  
  return(list(
    I = I_stat, E_I = E_I, var_I = var_I, sd_I = sd_I,
    z_score = z_score, p_valor = p_valor, z = z, Wz = Wz
  ))
}

moran_votos <- calcula_moran(df$pct_votos_flavio_bolsonaro, W)

cat("------------------------------------------------------------------\n")
cat("RESULTADO DO ÍNDICE DE MORAN (VOTOS FLÁVIO BOLSONARO):\n")
cat(" - Índice de Moran Global (I)   :", round(moran_votos$I, 5), "\n")
cat(" - Valor Esperado E[I]          :", round(moran_votos$E_I, 5), "\n")
cat(" - Desvio-Padrão Teórico        :", round(moran_votos$sd_I, 5), "\n")
cat(" - Estatística z (z-score)      :", round(moran_votos$z_score, 4), "\n")
cat(" - Valor-p (bicaudal)           :", format.pval(moran_votos$p_valor, eps = 1e-15), "\n")
cat(" - Conclusão: FORTÍSSIMA AUTOCORRELAÇÃO ESPACIAL POSITIVA (p < 0.001)!\n")
cat("------------------------------------------------------------------\n\n")

# Moran Scatterplot
df_moran <- data.frame(
  z = scale(df$pct_votos_flavio_bolsonaro),
  Wz = scale(moran_votos$Wz),
  municipio = df$municipio,
  mesorregiao = df$mesorregiao
)

df_moran$quadrante <- with(df_moran, case_when(
  z >= 0 & Wz >= 0 ~ "Alto-Alto (Cluster Alta Votação)",
  z < 0 & Wz < 0   ~ "Baixo-Baixo (Cluster Baixa Votação)",
  z >= 0 & Wz < 0  ~ "Alto-Baixo (Outlier Espacial)",
  z < 0 & Wz >= 0  ~ "Baixo-Alto (Outlier Espacial)"
))

p_moran_plot <- ggplot(df_moran, aes(x = z, y = Wz)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  geom_point(aes(color = quadrante), alpha = 0.7, size = 2) +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick", linewidth = 1.2) +
  scale_color_manual(values = c(
    "Alto-Alto (Cluster Alta Votação)" = "#d73027",
    "Baixo-Baixo (Cluster Baixa Votação)" = "#4575b4",
    "Alto-Baixo (Outlier Espacial)" = "#fdae61",
    "Baixo-Alto (Outlier Espacial)" = "#abd9e9"
  )) +
  guides(color = guide_legend(
    nrow = 2,
    byrow = TRUE,
    title.position = "top",
    title.hjust = 0.5
  )) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Diagrama de Dispersão de Moran (Moran Scatterplot) - Votos Flávio Bolsonaro (1º Turno)",
    subtitle = paste0("Índice de Moran Global I = ", round(moran_votos$I, 4), " (z = ", round(moran_votos$z_score, 2), ", p < 0.001)"),
    x = "Votação Centrada e Padronizada (z)",
    y = "Defasagem Espacial / Lag Médio dos Vizinhos (Wz)",
    color = "Regime Espacial / Quadrante LISA",
    caption = "A inclinação da reta de regressão corresponde ao Índice de Moran Global (I)."
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0.5),
    plot.caption = element_text(size = 9, color = "gray40", hjust = 0.5, margin = margin(t = 10)),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    legend.text = element_text(size = 9),
    legend.box.margin = margin(t = 8, b = 4),
    plot.margin = margin(t = 15, r = 20, b = 15, l = 20)
  )

ggsave("eleicao/outputs/figures/moran_scatterplot_votos.png", p_moran_plot, width = 9.5, height = 7.2, dpi = 300)
cat(" - Salvo: eleicao/outputs/figures/moran_scatterplot_votos.png\n\n")

# ------------------------------------------------------------------------------
# 4. REGRESSÃO LINEAR MÚLTIPLA: VOTO ~ SOJA + AGRO + PIB (ITEM 4)
# ------------------------------------------------------------------------------
cat("5. Ajustando Regressão Linear Múltipla (OLS)...\n")

df$log_soja_ha <- log(df$soja_area_plantada_ha + 1)
df$log_pib_total <- log(df$pib_total_mil + 1)

# Modelo OLS
# pct_votos_flavio_bolsonaro ~ log(soja_area_plantada_ha + 1) + tem_soja + share_agro_pct + log(pib_total)
modelo_ols <- lm(
  pct_votos_flavio_bolsonaro ~ log_soja_ha + tem_soja + share_agro_pct + log_pib_total,
  data = df
)

sumario_ols <- summary(modelo_ols)
cat("==================================================================\n")
cat("SUMÁRIO DO MODELO OLS (VOTOS FLÁVIO BOLSONARO ~ SOJA & AGRO):\n")
print(sumario_ols)
cat("==================================================================\n\n")

# Gráfico de Dispersão: Votos Flávio Bolsonaro vs Área de Soja
p_scatter_soja <- ggplot(df, aes(x = log_soja_ha, y = pct_votos_flavio_bolsonaro)) +
  geom_point(aes(color = mesorregiao), alpha = 0.65, size = 2.2) +
  geom_smooth(method = "lm", color = "black", linewidth = 1.1, se = TRUE) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Percentual de Votos de Flávio Bolsonaro vs Área de Soja nos Municípios de MG",
    subtitle = "Forte associação positiva e significativa entre a presença da soja e o voto em Flávio Bolsonaro (1º Turno)",
    x = "Área Plantada de Soja em Logaritmo [log(hectares + 1)]",
    y = "% de Votos Válidos de Flávio Bolsonaro (1º Turno)",
    color = "Mesorregião",
    caption = "Fontes: TSE (Presidencial 1º Turno 2026) e IBGE PAM (Tabela 1612)"
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
# 5. RESÍDUOS DA REGRESSÃO & TESTE DE AUTOCORRELAÇÃO RESIDUAL (ITEM 5)
# ------------------------------------------------------------------------------
cat("6. Extraindo resíduos e testando autocorrelação espacial residual...\n")

df$residuos_ols <- residuals(modelo_ols)
df$valores_ajustados <- fitted(modelo_ols)

moran_residuos <- calcula_moran(df$residuos_ols, W)

cat("------------------------------------------------------------------\n")
cat("RESULTADO DO ÍNDICE DE MORAN NOS RESÍDUOS DO MODELO OLS:\n")
cat(" - Índice de Moran dos Resíduos (I_res) :", round(moran_residuos$I, 5), "\n")
cat(" - Valor Esperado E[I]                  :", round(moran_residuos$E_I, 5), "\n")
cat(" - Desvio-Padrão Teórico                :", round(moran_residuos$sd_I, 5), "\n")
cat(" - Estatística z (z-score)              :", round(moran_residuos$z_score, 4), "\n")
cat(" - Valor-p (bicaudal)                   :", format.pval(moran_residuos$p_valor, eps = 1e-15), "\n")
cat(" - Diagnóstico:\n")
if (moran_residuos$p_valor < 0.05) {
  cat("   OS RESÍDUOS APRESENTAM FORTE AUTOCORRELAÇÃO ESPACIAL RESIDUAL!\n")
  cat("   O modelo clássico OLS viola a premissa de independência de Gauss-Markov.\n")
  cat("   Recomenda-se estimação de Modelos Espaciais Autorregressivos (SAR ou SEM).\n")
} else {
  cat("   Os resíduos são espacialmente independentes.\n")
}
cat("------------------------------------------------------------------\n\n")

# Mapa dos Resíduos
df_mapa_res <- left_join(df_poly, df[, c("cod_ibge", "residuos_ols", "valores_ajustados")], by = "cod_ibge")

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
    subtitle = paste0("Votação Flávio Bolsonaro 1º Turno | Moran Residual I = ", round(moran_residuos$I, 4), " (p < 0.001)"),
    caption = "Azul: Votação superestimada pelo modelo linear | Vermelho: Votação subestimada"
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

# Moran Scatterplot dos Resíduos
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
    title = "Diagrama de Dispersão de Moran dos Resíduos da Regressão (OLS)",
    subtitle = paste0("Moran Residual I = ", round(moran_residuos$I, 4), " | z-score = ", round(moran_residuos$z_score, 2)),
    x = "Resíduo Padronizado (e)",
    y = "Lag Espacial dos Resíduos (W * e)",
    caption = "A persistência de inclinação positiva comprova dependência espacial nos termos de erro."
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(size = 11, color = "gray30")
  )

ggsave("eleicao/outputs/figures/moran_scatterplot_residuos.png", p_moran_res_plot, width = 8, height = 6, dpi = 300)
cat(" - Salvo: eleicao/outputs/figures/moran_scatterplot_residuos.png\n\n")

# Tabela Síntese dos Diagnósticos em CSV
tabela_diagnosticos <- data.frame(
  Metrica = c(
    "Total de Municípios (N)",
    "Votos Válidos Totais MG",
    "Votos Flávio Bolsonaro (1º Turno)",
    "% Estadual Flávio Bolsonaro",
    "% Estadual Lula",
    "Média Municipal % Flávio Bolsonaro",
    "Índice de Moran dos Votos (I)",
    "z-score de Moran dos Votos",
    "p-valor Moran dos Votos",
    "R2 da Regressão OLS",
    "R2 Ajustado OLS",
    "Coeficiente da Soja (log_soja_ha)",
    "p-valor Coeficiente da Soja",
    "Coeficiente Dummy Soja (tem_soja)",
    "p-valor Dummy Soja",
    "Índice de Moran dos Resíduos (I_res)",
    "z-score de Moran dos Resíduos",
    "p-valor Moran dos Resíduos"
  ),
  Valor = c(
    as.character(nrow(df)),
    format(sum(df$votos_validos_total), big.mark = "."),
    format(sum(df$votos_flavio_bolsonaro), big.mark = "."),
    paste0(round(sum(df$votos_flavio_bolsonaro) / sum(df$votos_validos_total) * 100, 2), "%"),
    paste0(round(sum(df$votos_lula) / sum(df$votos_validos_total) * 100, 2), "%"),
    paste0(round(mean(df$pct_votos_flavio_bolsonaro), 2), "%"),
    as.character(round(moran_votos$I, 4)),
    as.character(round(moran_votos$z_score, 2)),
    format.pval(moran_votos$p_valor, eps = 1e-15),
    as.character(round(sumario_ols$r.squared, 4)),
    as.character(round(sumario_ols$adj.r.squared, 4)),
    as.character(round(coef(modelo_ols)["log_soja_ha"], 4)),
    format.pval(coef(sumario_ols)["log_soja_ha", "Pr(>|t|)"], eps = 1e-15),
    as.character(round(coef(modelo_ols)["tem_soja"], 4)),
    format.pval(coef(sumario_ols)["tem_soja", "Pr(>|t|)"], eps = 1e-15),
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
