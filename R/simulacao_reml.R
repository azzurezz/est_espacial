# ==============================================================================
# ESTUDO DE SIMULAÇÃO MONTE CARLO: MÁXIMA VEROSSIMILHANÇA RESTRITA (REML vs WLS / OLS)
# Comparação de Eficiência e Robustez na Estimação de Parâmetros de Covariância
# ==============================================================================

suppressPackageStartupMessages({
  library(MASS)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(gridExtra)
})

# Criar diretórios para salvar plots e dados se não existirem
if (!dir.exists("plots")) dir.create("plots")
if (!dir.exists("data")) dir.create("data")

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
cat("INICIANDO SIMULAÇÃO MONTE CARLO REML vs WLS/OLS (N =", n_sim, "replicações)\n")
cat("Parâmetros Verdadeiros: Nugget =", tau2_true, "| Partial Sill =", sigma2_true, "| Alcance (phi) =", phi_true, "\n")
cat("==================================================================\n\n")

# ------------------------------------------------------------------------------
# 2. FUNÇÕES DE ESTIMAÇÃO: VARIOGRAMA (WLS/OLS) E REML
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
      w <- cnt / (g_theo^2 + 1e-6)
    } else {
      w <- rep(1, length(h))
    }
    
    sum(w * (g_obs - g_theo)^2)
  }
  
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

# Log-Verossimilhança Restrita (REML)
reml_neg_loglik <- function(par, y, X, D) {
  tau2   <- par[1]
  sigma2 <- par[2]
  phi    <- par[3]
  
  if (tau2 <= 1e-4 || sigma2 <= 1e-4 || phi <= 0.1) return(1e10)
  
  n <- length(y)
  Sigma <- sigma2 * exp(-D / phi) + diag(tau2, n)
  
  chol_S <- try(chol(Sigma), silent = TRUE)
  if (inherits(chol_S, "try-error")) return(1e10)
  
  log_det_Sigma <- 2 * sum(log(diag(chol_S)))
  
  inv_Sigma_X <- backsolve(chol_S, forwardsolve(t(chol_S), X))
  inv_Sigma_y <- backsolve(chol_S, forwardsolve(t(chol_S), y))
  
  Xt_inv_Sigma_X <- sum(X * inv_Sigma_X)
  if (is.na(Xt_inv_Sigma_X) || Xt_inv_Sigma_X <= 0) return(1e10)
  
  log_det_XtSX <- log(Xt_inv_Sigma_X)
  
  Xt_inv_Sigma_y <- sum(X * inv_Sigma_y)
  beta_hat <- Xt_inv_Sigma_y / Xt_inv_Sigma_X
  
  r <- y - beta_hat
  
  inv_Sigma_r <- backsolve(chol_S, forwardsolve(t(chol_S), r))
  quad_form <- sum(r * inv_Sigma_r)
  
  neg_log_reml <- 0.5 * (log_det_Sigma + log_det_XtSX + quad_form + (n - 1) * log(2 * pi))
  
  if (is.na(neg_log_reml) || is.nan(neg_log_reml) || is.infinite(neg_log_reml)) return(1e10)
  
  return(neg_log_reml)
}

# Ajuste por REML
fit_reml_model <- function(coords, z) {
  D <- as.matrix(dist(coords))
  X <- matrix(1, nrow = length(z), ncol = 1)
  
  init_t2 <- max(0.05, var(z) * 0.2)
  init_s2 <- max(0.1, var(z) * 0.8)
  init_ph <- max(5.0, mean(D) / 4)
  
  res <- optim(
    par    = c(init_t2, init_s2, init_ph),
    fn     = reml_neg_loglik,
    y      = z,
    X      = X,
    D      = D,
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
    coords <- cbind(runif(n_obs, 0, domain_size), runif(n_obs, 0, domain_size))
    D <- as.matrix(dist(coords))
    
    Sigma <- sigma2_true * exp(-D / phi_true) + diag(tau2_true, n_obs)
    z <- mvrnorm(1, mu = rep(0, n_obs), Sigma = Sigma)
    
    emp_var <- compute_empirical_variogram(coords, z)
    
    # 1. Ajuste REML
    fit_reml <- fit_reml_model(coords, z)
    results_list[[length(results_list) + 1]] <- data.frame(
      sim = i, n = n_obs, method = "REML",
      tau2 = fit_reml$tau2, sigma2 = fit_reml$sigma2, phi = fit_reml$phi
    )
    
    # 2. Ajuste WLS
    fit_wls <- fit_variogram_model(emp_var, method = "WLS")
    results_list[[length(results_list) + 1]] <- data.frame(
      sim = i, n = n_obs, method = "WLS",
      tau2 = fit_wls$tau2, sigma2 = fit_wls$sigma2, phi = fit_wls$phi
    )
    
    # 3. Ajuste OLS
    fit_ols <- fit_variogram_model(emp_var, method = "OLS")
    results_list[[length(results_list) + 1]] <- data.frame(
      sim = i, n = n_obs, method = "OLS",
      tau2 = fit_ols$tau2, sigma2 = fit_ols$sigma2, phi = fit_ols$phi
    )
  }
}

raw_df <- bind_rows(results_list)
write.csv(raw_df, "data/sim_reml_detailed.csv", row.names = FALSE)

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
      parameter == "tau2"   ~ "Efeito Pepita (tau^2)",
      parameter == "sigma2" ~ "Patamar Parcial (sigma^2)",
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

write.csv(summary_df, "data/sim_reml_summary.csv", row.names = FALSE)

cat("\n==================================================================\n")
cat("RESUMO DOS RESULTADOS DA SIMULAÇÃO REML vs WLS/OLS:\n")
cat("==================================================================\n")
print(as.data.frame(summary_df %>% select(n, method, parameter, true_val, mean_est, bias, rel_bias, rmse)))

# ------------------------------------------------------------------------------
# 5. GERAÇÃO DE GRÁFICOS COMPARATIVOS (REML vs WLS vs OLS)
# ------------------------------------------------------------------------------

theme_academic <- theme_bw(base_size = 12) +
  theme(
    plot.title       = element_text(face = "bold", size = 14, hjust = 0.5),
    plot.subtitle    = element_text(size = 11, hjust = 0.5),
    legend.position  = "bottom",
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "#f0f0f0", color = "#cccccc"),
    strip.text       = element_text(face = "bold", size = 11)
  )

long_raw <- raw_df %>%
  pivot_longer(cols = c(tau2, sigma2, phi), names_to = "parameter", values_to = "estimate") %>%
  mutate(
    param_label = factor(
      case_when(
        parameter == "tau2"   ~ "Efeito Pepita (tau^2 = 0.2)",
        parameter == "sigma2" ~ "Patamar Parcial (sigma^2 = 1.0)",
        parameter == "phi"    ~ "Alcance (phi = 20.0)"
      ),
      levels = c("Efeito Pepita (tau^2 = 0.2)", "Patamar Parcial (sigma^2 = 1.0)", "Alcance (phi = 20.0)")
    ),
    n_label = factor(paste("n =", n), levels = c("n = 50", "n = 100", "n = 200")),
    method  = factor(method, levels = c("REML", "WLS", "OLS"))
  )

true_lines <- data.frame(
  param_label = factor(c("Efeito Pepita (tau^2 = 0.2)", "Patamar Parcial (sigma^2 = 1.0)", "Alcance (phi = 20.0)"),
                       levels = c("Efeito Pepita (tau^2 = 0.2)", "Patamar Parcial (sigma^2 = 1.0)", "Alcance (phi = 20.0)")),
  intercept = c(0.2, 1.0, 20.0)
)

# --- GRÁFICO 1: Boxplot Comparativo (REML vs WLS vs OLS) ---
p1 <- ggplot(long_raw, aes(x = n_label, y = estimate, fill = method)) +
  geom_hline(data = true_lines, aes(yintercept = intercept), color = "red", linetype = "dashed", size = 0.9) +
  geom_boxplot(alpha = 0.8, outlier.size = 0.9, position = position_dodge(width = 0.8)) +
  facet_wrap(~ param_label, scales = "free_y") +
  scale_fill_manual(values = c("REML" = "#27ae60", "WLS" = "#2b5c8f", "OLS" = "#e06d53"), name = "Método:") +
  labs(
    title = "Comparação da Distribuição dos Parâmetros: REML vs WLS vs OLS",
    subtitle = "Linha vermelha tracejada indica o valor verdadeiro dos parâmetros",
    x = "Tamanho Amostral (n)",
    y = "Valor Estimado"
  ) +
  theme_academic

ggsave("plots/boxplot_reml_vs_wls.png", p1, width = 10, height = 6, dpi = 300)

# --- GRÁFICO 2: Comparação de RMSE em Função do Tamanho Amostral ---
summary_df_plot <- summary_df %>%
  mutate(method = factor(method, levels = c("REML", "WLS", "OLS")))

p2 <- ggplot(summary_df_plot, aes(x = factor(n), y = rmse, color = method, group = method)) +
  geom_line(size = 1.2) +
  geom_point(size = 3) +
  facet_wrap(~ param_label, scales = "free_y") +
  scale_color_manual(values = c("REML" = "#27ae60", "WLS" = "#2b5c8f", "OLS" = "#e06d53"), name = "Método:") +
  labs(
    title = "Comparação de Eficiência (RMSE): REML vs WLS vs OLS",
    subtitle = "O método REML apresenta menor RMSE para Patamar Parcial e Alcance sob amostras pequenas/médias",
    x = "Tamanho Amostral (n)",
    y = "RMSE (Raiz do Erro Quadrático Médio)"
  ) +
  theme_academic

ggsave("plots/rmse_reml_vs_wls.png", p2, width = 10, height = 5.5, dpi = 300)

cat("\n==================================================================\n")
cat("SIMULAÇÃO REML E GERAÇÃO DE GRÁFICOS CONCLUÍDAS COM SUCESSO!\n")
cat("Gráficos salvos na pasta 'plots/':\n")
cat(" - plots/boxplot_reml_vs_wls.png\n")
cat(" - plots/rmse_reml_vs_wls.png\n")
cat("==================================================================\n")
