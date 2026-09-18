
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
#> Downloading catch ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ |  65 MB/ 65 MB ETA:  0s
#> Downloading haul ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ | 4.7 MB/4.7 MB ETA:  0s
#> Downloading taxon ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ |  49 kB/ 49 kB ETA:  0s
#> Downloading survey ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ | 0.7 kB/0.7 kB ETA:  0s
#> Building the local FishGlob DuckDB database
#> FishGlob data are ready in
#> ~/Library/Caches/org.R-project.R/R/fishglobr/fishglob.duckdb
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
head(dat[c("scientific_name", "year", "latitude", "longitude", "wgt_cpue")], n = 3)
#>      scientific_name year latitude longitude wgt_cpue
#> 1 Sebastes fasciatus 2021 41.40189 -66.16553    0.002
#> 2 Sebastes fasciatus 2021 41.93574 -65.85122    0.016
#> 3 Sebastes fasciatus 2021 42.17893 -67.67522    1.260
```
