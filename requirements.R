# =============================================================================
#  requirements.R
#  BDRY Pipeline — R Package Dependencies
#
#  Run this script once to install all required packages before executing
#  BDRY_pipeline.R for the first time.
#
#  Usage:
#    source("requirements.R")       # from within R / RStudio
#    Rscript requirements.R         # from the terminal
#
#  Note: BDRY_pipeline.R also auto-installs missing packages at startup,
#  so running this file separately is optional but recommended for a clean
#  first-time setup or reproducible CI environments.
# =============================================================================

# CRAN mirror — change if needed
options(repos = c(CRAN = "https://cloud.r-project.org"))

# ── Package list ──────────────────────────────────────────────────────────────
# Package        Version tested   Purpose
# ─────────────────────────────────────────────────────────────────────────────
# quantmod       >= 0.4.25        Download OHLCV data from Yahoo Finance
# TTR            >= 0.24.3        Technical indicators (SMA, BBands, RSI)
# ggplot2        >= 3.5.0         Grammar-of-graphics plotting
# patchwork      >= 1.2.0         Combine multiple ggplot2 panels
# dplyr          >= 1.1.4         Data wrangling (filter, mutate, etc.)
# scales         >= 1.3.0         Axis label formatting (dollar, number)
# moments        >= 0.14.1        Skewness and kurtosis statistics

required_pkgs <- c(
  "quantmod",
  "TTR",
  "ggplot2",
  "patchwork",
  "dplyr",
  "scales",
  "moments"
)

# ── Install only what is missing ──────────────────────────────────────────────
already_installed <- required_pkgs %in% installed.packages()[, "Package"]
to_install        <- required_pkgs[!already_installed]

if (length(to_install) == 0) {
  message("All required packages are already installed.")
} else {
  message("Installing ", length(to_install), " package(s): ",
          paste(to_install, collapse = ", "))
  install.packages(to_install)
  message("Installation complete.")
}

# ── Verify all packages load without errors ───────────────────────────────────
message("\nVerifying all packages load correctly ...")

load_ok <- vapply(required_pkgs, function(pkg) {
  tryCatch({
    library(pkg, character.only = TRUE)
    TRUE
  }, error = function(e) {
    message("  ERROR loading '", pkg, "': ", conditionMessage(e))
    FALSE
  })
}, logical(1))

if (all(load_ok)) {
  message("All packages loaded successfully. Ready to run BDRY_pipeline.R")
} else {
  failed <- names(load_ok)[!load_ok]
  warning("The following packages failed to load: ",
          paste(failed, collapse = ", "),
          "\nTry re-installing them manually with install.packages().")
}
