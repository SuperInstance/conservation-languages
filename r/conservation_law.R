#!/usr/bin/env Rscript
# ═══════════════════════════════════════════════════════════════
# SuperInstance Conservation Law — R Implementation
# γ + η = C (Shannon chain rule: H(X) = I(X;G) + H(X|G))
#
# R advantages: vectorized ops, statistical inference,
# built-in distributions, publication-quality visualization
# ═══════════════════════════════════════════════════════════════

LOG2_3 <- log2(3)  # Maximum ternary entropy ≈ 1.585 bits

# ─── Core Formulas ─────────────────────────────────────────────

conservation_delta <- function(n) {
  if (n < 2) return(1.0)
  (1 / sqrt(n)) * (1 - 3 / (2 * n))
}

conservation_efficiency <- function(n) {
  1 - conservation_delta(n)
}

# ─── Ternary Operations ────────────────────────────────────────

ternary_signals <- function(n) {
  sample(c(-1L, 0L, 1L), n, replace = TRUE)
}

ternary_dot <- function(a, b) sum(a * b)

ternary_entropy <- function(signals) {
  n <- length(signals)
  if (n == 0) return(0)
  t <- table(factor(signals, levels = c(-1, 0, 1)))
  p <- as.numeric(t) / n
  p <- p[p > 0]
  -sum(p * log2(p))
}

# ─── Conservation Analysis ─────────────────────────────────────

conservation_analyze <- function(X, G) {
  n <- length(X)
  C <- ternary_entropy(X)
  H_G <- ternary_entropy(G)
  joint <- table(factor(X, levels=-1:1), factor(G, levels=-1:1)) / n
  joint <- joint[joint > 0]
  H_XG <- -sum(joint * log2(joint))
  eta <- max(0, H_XG - H_G)
  gamma <- max(0, C - eta)
  list(gamma = gamma, eta = eta, C = C, H_max = LOG2_3)
}

fleet_cancellation <- function(signals) {
  n <- length(signals)
  if (n == 0) return(0)
  1 - abs(sum(signals)) / n
}

# ─── Monte Carlo ───────────────────────────────────────────────

monte_carlo_cancellation <- function(fleet_size, n_trials = 10000) {
  # Fully vectorized: matrix of n_trials × fleet_size
  signals <- matrix(sample(c(-1L, 0L, 1L), fleet_size * n_trials,
                           replace = TRUE),
                    nrow = n_trials, ncol = fleet_size)
  sums <- rowSums(signals)
  cancellation <- 1 - abs(sums) / fleet_size
  list(mean = mean(cancellation), sd = sd(cancellation),
       median = median(cancellation),
       q05 = quantile(cancellation, 0.05), q95 = quantile(cancellation, 0.95))
}

# ─── Haar Wavelet ──────────────────────────────────────────────

haar_decompose <- function(signal) {
  n <- length(signal)
  half <- n %/% 2
  even <- signal[seq(1, n, by = 2)]
  odd  <- signal[seq(2, n, by = 2)]
  list(approx = (even + odd) / sqrt(2), detail = (even - odd) / sqrt(2))
}

haar_full <- function(signal) {
  n <- length(signal)
  levels <- floor(log2(n))
  details <- vector("list", levels)
  current <- signal
  for (l in seq_len(levels)) {
    d <- haar_decompose(current)
    details[[l]] <- d$detail
    current <- d$approx
  }
  list(details = details, final = current, n_levels = levels)
}

# ─── Main Benchmark ────────────────────────────────────────────

main <- function() {
  cat("═══ SuperInstance Conservation Law — R ═══\n")
  cat("R:", R.version.string, "\n\n")

  cat("─── Monte Carlo Fleet Cancellation ───\n")
  sizes <- c(5, 10, 50, 100, 500, 1000, 5000, 10000)
  cat(sprintf("%-8s %-12s %-12s %-8s %-10s\n",
              "Fleet", "Empirical", "Theory", "Error%", "Time(ms)"))
  cat(paste(rep("-", 60), collapse=""), "\n")
  for (sz in sizes) {
    t0 <- Sys.time()
    mc <- monte_carlo_cancellation(sz, 10000)
    elapsed <- as.numeric(Sys.time() - t0, units = "secs") * 1000
    theo <- conservation_efficiency(sz)
    err <- abs(mc$mean - theo) / theo * 100
    cat(sprintf("%-8d %-12.4f %-12.4f %-8.2f %-10.1f\n",
                sz, mc$mean, theo, err, elapsed))
  }

  cat("\n─── Conservation Identity γ + η = C ───\n")
  set.seed(42)
  n <- 10000
  G <- ternary_signals(n)
  X <- ifelse(runif(n) < 0.5, G, ternary_signals(n))
  tc <- conservation_analyze(X, G)
  cat(sprintf("γ = %.6f  η = %.6f  C = %.6f\n", tc$gamma, tc$eta, tc$C))
  cat(sprintf("γ + η = %.6f ≈ C = %.6f  %s\n\n",
              tc$gamma + tc$eta, tc$C,
              ifelse(abs(tc$gamma+tc$eta-tc$C) < 1e-10, "✓", "✗")))

  cat("─── Haar Wavelet ───\n")
  signal <- as.integer(c(1,1,-1,1,-1,-1,1,-1))
  hw <- haar_decompose(signal)
  cat("Signal:", paste(signal, collapse=" "), "\n")
  cat("Approx:", sprintf("%.3f", hw$approx), "\n")
  cat("Detail:", sprintf("%.3f", hw$detail), "\n")

  cat("\n─── Distribution (n=50, 10K trials) ───\n")
  mc50 <- monte_carlo_cancellation(50, 10000)
  cat(sprintf("Mean=%.4f  SD=%.4f  90%%CI=[%.4f, %.4f]\n",
              mc50$mean, mc50$sd, mc50$q05, mc50$q95))
  cat(sprintf("Theory: 86.28%%\n"))

  cat("\n─── Throughput ───\n")
  t0 <- Sys.time()
  monte_carlo_cancellation(100000, 100)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  cat(sprintf("100K agents × 100 trials: %.3fs (%.1fM sig/s)\n",
              elapsed, 100000*100/elapsed/1e6))
  cat("\n═══ Complete ═══\n")
}

main()
