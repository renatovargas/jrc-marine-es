# Convert the marine region shapefiles into a single GeoPackage.
#
# Seven shapefiles, each with six or seven sidecar files, were replaced by one
# GeoPackage. Two reasons. First, QGIS writes layer metadata sidecars with a
# .qmd extension, which Quarto picks up as documents; that broke the site build
# until `_quarto.yml` gained a render exclusion, and removing the sidecars
# removes the trap at source. Second, the shapefile DBF format truncates field
# names to ten characters, which is how the legacy attribute `Tonnes_2023`
# became `Tonnes_202`.
#
# All attributes are carried across unchanged, including the result columns the
# previous team joined in by hand in QGIS. Those columns are legacy. Do not use
# them; results are joined to the geometry at render time now.
#
# This script is kept as a record. It cannot be rerun, because the shapefiles it
# reads were deleted once the GeoPackage was verified.
#
# Run from the project root:
#   Rscript data/gisdata/shapefiles_to_gpkg.R

library(sf)
library(dplyr)

sf_use_s2(FALSE)

gpkg <- "data/gisdata/marine_regions.gpkg"

# The `_modified` layers are the authoritative ones. Baltic (10) plus Black (3)
# plus Mediterranean (7) plus modified NEAO (38) reproduce the F_CODE set of the
# 58 feature European layer exactly; the unmodified NEAO does not. The
# modification was a dissolve of the finer FAO subdivisions, the same collapse
# that `sub_reg_recodes` performs in the processing routine. The unmodified NEAO
# is kept as a separate layer because its 55 features are the only record we
# have of the finer geometry.
#
# The unmodified Mediterranean layer is kept for the opposite reason. Its
# geometry is identical to the modified one, but it is the only place the
# published 2023 attributes Tonnes_202, Money_23, OverTonnes and OverLand
# survive.
layers <- tribble(
  ~shapefile,                          ~layer,                    ~note,
  "Macro_Division_European_Sea",       "sea_regions_macro",       "Four pan-European regions; join on Sea_name",
  "European Sea Divion_Regions",       "sea_regions_division",    "58 FAO divisions and subdivisions; join on F_CODE",
  "Baltic_Sea_Region",                 "baltic_sea",              "10 subdivisions of 27.3.d",
  "Black_Sea_Region",                  "black_sea",               "3 divisions of 37.4",
  "Mediterranean_Sea_Region_modified", "mediterranean_sea",       "7 FAO divisions of area 37",
  "NEAO_Sea_Region_modified",          "neao",                    "38 divisions, dissolved to accounting level",
  "NEAO_Sea_Region",                   "neao_fao_subdivisions",   "55 features at finer FAO subdivision level",
  "Mediterranean_Sea_Region",          "mediterranean_legacy",    "Same geometry as mediterranean_sea; carries the published 2023 attributes"
)

if (file.exists(gpkg)) file.remove(gpkg)

for (i in seq_len(nrow(layers))) {
  path <- file.path("data/gisdata", paste0(layers$shapefile[i], ".shp"))
  message("Reading ", layers$shapefile[i], " ...")
  # The accented characters in NAME_FR and NAME_ES are unrecoverable. The DBF
  # holds 74 literal U+FFFD replacement bytes and no Latin-1 accented bytes at
  # all, so the damage predates this repository; some earlier export destroyed
  # them. They are copied across as they are. Use NAME_EN, which is clean.
  x <- st_read(path, quiet = TRUE)

  st_write(x, gpkg, layer = layers$layer[i], quiet = TRUE, append = TRUE)
  message("  wrote layer '", layers$layer[i], "' (", nrow(x), " features)")
}

message("\n", gpkg, " (", round(file.size(gpkg) / 1024^2, 1), " MB)")
print(st_layers(gpkg))
