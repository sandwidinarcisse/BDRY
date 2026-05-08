# BDRY Automated Analysis Pipeline

An automated R pipeline that downloads, processes, and visualises one year of daily price data for the **Breakwave Dry Bulk Shipping ETF (BDRY)** from Yahoo Finance.

---

## What it does

| Stage | Description |
|-------|-------------|
| **Download** | Fetches 365 days of OHLCV + Adjusted close via `quantmod` |
| **Process** | Cleans the data, removes NAs, classifies bullish/bearish sessions |
| **Indicators** | Computes SMA20, SMA50, Bollinger Bands (20-day, 2σ), RSI(14), log returns, cumulative return, and drawdown |
| **Analyse** | Prints a summary statistics table to the console |
| **Visualise** | Generates 4 publication-quality charts — displayed immediately and saved as PNG |

---

## Charts

All charts appear in your graphics viewer upon execution and are also saved to `./BDRY_output/`.

| File | Description |
|------|-------------|
| `01_price_volume_MA.png` | Candlestick chart with SMA20/50 overlay + volume bars |
| `02_bollinger_RSI.png` | Bollinger Bands (20-day, 2σ) + RSI(14) with overbought/oversold zones |
| `03_returns_distribution.png` | Daily log-return histogram with kernel density, mean/median lines, and a stats annotation box |
| `04_cumulative_drawdown.png` | Cumulative log return ribbon + drawdown timeline |

---

## Requirements

- **R** ≥ 4.2.0  
- An internet connection (to fetch data from Yahoo Finance)

### R packages

| Package | Purpose |
|---------|---------|
| `quantmod` | Download OHLCV data from Yahoo Finance |
| `TTR` | Technical indicators (SMA, BBands, RSI) |
| `ggplot2` | Grammar-of-graphics plotting |
| `patchwork` | Combine multiple ggplot2 panels |
| `dplyr` | Data wrangling |
| `scales` | Axis label formatting |
| `moments` | Skewness and kurtosis |

---

## Getting started

### 1 — Clone the repository

```bash
git clone https://github.com/sandwidinarcisse/BDRY.git
cd BDRY
```

### 2 — Install dependencies (one-time)

```r
source("requirements.R")
```

> **Note:** `BDRY_pipeline.R` also installs missing packages automatically at startup, so this step is optional.

### 3 — Run the pipeline

From **R / RStudio**:
```r
source("BDRY_pipeline.R")
```

From the **terminal**:
```bash
Rscript BDRY_pipeline.R
```

Charts will appear in your graphics viewer as each one is generated. PNG files are saved to `./BDRY_output/`.

---

## Configuration

All user-facing settings are at the top of `BDRY_pipeline.R` under the `CONFIGURATION` section:

```r
TICKER     <- "BDRY"         # Yahoo Finance ticker — change to any valid symbol
LOOKBACK   <- 365            # Calendar days of history to download
OUTPUT_DIR <- "BDRY_output"  # Relative path for PNG output
DPI        <- 300            # PNG resolution (300 = print-quality)
PLOT_W     <- 13             # Chart width in inches
PLOT_H     <- 9              # Chart height in inches
```

You can point the pipeline at any ticker supported by Yahoo Finance by changing `TICKER`.

---

## Project structure

```
BDRY/
├── BDRY_pipeline.R    # Main pipeline script
├── requirements.R     # One-time package installer and verifier
├── README.md          # This file
├── .gitignore         # Excludes generated PNGs and R session files
└── BDRY_output/       # Auto-created on first run
    ├── 01_price_volume_MA.png
    ├── 02_bollinger_RSI.png
    ├── 03_returns_distribution.png
    └── 04_cumulative_drawdown.png
```

---

## Console output

When the pipeline runs, it prints a summary statistics table:

```
╔══════════════════════════════════════════╗
║         BDRY — Summary Statistics        ║
╠══════════════════════════════════════════╣
║  Period         : Last 365 days          ║
║  Trading days   : 252                    ║
║  Start price    : $5.43                  ║
║  End price      : $4.12                  ║
║  Total return   : -24.13%                ║
║  Max drawdown   : -38.50%                ║
║  Ann. volatility: 42.10%                 ║
║  Sharpe ratio   : -0.5731 (rf=0)         ║
║  Positive days  : 47.2%                  ║
╚══════════════════════════════════════════╝
```

*(Values are illustrative — actual output reflects the current market data.)*

---

## Data source

Market data is fetched live from **Yahoo Finance** via the [`quantmod`](https://cran.r-project.org/package=quantmod) package. Data availability depends on Yahoo Finance's service and may vary.

---

## License

This project is released under the [MIT License](https://opensource.org/licenses/MIT).
