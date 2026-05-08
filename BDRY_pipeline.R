# =============================================================================
#  BDRY AUTOMATED PIPELINE
#  Breakwave Dry Bulk Shipping ETF (BDRY) — Yahoo Finance
#
#  Stages:
#    1. Download   – 1 year of OHLCV data via quantmod
#    2. Process    – clean, tidy, add direction flag
#    3. Indicators – SMA20, SMA50, Bollinger Bands, RSI14, returns, drawdown
#    4. Analyse    – print key statistics to the console
#    5. Visualise  – 4 publication-quality PNG charts saved + displayed
#
#  Output folder: ./BDRY_output/
#    01_price_volume_MA.png      Candlestick + SMA20/50 + volume
#    02_bollinger_RSI.png        Bollinger Bands (20-day 2σ) + RSI (14-day)
#    03_returns_distribution.png Daily log-return histogram with density
#    04_cumulative_drawdown.png  Cumulative return + drawdown timeline
#
#  Usage:
#    source("BDRY_pipeline.R")          # from within R / RStudio
#    Rscript BDRY_pipeline.R            # from the terminal
#
#  Dependencies: see requirements.R
# =============================================================================


# ── 0. PACKAGES ───────────────────────────────────────────────────────────────
# Install any missing packages automatically before loading them.

required_pkgs <- c("quantmod", "TTR", "ggplot2", "patchwork",
                   "dplyr", "scales", "moments")

new_pkgs <- required_pkgs[!required_pkgs %in% installed.packages()[, "Package"]]
if (length(new_pkgs) > 0) {
  message("Installing missing packages: ", paste(new_pkgs, collapse = ", "))
  install.packages(new_pkgs, repos = "https://cloud.r-project.org")
}

library(quantmod)  # getSymbols() – download financial data from Yahoo Finance
library(TTR)       # SMA(), EMA(), BBands(), RSI() – technical indicators
library(ggplot2)   # grammar-of-graphics plotting
library(patchwork) # combine multiple ggplot panels with /  and |  operators
library(dplyr)     # data wrangling (filter, mutate, etc.)
library(scales)    # axis label helpers (dollar_format, label_number)
library(moments)   # skewness() and kurtosis() for the returns histogram


# ── 1. CONFIGURATION ──────────────────────────────────────────────────────────
# Edit these values to change the ticker, date range, or output settings.
# OUTPUT_DIR is relative to the script's location — no absolute paths needed.

TICKER      <- "BDRY"          # Yahoo Finance ticker symbol
LOOKBACK    <- 365             # calendar days of history to download
OUTPUT_DIR  <- "BDRY_output"  # sub-folder where PNGs will be saved
DPI         <- 300             # PNG resolution (300 = print-quality)
PLOT_W      <- 13              # chart width  in inches
PLOT_H      <- 9               # chart height in inches

# Colour palette (feel free to customise)
COL_BULL    <- "#2ecc71"  # green  – bullish candles / positive returns
COL_BEAR    <- "#e74c3c"  # red    – bearish candles / negative returns
COL_NAVY    <- "#2c3e50"  # navy   – price line, SMA50
COL_BLUE    <- "#3498db"  # blue   – SMA20
COL_ORANGE  <- "#e67e22"  # orange – Bollinger Bands
COL_PURPLE  <- "#8e44ad"  # purple – RSI line


# ── 2. OUTPUT DIRECTORY ───────────────────────────────────────────────────────
# Create the output folder if it does not already exist.

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
  message("Created output directory: ./", OUTPUT_DIR, "/")
}


# ── 3. DOWNLOAD DATA ──────────────────────────────────────────────────────────
# getSymbols() fetches OHLCV + Adjusted close from Yahoo Finance.
# auto.assign = FALSE returns the xts object directly instead of creating
# a global variable named after the ticker.

message("\n[1/5] Downloading ", TICKER, " data (", LOOKBACK, " days) ...")

raw_xts <- tryCatch(
  getSymbols(
    TICKER,
    src         = "yahoo",
    from        = Sys.Date() - LOOKBACK,
    auto.assign = FALSE
  ),
  error = function(e) {
    stop("Download failed for ", TICKER, ": ", conditionMessage(e))
  }
)

message(
  "  Downloaded ", nrow(raw_xts), " trading days  (",
  format(index(raw_xts)[1],             "%Y-%m-%d"), " to ",
  format(index(raw_xts)[nrow(raw_xts)], "%Y-%m-%d"), ")"
)


# ── 4. PROCESS & CLEAN ────────────────────────────────────────────────────────
# Convert the xts object to a plain data frame for easier ggplot2 use.
# Column names are standardised (quantmod appends the ticker prefix).

message("\n[2/5] Processing and cleaning data ...")

df <- data.frame(
  Date   = index(raw_xts),
  Open   = as.numeric(raw_xts[, 1]),  # BDRY.Open
  High   = as.numeric(raw_xts[, 2]),  # BDRY.High
  Low    = as.numeric(raw_xts[, 3]),  # BDRY.Low
  Close  = as.numeric(raw_xts[, 4]),  # BDRY.Close
  Volume = as.numeric(raw_xts[, 5]),  # BDRY.Volume
  Adj    = as.numeric(raw_xts[, 6])   # BDRY.Adjusted
)

# Drop rows with any NA (can appear at the very start of some series)
n_before <- nrow(df)
df       <- df %>% filter(!is.na(Close), !is.na(Volume), !is.na(Adj))
message("  Rows kept after NA removal: ", nrow(df),
        " (dropped ", n_before - nrow(df), ")")

# Classify each session for candlestick colouring
df$Direction <- ifelse(df$Close >= df$Open, "Bullish", "Bearish")


# ── 5. TECHNICAL INDICATORS ───────────────────────────────────────────────────
# All indicators are computed on the Adjusted close price to account for
# dividends and stock splits.

message("\n[3/5] Computing technical indicators ...")

adj <- df$Adj  # shorthand

# — Moving Averages —
df$SMA20 <- SMA(adj, n = 20)  # 20-day simple moving average (short-term trend)
df$SMA50 <- SMA(adj, n = 50)  # 50-day simple moving average (medium-term trend)

# — Bollinger Bands (20-day window, ±2 standard deviations) —
bb          <- BBands(adj, n = 20, sd = 2)
df$BB_upper <- as.numeric(bb[, "up"])    # upper band
df$BB_lower <- as.numeric(bb[, "dn"])    # lower band
df$BB_mid   <- as.numeric(bb[, "mavg"]) # middle band (= SMA20)

# — Relative Strength Index (14-day) —
# RSI > 70  → potentially overbought
# RSI < 30  → potentially oversold
df$RSI14 <- as.numeric(RSI(adj, n = 14))

# — Daily Log Returns (%) —
# Log returns are time-additive and more suitable for statistical analysis
df$Return <- c(NA, diff(log(adj)) * 100)

# — Cumulative Log Return (%) —
# Running sum of daily log returns (≈ total compounded return for small values)
df$CumReturn <- cumsum(ifelse(is.na(df$Return), 0, df$Return))

# — Drawdown (%) —
# How far the price has fallen from its running peak (always ≤ 0)
running_peak <- cummax(adj)
df$Drawdown  <- (adj - running_peak) / running_peak * 100

message("  Indicators computed: SMA20, SMA50, Bollinger Bands, RSI14, ",
        "daily returns, cumulative return, drawdown")


# ── 6. ANALYSIS — SUMMARY STATISTICS ─────────────────────────────────────────
# Compute and print key performance metrics to the console.

message("\n[4/5] Analysing ...")

returns_clean  <- df$Return[!is.na(df$Return)]   # drop leading NA
total_return   <- (df$Adj[nrow(df)] / df$Adj[1] - 1) * 100  # simple %
max_dd         <- min(df$Drawdown, na.rm = TRUE)
ann_vol        <- sd(returns_clean) * sqrt(252)   # annualised volatility (%)
sharpe         <- (mean(returns_clean) * 252) / ann_vol  # simplified Sharpe (rf = 0)
pos_days_pct   <- mean(returns_clean > 0) * 100          # % of positive days

cat("\n")
cat("╔══════════════════════════════════════════╗\n")
cat("║         BDRY — Summary Statistics        ║\n")
cat("╠══════════════════════════════════════════╣\n")
cat(sprintf("║  Period         : %s to %s ║\n",
            format(df$Date[1],        "%Y-%m-%d"),
            format(df$Date[nrow(df)], "%Y-%m-%d")))
cat(sprintf("║  Trading days   : %-4d                    ║\n", nrow(df)))
cat(sprintf("║  Start price    : $%-7.2f                ║\n", df$Adj[1]))
cat(sprintf("║  End price      : $%-7.2f                ║\n", df$Adj[nrow(df)]))
cat(sprintf("║  Total return   : %+.2f%%                  ║\n", total_return))
cat(sprintf("║  Max drawdown   : %.2f%%                  ║\n", max_dd))
cat(sprintf("║  Ann. volatility: %.2f%%                   ║\n", ann_vol))
cat(sprintf("║  Sharpe ratio   : %.4f (rf=0)            ║\n", sharpe))
cat(sprintf("║  Positive days  : %.1f%%                   ║\n", pos_days_pct))
cat("╚══════════════════════════════════════════╝\n\n")


# ── 7. CUSTOM THEME ───────────────────────────────────────────────────────────
# A clean, minimal ggplot2 theme shared across all four charts.

theme_bdry <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      # Titles and captions
      plot.title       = element_text(face  = "bold", size  = 14,
                                      colour = "#1a1a2e", margin = margin(b = 4)),
      plot.subtitle    = element_text(size  = 10,  colour = "#555555",
                                      margin = margin(b = 8)),
      plot.caption     = element_text(size  = 8,   colour = "#999999",
                                      hjust = 1),
      # Background
      plot.background  = element_rect(fill = "#fafafa", colour = NA),
      panel.background = element_rect(fill = "#fafafa", colour = NA),
      # Grid lines
      panel.grid.major = element_line(colour = "#e0e0e0", linewidth = 0.35),
      panel.grid.minor = element_blank(),
      # Axis text
      axis.text        = element_text(colour = "#444444", size = 9),
      axis.title       = element_text(colour = "#555555", size = 10),
      # Legend
      legend.position   = "bottom",
      legend.key.size   = unit(0.8, "lines"),
      legend.text       = element_text(size = 9),
      legend.background = element_rect(fill = "#fafafa", colour = NA)
    )
}


# ── 8. VISUALISATION ─────────────────────────────────────────────────────────
# Each chart is built, saved to disk as a PNG, then printed to the active
# graphics device (RStudio Plots pane or a new window) so it is visible
# immediately — no viewer setup required.

message("[5/5] Generating and saving charts ...")

# Helper: shared subtitle with date range
date_range_label <- paste0(
  "Breakwave Dry Bulk Shipping ETF  |  ",
  format(df$Date[1],        "%d %b %Y"), " – ",
  format(df$Date[nrow(df)], "%d %b %Y")
)


# ── CHART 1: Candlestick + Moving Averages + Volume ──────────────────────────
# Top panel: OHLC candlestick chart with SMA20 and SMA50 overlaid.
# Bottom panel: daily volume bars coloured by direction.

p1_price <- ggplot(df, aes(x = Date)) +

  # Candlestick wicks: thin vertical lines from Low to High
  geom_segment(
    aes(xend = Date, y = Low, yend = High),
    colour    = "#aaaaaa",
    linewidth = 0.3
  ) +

  # Candlestick bodies: rectangles from Open to Close
  geom_rect(
    aes(
      xmin = Date - 0.4, xmax = Date + 0.4,
      ymin = pmin(Open, Close),
      ymax = pmax(Open, Close),
      fill = Direction
    ),
    alpha = 0.9
  ) +
  scale_fill_manual(
    values = c("Bullish" = COL_BULL, "Bearish" = COL_BEAR),
    name   = NULL
  ) +

  # 20-day SMA (short-term trend signal)
  geom_line(aes(y = SMA20, colour = "SMA 20"), linewidth = 0.9,
            na.rm = TRUE) +
  # 50-day SMA (medium-term trend signal)
  geom_line(aes(y = SMA50, colour = "SMA 50"), linewidth = 0.9,
            linetype = "dashed", na.rm = TRUE) +
  scale_colour_manual(
    values = c("SMA 20" = COL_BLUE, "SMA 50" = COL_NAVY),
    name   = NULL
  ) +

  scale_y_continuous(labels = dollar_format(prefix = "$")) +
  labs(
    title    = "BDRY — Price Chart with Moving Averages",
    subtitle = date_range_label,
    x        = NULL,
    y        = "Price (USD)",
    caption  = "Source: Yahoo Finance via quantmod"
  ) +
  theme_bdry() +
  guides(
    fill   = guide_legend(order = 1),
    colour = guide_legend(order = 2)
  )

p1_volume <- ggplot(df, aes(x = Date, y = Volume / 1e6, fill = Direction)) +
  geom_col(alpha = 0.75, width = 0.8) +
  scale_fill_manual(
    values = c("Bullish" = COL_BULL, "Bearish" = COL_BEAR),
    name   = NULL
  ) +
  scale_y_continuous(labels = label_number(suffix = "M")) +
  labs(x = "Date", y = "Volume") +
  theme_bdry() +
  theme(legend.position = "none")

# Stack price (75%) above volume (25%) using patchwork
plot1 <- p1_price / p1_volume + plot_layout(heights = c(3, 1))

ggsave(
  filename = file.path(OUTPUT_DIR, "01_price_volume_MA.png"),
  plot     = plot1,
  width    = PLOT_W,
  height   = PLOT_H + 2,
  dpi      = DPI,
  bg       = "#fafafa"
)
message("  Saved: 01_price_volume_MA.png")
print(plot1)


# ── CHART 2: Bollinger Bands + RSI ───────────────────────────────────────────
# Top panel: price overlaid with Bollinger Bands (shaded region between bands).
# Bottom panel: RSI(14) with overbought/oversold reference lines.

p2_bb <- ggplot(df, aes(x = Date)) +

  # Shaded area between upper and lower Bollinger Bands
  geom_ribbon(
    aes(ymin = BB_lower, ymax = BB_upper),
    fill  = COL_ORANGE,
    alpha = 0.12,
    na.rm = TRUE
  ) +
  # Upper Bollinger Band
  geom_line(aes(y = BB_upper, colour = "Upper Band"),
            linewidth = 0.6, linetype = "dashed", na.rm = TRUE) +
  # Lower Bollinger Band
  geom_line(aes(y = BB_lower, colour = "Lower Band"),
            linewidth = 0.6, linetype = "dashed", na.rm = TRUE) +
  # Middle band (= SMA20)
  geom_line(aes(y = BB_mid, colour = "Middle (SMA 20)"),
            linewidth = 0.75, na.rm = TRUE) +
  # Adjusted close price
  geom_line(aes(y = Adj, colour = "Price"),
            linewidth = 0.75, na.rm = TRUE) +

  scale_colour_manual(
    values = c(
      "Price"           = COL_NAVY,
      "Middle (SMA 20)" = COL_BLUE,
      "Upper Band"      = COL_ORANGE,
      "Lower Band"      = COL_ORANGE
    ),
    name = NULL
  ) +
  scale_y_continuous(labels = dollar_format(prefix = "$")) +
  labs(
    title    = "BDRY — Bollinger Bands & RSI",
    subtitle = paste0(date_range_label,
                      "  |  BB: 20-day, 2σ  |  RSI: 14-day"),
    x        = NULL,
    y        = "Price (USD)",
    caption  = "Source: Yahoo Finance via quantmod"
  ) +
  theme_bdry()

p2_rsi <- ggplot(df, aes(x = Date, y = RSI14)) +

  # Overbought zone (RSI > 70): shaded red
  annotate("rect",
    xmin  = df$Date[1], xmax  = df$Date[nrow(df)],
    ymin  = 70,         ymax  = 100,
    alpha = 0.06,       fill  = COL_BEAR
  ) +
  # Oversold zone (RSI < 30): shaded green
  annotate("rect",
    xmin  = df$Date[1], xmax  = df$Date[nrow(df)],
    ymin  = 0,          ymax  = 30,
    alpha = 0.06,       fill  = COL_BULL
  ) +

  # Reference lines at 70, 50 (neutral), and 30
  geom_hline(yintercept = 70, colour = COL_BEAR,  linewidth = 0.5,
             linetype = "dashed") +
  geom_hline(yintercept = 50, colour = "#888888", linewidth = 0.4,
             linetype = "dotted") +
  geom_hline(yintercept = 30, colour = COL_BULL,  linewidth = 0.5,
             linetype = "dashed") +

  # RSI line
  geom_line(colour = COL_PURPLE, linewidth = 0.8, na.rm = TRUE) +

  # Zone labels
  annotate("text", x = df$Date[6], y = 73,
           label = "Overbought (70)", size = 3,
           colour = COL_BEAR, hjust = 0) +
  annotate("text", x = df$Date[6], y = 27,
           label = "Oversold (30)", size = 3,
           colour = COL_BULL, hjust = 0) +

  scale_y_continuous(limits = c(0, 100),
                     breaks = c(0, 30, 50, 70, 100)) +
  labs(x = "Date", y = "RSI (14)") +
  theme_bdry()

plot2 <- p2_bb / p2_rsi + plot_layout(heights = c(3, 2))

ggsave(
  filename = file.path(OUTPUT_DIR, "02_bollinger_RSI.png"),
  plot     = plot2,
  width    = PLOT_W,
  height   = PLOT_H + 2,
  dpi      = DPI,
  bg       = "#fafafa"
)
message("  Saved: 02_bollinger_RSI.png")
print(plot2)


# ── CHART 3: Daily Returns Distribution ──────────────────────────────────────
# Histogram of daily log returns with a kernel density overlay.
# Bars are coloured green (positive) / red (negative).
# Summary statistics are shown in an annotation box.

ret_mean   <- mean(returns_clean)
ret_median <- median(returns_clean)
ret_sd     <- sd(returns_clean)
ret_skew   <- skewness(returns_clean)
ret_kurt   <- kurtosis(returns_clean)

# Build annotation text for the stats box
stats_label <- paste0(
  "σ daily:     ", round(ret_sd,            3), "%\n",
  "σ annual:  ",  round(ret_sd * sqrt(252), 2), "%\n",
  "Skewness: ",        round(ret_skew,            3), "\n",
  "Kurtosis:   ",      round(ret_kurt,            3)
)

plot3 <- ggplot(
  df %>% filter(!is.na(Return)),
  aes(x = Return, fill = Return >= 0)
) +

  # Histogram bins coloured by sign of return
  geom_histogram(
    binwidth  = 0.5,
    colour    = "white",
    linewidth = 0.2,
    alpha     = 0.85
  ) +

  # Scaled kernel density curve overlaid on the histogram.
  # inherit.aes = FALSE prevents the fill aesthetic carrying over.
  geom_density(
    mapping = aes(
      x = Return,
      y = after_stat(density) * nrow(df %>% filter(!is.na(Return))) * 0.5
    ),
    colour      = COL_NAVY,
    linewidth   = 0.9,
    adjust      = 1.5,
    inherit.aes = FALSE
  ) +

  # Vertical reference lines
  geom_vline(xintercept = 0,          colour = "#666666",
             linewidth = 0.5) +
  geom_vline(xintercept = ret_mean,   colour = COL_ORANGE,
             linewidth = 0.9, linetype = "dashed") +
  geom_vline(xintercept = ret_median, colour = COL_PURPLE,
             linewidth = 0.9, linetype = "dotted") +

  # Mean label
  annotate("text",
    x      = ret_mean + 0.15,
    y      = Inf,
    label  = paste0("Mean: ", round(ret_mean, 3), "%"),
    colour = COL_ORANGE, size = 3.5,
    vjust  = 2.5, hjust = 0
  ) +
  # Median label
  annotate("text",
    x      = ret_median - 0.15,
    y      = Inf,
    label  = paste0("Median: ", round(ret_median, 3), "%"),
    colour = COL_PURPLE, size = 3.5,
    vjust  = 4.5, hjust = 1
  ) +

  # Stats box (top-right corner)
  annotate("label",
    x          = Inf, y = Inf,
    hjust      = 1.05, vjust = 1.3,
    label      = stats_label,
    size       = 3.2,
    fill       = "white",
    colour     = "#444444",
    label.size = 0.3
  ) +

  scale_fill_manual(
    values = c("TRUE" = COL_BULL, "FALSE" = COL_BEAR),
    labels = c("TRUE" = "Positive return", "FALSE" = "Negative return"),
    name   = NULL
  ) +
  labs(
    title    = "BDRY — Daily Log Returns Distribution",
    subtitle = paste0(date_range_label, "  |  ", length(returns_clean),
                      " observations"),
    x        = "Daily Log Return (%)",
    y        = "Count",
    caption  = "Source: Yahoo Finance via quantmod"
  ) +
  theme_bdry()

ggsave(
  filename = file.path(OUTPUT_DIR, "03_returns_distribution.png"),
  plot     = plot3,
  width    = PLOT_W,
  height   = PLOT_H,
  dpi      = DPI,
  bg       = "#fafafa"
)
message("  Saved: 03_returns_distribution.png")
print(plot3)


# ── CHART 4: Cumulative Return & Drawdown ────────────────────────────────────
# Top panel: cumulative log return over time (shaded area above/below zero).
# Bottom panel: drawdown — how far price has fallen from its rolling peak.

# Choose fill colour for the cumulative return ribbon by overall sign
cum_fill_col <- ifelse(df$CumReturn[nrow(df)] >= 0, COL_BULL, COL_BEAR)

p4_cum <- ggplot(df, aes(x = Date)) +

  # Zero reference line
  geom_hline(yintercept = 0, colour = "#888888",
             linewidth = 0.5, linetype = "dashed") +

  # Shaded ribbon: above zero = green, below zero = red
  geom_ribbon(
    aes(ymin = pmin(CumReturn, 0), ymax = pmax(CumReturn, 0)),
    fill  = cum_fill_col,
    alpha = 0.25
  ) +

  # Cumulative return line
  geom_line(aes(y = CumReturn), colour = COL_NAVY,
            linewidth = 0.9, na.rm = TRUE) +

  scale_y_continuous(labels = function(x) paste0(round(x, 1), "%")) +
  labs(
    title    = "BDRY — Cumulative Return & Drawdown",
    subtitle = paste0(
      date_range_label, "\n",
      sprintf("Total return: %+.2f%%  |  Max drawdown: %.2f%%",
              total_return, max_dd)
    ),
    x        = NULL,
    y        = "Cumulative Return (%)",
    caption  = "Source: Yahoo Finance via quantmod"
  ) +
  theme_bdry()

p4_dd <- ggplot(df, aes(x = Date, y = Drawdown)) +

  # Filled area between drawdown and zero (always at or below zero)
  geom_ribbon(aes(ymin = Drawdown, ymax = 0),
              fill  = COL_BEAR,
              alpha = 0.45) +

  # Drawdown line
  geom_line(colour = COL_BEAR, linewidth = 0.7, na.rm = TRUE) +

  scale_y_continuous(labels = function(x) paste0(round(x, 1), "%")) +
  labs(x = "Date", y = "Drawdown (%)") +
  theme_bdry()

plot4 <- p4_cum / p4_dd + plot_layout(heights = c(3, 2))

ggsave(
  filename = file.path(OUTPUT_DIR, "04_cumulative_drawdown.png"),
  plot     = plot4,
  width    = PLOT_W,
  height   = PLOT_H + 2,
  dpi      = DPI,
  bg       = "#fafafa"
)
message("  Saved: 04_cumulative_drawdown.png")
print(plot4)


# ── 9. DONE ───────────────────────────────────────────────────────────────────
message("\n✓ Pipeline complete!")
message("  Charts displayed above and saved to ./", OUTPUT_DIR, "/")
message("  01_price_volume_MA.png      – Candlestick + SMA20/50 + volume")
message("  02_bollinger_RSI.png        – Bollinger Bands + RSI (14-day)")
message("  03_returns_distribution.png – Daily log-return histogram")
message("  04_cumulative_drawdown.png  – Cumulative return + drawdown")
