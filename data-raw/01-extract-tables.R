load("../FishGlob_data/outputs/Compiled_data/FishGlob_public_clean.RData")
library(dplyr)

n_records <- nrow(data)

# primary key: survey_unit
survey <- data |>
  select(survey_unit, survey, source, country, continent) |>
  distinct()

# primary key: haul_id
haul <- data |>
  select(
    haul_id, survey_unit, timestamp, latitude, longitude, sub_area, stat_rec, station,
    stratum, haul_dur, area_swept, gear, depth, sbt, sst
  ) |>
  distinct()

# not all entries have aphia IDs and taxonomy differs across a few aphia IDs currently
#
# FIXME: make aphia primary key
#
# for now, use a custom taxon_id as a proof of concept
taxon_fields <- c(
  "aphia_id", "accepted_name", "SpecCode", "kingdom", "phylum", "class",
  "order", "family", "genus", "rank"
)

taxon <- data |>
  select(all_of(taxon_fields)) |>
  distinct() |>
  arrange(across(all_of(taxon_fields))) |>
  mutate(taxon_id = row_number(), .before = 1)

# don't distinct this table: a haul can contain multiple
# records for the same accepted taxon in some cases.
# `verbatim_*` documents the original reported taxon
catch <- data |>
  select(
    haul_id, all_of(taxon_fields), verbatim_name, verbatim_aphia_id, num,
    num_cpue, num_cpua, wgt, wgt_cpue, wgt_cpua
  ) |>
  left_join(taxon, by = taxon_fields, relationship = "many-to-one") |>
  select(-all_of(taxon_fields)) |>
  relocate(taxon_id, .after = haul_id)

# sanity checks
stopifnot(
  !anyDuplicated(survey$survey_unit),
  !anyDuplicated(haul$haul_id),
  nrow(catch) == n_records,
  !anyNA(catch$taxon_id),
  all(catch$haul_id %in% haul$haul_id),
  all(haul$survey_unit %in% survey$survey_unit)
)

tables <- lapply(
  list(survey = survey, haul = haul, taxon = taxon, catch = catch),
  as.data.frame
)

sapply(tables, nrow)

glimpse(tables$catch)
glimpse(tables$haul)
glimpse(tables$taxon)
glimpse(tables$survey)

# Store base data frames so consumers do not need the tidyverse packages used
# to create these tables just to restore the RDS files.
saveRDS(tables$catch, "data-raw/catch.rds", version = 2)
saveRDS(tables$survey, "data-raw/survey.rds", version = 2)
saveRDS(tables$haul, "data-raw/haul.rds", version = 2)
saveRDS(tables$taxon, "data-raw/taxon.rds", version = 2)

# restart your R session - `data` is large
