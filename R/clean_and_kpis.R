# Example of cleaning raw data and calculating KPIs in R
# Anthony Hobson

library(dplyr)
library(readr)
library(stringr)
library(lubridate)

raw_dir   <- "data/raw"
clean_dir <- "data/clean"
dir.create(clean_dir, recursive = TRUE, showWarnings = FALSE)

batches  <- read_csv(file.path(raw_dir, "batches.csv"),  col_types = cols(.default = "c"), trim_ws = FALSE)
downtime <- read_csv(file.path(raw_dir, "downtime.csv"), col_types = cols(.default = "c"), trim_ws = FALSE)

dq_log <- tibble(issue = character(), rows_affected = integer(), fix = character())
log_issue <- function(issue, n, fix) {
  dq_log <<- add_row(dq_log, issue = issue, rows_affected = as.integer(n), fix = fix)
}
rows_before <- nrow(batches)

# 1. Duplicates 
n_dup   <- sum(duplicated(batches))
batches <- distinct(batches)
log_issue("Duplicate batch rows", n_dup, "Removed")
stopifnot(n_distinct(batches$batch_id) == nrow(batches))

# 2. Inconsistent product names (case and spaces) 
valid_products <- c("mAb-101", "mAb-205", "mAb-310", "Fc-412", "mAb-518", "mAb-623")
clean_name <- function(x) {
  x <- str_trim(x)
  valid_products[match(str_to_lower(x), str_to_lower(valid_products))]
}
n_bad_name <- sum(!batches$product %in% valid_products)
batches    <- batches |> mutate(product = clean_name(product))
stopifnot(!any(is.na(batches$product)))
log_issue("Product name with wrong case or extra spaces", n_bad_name, "Standardised to official name")

# 3. Dates typed in two formats (yyyy-mm-dd and dd/mm/yyyy) 
n_bad_date <- sum(str_detect(batches$start_date, "/"))
batches <- batches |>
  mutate(start_date = as_date(parse_date_time(start_date, orders = c("Ymd", "dmY"))),
         across(c(end_date, qa_release_date, promised_date, delivered_date), as_date))
stopifnot(!any(is.na(batches$start_date)), all(batches$end_date > batches$start_date))
log_issue("Start date typed as dd/mm/yyyy", n_bad_date, "Parsed both formats to one date type")

# 4. Numbers and missing values 
batches <- batches |>
  mutate(across(c(target_titer_g_L, actual_titer_g_L, harvest_volume_L, purified_kg,
                  deviations, electricity_kwh), as.numeric))
log_issue("Missing actual titer", sum(is.na(batches$actual_titer_g_L)),
          "Kept batch; excluded from yield KPI only")

# 5. KPI  
solar_from <- as_date("2025-10-01")
batches <- batches |>
  mutate(
    is_success         = status != "Rejected",                       # batch success
    is_rft             = status == "Released" & deviations == 0,     # right first time
    titer_vs_target    = actual_titer_g_L / target_titer_g_L,        # yield vs plan
    run_days           = as.numeric(end_date - start_date),
    qa_lead_days       = as.numeric(qa_release_date - end_date),
    on_time            = delivered_date <= promised_date,            # NA if rejected
    electricity_source = if_else(start_date >= solar_from, "Solar", "Grid mix"),
    # Assumption: 0.12 kg CO2e/kWh for grid electricity, 0 for solar (market-based scope 2)
    co2e_kg            = electricity_kwh * if_else(electricity_source == "Grid mix", 0.12, 0),
    kwh_per_kg         = if_else(purified_kg > 0, electricity_kwh / purified_kg, NA_real_),
    year               = year(end_date),
    month              = floor_date(end_date, "month")
  )

downtime <- downtime |>
  mutate(date = as_date(date), hours = as.numeric(hours), month = floor_date(date, "month"))

# 6. Reconciliation and KPI summary
log_issue("Rows before vs after cleaning", rows_before - nrow(batches),
          paste(rows_before, "rows in,", nrow(batches), "unique batches out"))

kpi <- function(df) df |> summarise(
  batches            = n(),
  batch_success_rate = mean(is_success),
  rft_rate           = mean(is_rft),
  titer_vs_target    = mean(titer_vs_target, na.rm = TRUE),
  on_time_delivery   = mean(on_time, na.rm = TRUE),
  purified_kg        = sum(purified_kg),
  co2e_tonnes        = sum(co2e_kg) / 1000)

kpi_summary <- bind_rows(
  batches |> kpi() |> mutate(period = "All (Jan 2025 - Oct 2026)", .before = 1),
  batches |> group_by(period = as.character(year)) |> kpi()
)
kpi_summary <- kpi_summary |>
  mutate(unplanned_downtime_h = c(
    sum(downtime$hours[downtime$category == "Unplanned"]),
    sapply(period[-1], \(y) sum(downtime$hours[downtime$category == "Unplanned" &
                                                 year(downtime$date) == as.integer(y)]))))
print(kpi_summary, width = Inf)

kpi_by_bioreactor <- batches |>
  mutate(period = if_else(end_date >= as_date("2025-09-01"), "Sep 2025 on", "Before Sep 2025")) |>
  group_by(bioreactor, period) |> kpi() |> ungroup()

# 7. A statistical check on the main finding 
recent <- filter(batches, end_date >= as_date("2025-09-01"))
tab <- table(br07 = recent$bioreactor == "BR-07", rft = recent$is_rft)
print(tab)
print(fisher.test(tab))

# 8. Export (blank cells, not "NA")
out <- function(df, name) write_csv(df, file.path(clean_dir, name), na = "")
out(select(batches, -year), "batches_clean.csv")
out(downtime,               "downtime_clean.csv")
out(tibble(bioreactor = sort(unique(c(batches$bioreactor, downtime$bioreactor)))), "dim_bioreactor.csv")
out(kpi_summary,            "kpi_summary.csv")
out(kpi_by_bioreactor,      "kpi_by_bioreactor.csv")
out(dq_log,                 "data_quality_log.csv")
print(dq_log)
