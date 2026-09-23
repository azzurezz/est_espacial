# ==============================================================================
# ESTUDO DE SIMULAÇÃO MONTE CARLO: ESTIMAÇÃO DE PARÂMETROS DO VARIOGRAMA
# Baseado em Moraga (2023) - Spatial Statistics for Data Science (Cap. 14: Kriging)
# ==============================================================================

suppressPackageStartupMessages({
  library(MASS)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(gridExtra)
})

# Criar diretório para salvar plots se não existir
if (!dir.exists("plots")) {
  dir.create("plots")
}

set.seed(2026)

# ------------------------------------------------------------------------------
# 1. PARÂMETROS DA SIMULAÇÃO
# ------------------------------------------------------------------------------
tau2_true   <- 0.20   # Nugget (Efeito Pepita)
sigma2_true <- 1.00   # Partial Sill (Variância Espacial)
phi_true    <- 20.00  # Range (Alcance Espacial - Modelo Exponencial)

sample_sizes <- c(50, 100, 200)
n_sim        <- 100
domain_size  <- 100

cat("==================================================================\n")
cat("INICIANDO SIMULAÇÃO MONTE CARLO (N =", n_sim, "replicações por cenário)\n")
cat("Parâmetros Verdadeiros: Nugget =", tau2_true, "| Partial Sill =", sigma2_true, "| Alcance (phi) =", phi_true, "\n")
cat("==================================================================\n\n")

# ------------------------------------------------------------------------------
# 2. FUNÇÕES AUXILIARES DE AJUSTE DE VARIOGRAMA (WLS & OLS)
# ------------------------------------------------------------------------------

# Variograma Teórico Exponencial: gamma(h) = tau2 + sigma2 * (1 - exp(-h / phi))
exp_variogram <- function(h, tau2, sigma2, phi) {
  tau2 + sigma2 * (1 - exp(-h / phi))
}

# Calcular Variograma Empírico
compute_empirical_variogram <- function(coords, z, n_lags = 15, max_dist_ratio = 0.5) {
  n <- nrow(coords)
  D <- as.matrix(dist(coords))
  pairs <- t(combn(n, 2))
  
  dist_vec <- D[pairs]
  sq_diff  <- 0.5 * (z[pairs[, 1]] - z[pairs[, 2]])^2
  
  max_dist <- max(dist_vec) * max_dist_ratio
  bins     <- seq(0, max_dist, length.out = n_lags + 1)
  bin_mid  <- (bins[-1] + bins[-length(bins)]) / 2
  
  emp_gamma  <- numeric(length(bin_mid))
  bin_counts <- numeric(length(bin_mid))
  
  for (k in 1:length(bin_mid)) {
    idx <- dist_vec >= bins[k] & dist_vec < bins[k + 1]
    if (sum(idx) > 0) {
      emp_gamma[k]  <- mean(sq_diff[idx])
      bin_counts[k] <- sum(idx)
    } else {
      emp_gamma[k]  <- NA
      bin_counts[k] <- 0
    }
  }
  
  valid <- !is.na(emp_gamma) & bin_counts > 0
  return(list(
    h      = bin_mid[valid],
    gamma  = emp_gamma[valid],
    counts = bin_counts[valid]
  ))
}

# Ajustar Modelo Exponencial por WLS ou OLS
fit_variogram_model <- function(emp_var, method = c("WLS", "OLS")) {
  method <- match.arg(method)
  
  h     <- emp_var$h
  g_obs <- emp_var$gamma
  cnt   <- emp_var$counts
  
  objective_fn <- function(par) {
    t2 <- par[1]
    s2 <- par[2]
    ph <- par[3]
    
    if (t2 < 0 || s2 < 0 || ph <= 0) return(1e10)
    
    g_theo <- exp_variogram(h, t2, s2, ph)
    
    if (method == "WLS") {
      # Pesos de Cressie: N(h) / gamma_theo(h)^2
      w <- cnt / (g_theo^2 + 1e-6)
    } else {
      # OLS: Pesos unitários
      w <- rep(1, length(h))
    }
    
    sum(w * (g_obs - g_theo)^2)
  }
  
  # Chute inicial razoável baseado nos dados empíricos
  init_t2 <- max(0.01, min(g_obs))
  init_s2 <- max(0.1, max(g_obs) - init_t2)
  init_ph <- mean(h) / 2
  
  res <- optim(
    par    = c(init_t2, init_s2, init_ph),
    fn     = objective_fn,
    method = "L-BFGS-B",
    lower  = c(0.0001, 0.0001, 0.5),
    upper  = c(5.0, 10.0, 150.0)
  )
  
  return(data.frame(
    tau2   = res$par[1],
    sigma2 = res$par[2],
    phi    = res$par[3],
    conv   = res$convergence
  ))
}

# ------------------------------------------------------------------------------
# 3. EXECUÇÃO DO LOOP MONTE CARLO
# ------------------------------------------------------------------------------
results_list <- list()

for (n_obs in sample_sizes) {
  cat("Simulando cenário n =", n_obs, "...\n")
  
  for (i in 1:n_sim) {
    # Coordenadas aleatórias
    coords <- cbind(runif(n_obs, 0, domain_size), runif(n_obs, 0, domain_size))
    D <- as.matrix(dist(coords))
    
    # Matriz de Covariância Teórica
    Sigma <- sigma2_true * exp(-D / phi_true) + diag(tau2_true, n_obs)
    
    # Simulação de Campo Aleatório Gaussiano (GRF)
    z <- mvrnorm(1, mu = rep(0, n_obs), Sigma = Sigma)
    
    # Variograma Empírico
    emp_var <- compute_empirical_variogram(coords, z)
    
    # Ajuste WLS
    fit_wls <- fit_variogram_model(emp_var, method = "WLS")
    results_list[[length(results_list) + 1]] <- data.frame(
      sim = i, n = n_obs, method = "WLS",
      tau2 = fit_wls$tau2, sigma2 = fit_wls$sigma2, phi = fit_wls$phi
    )
    
    # Ajuste OLS
    fit_ols <- fit_variogram_model(emp_var, method = "OLS")
    results_list[[length(results_list) + 1]] <- data.frame(
      sim = i, n = n_obs, method = "OLS",
      tau2 = fit_ols$tau2, sigma2 = fit_ols$sigma2, phi = fit_ols$phi
    )
  }
}

raw_df <- bind_rows(results_list)
write.csv(raw_df, "sim_results_detailed.csv", row.names = FALSE)

# ------------------------------------------------------------------------------
# 4. PROCESSAMENTO DAS ESTATÍSTICAS E TABELA RESUMO
# ------------------------------------------------------------------------------

summary_df <- raw_df %>%
  pivot_longer(cols = c(tau2, sigma2, phi), names_to = "parameter", values_to = "estimate") %>%
  mutate(
    true_val = case_when(
      parameter == "tau2"   ~ tau2_true,
      parameter == "sigma2" ~ sigma2_true,
      parameter == "phi"    ~ phi_true
    ),
    param_label = case_when(
      parameter == "tau2"   ~ "Nugget (tau^2)",
      parameter == "sigma2" ~ "Partial Sill (sigma^2)",
      parameter == "phi"    ~ "Alcance (phi)"
    )
  ) %>%
  group_by(n, method, parameter, param_label) %>%
  summarise(
    tv        = first(true_val),
    mean_est  = mean(estimate),
    median_est= median(estimate),
    sd_est    = sd(estimate),
    bias      = mean(estimate) - first(true_val),
    rel_bias  = ((mean(estimate) - first(true_val)) / first(true_val)) * 100,
    rmse      = sqrt(mean((estimate - first(true_val))^2)),
    .groups   = "drop"
  ) %>%
  rename(true_val = tv)

write.csv(summary_df, "sim_results_summary.csv", row.names = FALSE)

cat("\n==================================================================\n")
cat("RESUMO DOS RESULTADOS DA SIMULAÇÃO (TABELA SINTÉTICA):\n")
cat("==================================================================\n")
print(as.data.frame(summary_df %>% select(n, method, parameter, true_val, mean_est, bias, rel_bias, rmse)))

# ------------------------------------------------------------------------------
# 5. GERAÇÃO DE GRÁFICOS ILUSTRATIVOS E DIAGNÓSTICOS
# ------------------------------------------------------------------------------

# Theme customizado limpo e profissional
theme_academic <- theme_bw(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle    = element_text(size = 11, hjust = 0.5),
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "#f0f0f0", color = "#cccccc"),
    strip.text       = element_text(face = "bold", size = 11)
  )

# --- GRÁFICO 1: Exemplo de Variograma Empírico vs Ajustes Teóricos ---
set.seed(123)
coords_ex <- cbind(runif(100, 0, domain_size), runif(100, 0, domain_size))
D_ex <- as.matrix(dist(coords_ex))
Sigma_ex <- sigma2_true * exp(-D_ex / phi_true) + diag(tau2_true, 100)
z_ex <- mvrnorm(1, mu = rep(0, 100), Sigma = Sigma_ex)

emp_ex <- compute_empirical_variogram(coords_ex, z_ex)
wls_ex <- fit_variogram_model(emp_ex, "WLS")
ols_ex <- fit_variogram_model(emp_ex, "OLS")

h_grid <- seq(0, max(emp_ex$h), length.out = 200)
curve_df <- data.frame(
  h = rep(h_grid, 3),
  gamma = c(
    exp_variogram(h_grid, tau2_true, sigma2_true, phi_true),
    exp_variogram(h_grid, wls_ex$tau2, wls_ex$sigma2, wls_ex$phi),
    exp_variogram(h_grid, ols_ex$tau2, ols_ex$sigma2, ols_ex$phi)
  ),
  Modelo = factor(
    rep(c("Verdadeiro", "Ajuste WLS", "Ajuste OLS"), each = length(h_grid)),
    levels = c("Verdadeiro", "Ajuste WLS", "Ajuste OLS")
  )
)

emp_points_df <- data.frame(h = emp_ex$h, gamma = emp_ex$gamma)

p1 <- ggplot() +
  geom_point(data = emp_points_df, aes(x = h, y = gamma), size = 3, color = "#333333", alpha = 0.8) +
  geom_line(data = curve_df, aes(x = h, y = gamma, color = Modelo, linetype = Modelo), size = 1.2) +
  scale_color_manual(values = c("Verdadeiro" = "#1b9e77", "Ajuste WLS" = "#d95f02", "Ajuste OLS" = "#7570b3")) +
  scale_linetype_manual(values = c("Verdadeiro" = "dashed", "Ajuste WLS" = "solid", "Ajuste OLS" = "dotdash")) +
  labs(
    title = "Exemplo de Variograma Empírico e Modelos Ajustados (n = 100)",
    subtitle = expression(paste("Parâmetros Verdadeiros: ", tau^2, " = 0.2, ", sigma^2, " = 1.0, ", phi, " = 20.0")),
    x = "Distância de Separação (h)",
    y = expression(paste("Semivariância ", gamma, "(h)"))
  ) +
  theme_academic

ggsave("plots/exemplo_variograma_ajustado.png", p1, width = 8, height = 5, dpi = 300)

# --- GRÁFICO 2: Boxplot dos Parâmetros Estimados por Tamanho Amostral ---
long_raw <- raw_df %>%
  pivot_longer(cols = c(tau2, sigma2, phi), names_to = "parameter", values_to = "estimate") %>%
  mutate(
    param_label = factor(
      case_when(
        parameter == "tau2"   ~ "Nugget (tau^2 = 0.2)",
        parameter == "sigma2" ~ "Partial Sill (sigma^2 = 1.0)",
        parameter == "phi"    ~ "Alcance (phi = 20.0)"
      ),
      levels = c("Nugget (tau^2 = 0.2)", "Partial Sill (sigma^2 = 1.0)", "Alcance (phi = 20.0)")
    ),
    n_label = factor(paste("n =", n), levels = c("n = 50", "n = 100", "n = 200"))
  )

true_lines <- data.frame(
  param_label = factor(c("Nugget (tau^2 = 0.2)", "Partial Sill (sigma^2 = 1.0)", "Alcance (phi = 20.0)"),
                       levels = c("Nugget (tau^2 = 0.2)", "Partial Sill (sigma^2 = 1.0)", "Alcance (phi = 20.0)")),
  intercept = c(0.2, 1.0, 20.0)
)

p2 <- ggplot(long_raw, aes(x = n_label, y = estimate, fill = method)) +
  geom_hline(data = true_lines, aes(yintercept = intercept), color = "red", linetype = "dashed", size = 0.9) +
  geom_boxplot(alpha = 0.75, outlier.size = 1) +
  facet_wrap(~ param_label, scales = "free_y") +
  scale_fill_manual(values = c("WLS" = "#2b5c8f", "OLS" = "#e06d53"), name = "Método de Ajuste:") +
  labs(
    title = "Distribuição dos Parâmetros Estimados via Monte Carlo",
    subtitle = "Linha vermelha tracejada indica o valor verdadeiro dos parâmetros",
    x = "Tamanho Amostral (n)",
    y = "Valor Estimado"
  ) +
  theme_academic

ggsave("plots/boxplot_parametros.png", p2, width = 10, height = 6, dpi = 300)

# --- GRÁFICO 3: Evolução do RMSE em Função do Tamanho Amostral ---
p3 <- ggplot(summary_df, aes(x = factor(n), y = rmse, color = method, group = method)) +
  geom_line(size = 1.2) +
  geom_point(size = 3) +
  facet_wrap(~ param_label, scales = "free_y") +
  scale_color_manual(values = c("WLS" = "#2b5c8f", "OLS" = "#e06d53"), name = "Método de Ajuste:") +
  labs(
    title = "Evolução do Erro Quadrático Médio (RMSE) por Tamanho Amostral",
    subtitle = "Redução do erro de estimação à medida que o tamanho da amostra aumenta",
    x = "Tamanho Amostral (n)",
    y = "RMSE (Raiz do Erro Quadrático Médio)"
  ) +
  theme_academic

ggsave("plots/rmse_tamanho_amostral.png", p3, width = 10, height = 5.5, dpi = 300)

cat("\n==================================================================\n")
cat("SIMULAÇÃO E GERAÇÃO DE GRÁFICOS CONCLUÍDAS COM SUCESSO!\n")
cat("Gráficos salvos na pasta 'plots/':\n")
cat(" - plots/exemplo_variograma_ajustado.png\n")
cat(" - plots/boxplot_parametros.png\n")
cat(" - plots/rmse_tamanho_amostral.png\n")
cat("==================================================================\n")
