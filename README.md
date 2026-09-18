
<!-- README.md is generated from README.Rmd. Please edit that file -->

# fishglobr

<!-- badges: start -->

<!-- badges: end -->

## THIS IS AN EXPERIMENTAL DRAFT PROJECT NOT BE USED AT THIS STAGE!

fishglobr (perhaps to be renamed to fishglob) is an R package for
efficiently downloading, caching, and querying the
[FishGlob](https://fishglob.sites.ucsc.edu/) database. FISHGLOB is an
international consortium of scientists, experts and data providers who
collect, curate, standardize, share and analyse data from scientific
bottom trawl surveys.

## Installation

You can install the development version of fishglobr like so:

``` r
# temporary location; to be moved to fishglob group
pak::pak("seananderson/fishglobr")
```

## Example

First we load the package and download and install the database locally.
We only have to do this once. The data is stored in a local DuckDB
database.

``` r
library(fishglobr)
install_fishglob_data()
```

``` r
# Find available agency data sources
get_sources()
#> [1] "DATRAS ICES" "DFO"         "IMR"         "NOAA"

# The full list of available species:
spp <- get_scientific_names()
spp[1:5]
#> [1] "Ablennes hians"             "Abudefduf saxatilis"       
#> [3] "Acanthemblemaria"           "Acantholabrus palloni"     
#> [5] "Acantholiparis opercularis"

# All Canary Rockfish data held by DFO
dat <- get_data(
  scientific_name = "sebastes pinniger",
  source = "DFO"
)
nrow(dat)
#> [1] 1106

# All Sebastes data globally from 2000 to 2021
# using a regular expression
dat <- get_data(
  scientific_name = "^sebastes*",
  regex = TRUE,
  year = 2000:2021
)
head(dat[c("survey_unit", "year", "latitude", "longitude", "wgt_cpue")], n = 3)
#>   survey_unit year latitude longitude   wgt_cpue
#> 1   NEUS-Fall 2021 42.04747 -67.71460 0.06549118
#> 2   NEUS-Fall 2021 41.84667 -68.20291 0.25524769
#> 3   NEUS-Fall 2021 42.20143 -66.86743 1.13853904
```
