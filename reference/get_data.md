# Query FishGlob survey data

Functions to query the FishGlob database. These functions assume the
user has already run
[`install_fishglob_data()`](https://seananderson.github.io/fishglobr/reference/install_fishglob_data.md)
once to cache the FishGlob data in a local database on their computer.

`get_data()`: The main data querying function. Returns a data frame of
matching survey catch records with joined haul, survey, and taxon
information.

`get_surveys()`: Return available survey-unit IDs.

`get_continents()`: Return available continents.

`get_sources()`: Return available data sources.

`get_scientific_names()`: Return available accepted scientific names.

`get_catch_table()`: Return the complete catch table.

`get_taxon_table()`: Return the complete taxon table.

`get_haul_table()`: Return the complete haul table.

`get_survey_table()`: Return the complete survey table.

## Usage

``` r
get_data(
  scientific_name = NULL,
  regex = FALSE,
  family = NULL,
  survey = NULL,
  continent = NULL,
  source = NULL,
  year = NULL
)

get_surveys()

get_continents()

get_sources()

get_scientific_names()

get_catch_table()

get_taxon_table()

get_haul_table()

get_survey_table()
```

## Arguments

- scientific_name:

  Scientific name(s). See `get_scientific_names()`.

- regex:

  If `TRUE`, interpret `scientific_name` as regular expressions. For
  example, `"^hippo*"` matches names starting with "hippo".

- family:

  Taxonomic family name(s). See `get_taxon_table()`.

- survey:

  Survey name(s). See `get_surveys()`.

- continent:

  Continent name(s), e.g. "europe". See `get_continents()`.

- source:

  Data source name(s), e.g. "NOAA" or "DATRAS ICES". See
  `get_sources()`.

- year:

  Vector of years. Defaults to all.

## Value

A data frame of matching data.

## Details

`get_data()` is the main querying function to return filtered survey
catch records. Not all columns are included by default. Additional
columns can be appended by joining (e.g., `dplyr::left_join()`) the data
returned by `get_data()` with the data from `get_taxon_table()`,
`get_haul_table()`, or `get_survey_table()`.

## See also

[`install_fishglob_data()`](https://seananderson.github.io/fishglobr/reference/install_fishglob_data.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# The first time, start by installing the
# database locally:
install_fishglob_data()

# Subsequently, the data does not need to be recached.

# Find available agency data sources
get_sources()

# The full list of available species:
spp <- get_scientific_names()

# All Canary Rockfish data held by DFO
dat <- get_data(
  scientific_name = "sebastes pinniger",
  source = "DFO"
)

# All Sebastes data globally from 2000 to 2021
dat <- get_data(
  scientific_name = "^sebastes*",
  regex = TRUE,
  year = 2000:2021
)
} # }
```
