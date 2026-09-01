# Convert the STECF fleet segment workbook into two RDS datasets.
#
# The source workbook is a single 285 MB xlsx that is too large and too clunky
# to keep under version control. This script extracts the four sheets we use,
# binds the three landings sheets into one table, and writes both results as
# RDS files alongside it. Only the RDS files are committed.
#
# Run from the project root:
#   Rscript data/stecf/stecf_to_rds.R

library(readxl)
library(dplyr)

source_file <- paste0(
  "data/stecf/STECF_25 07_EU Fleet Economic and Transversal data_",
  "fleet segment level.xlsx"
)
output_dir <- "data/stecf"

landings_sheets <- c(
  "FS_landings FAO 2008-2012",
  "FS_landings FAO 2013-2017",
  "FS_landings FAO 2018-2023"
)
economic_sheet <- "FS data"

# Column types are declared by name rather than left to readxl's guesser. The
# guesser reads cluster_name as logical in the 2018-2023 sheet, where the column
# happens to be empty, and as text in the other two; binding those together
# would fail. Declaring the types also makes the script stop with a clear error
# if a future data call changes the sheet layout, which is what we want for a
# routine that is re-run every year.
landings_types <- c(
  upload_date    = "date",
  country_name   = "text",
  country_code   = "text",
  year           = "numeric",
  supra_reg      = "text",
  fishing_tech   = "text",
  vessel_length  = "text",
  geo_indicator  = "text",
  cluster_name   = "text",
  fs_name        = "text",
  variable_group = "text",
  variable_name  = "text",
  variable_code  = "text",
  value          = "numeric",
  unit           = "text",
  species_name   = "text",
  species_code   = "text",
  sub_reg        = "text",
  fromtable      = "text",
  framework      = "text",
  template_name  = "text",
  gear           = "text",
  fishery        = "text",
  activity       = "text"
)

economic_types <- landings_types[
  !names(landings_types) %in% c("species_name", "species_code", "sub_reg")
]

read_stecf_sheet <- function(path, sheet, types) {
  message("Reading '", sheet, "' ...")
  header <- names(read_excel(path, sheet = sheet, n_max = 0))
  if (!identical(header, names(types))) {
    stop(
      "Unexpected layout in sheet '", sheet, "'.\n",
      "  expected: ", paste(names(types), collapse = ", "), "\n",
      "  found:    ", paste(header, collapse = ", "),
      call. = FALSE
    )
  }
  read_excel(path, sheet = sheet, col_types = unname(types)) |>
    mutate(source_sheet = sheet)
}

describe <- function(data, label) {
  years <- sort(unique(data$year))
  message(
    label, ": ", format(nrow(data), big.mark = ","), " rows, ",
    ncol(data), " columns, years ", min(years), "-", max(years)
  )
  data |>
    summarise(
      rows = n(),
      reported = sum(!is.na(value)),
      pct_reported = round(100 * sum(!is.na(value)) / n()),
      .by = year
    ) |>
    arrange(year) |>
    as.data.frame() |>
    print(row.names = FALSE)
  invisible(data)
}

stopifnot(file.exists(source_file))

# Landings: species by FAO sub-region, in kilograms and in euro.
fs_landings <- landings_sheets |>
  lapply(read_stecf_sheet, path = source_file, types = landings_types) |>
  bind_rows() |>
  arrange(year, country_code, fs_name)

describe(fs_landings, "FS landings")

# Economic and transversal variables, at fleet segment level only.
fs_data <- read_stecf_sheet(source_file, economic_sheet, economic_types) |>
  arrange(year, country_code, fs_name)

describe(fs_data, "FS data")

landings_out <- file.path(output_dir, "FS_landings_FAO_2008-2024.RDS")
data_out <- file.path(output_dir, "FS_data_2008-2024.RDS")

saveRDS(fs_landings, landings_out)
saveRDS(fs_data, data_out)

message(
  "\nWrote:\n",
  "  ", landings_out, " (",
  round(file.size(landings_out) / 1024^2, 1), " MB)\n",
  "  ", data_out, " (",
  round(file.size(data_out) / 1024^2, 1), " MB)"
)
