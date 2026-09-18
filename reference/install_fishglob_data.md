# Download and install FishGlob data

Downloads the FishGlob .rds tables from Dropbox into a cache folder and
builds a local DuckDB database. Later sessions reuse that database.
Intended to be used before
[`get_data()`](https://seananderson.github.io/fishglobr/reference/get_data.md).

## Usage

``` r
install_fishglob_data(force = FALSE)
```

## Arguments

- force:

  If `TRUE`, download all tables again and rebuild the database.

## Value

Invisibly, the path to the cached DuckDB database.

## See also

[`get_data()`](https://seananderson.github.io/fishglobr/reference/get_data.md)

## Examples

``` r
# \donttest{
install_fishglob_data()
#> Using cached catch data
#> Using cached haul data
#> Using cached taxon data
#> Using cached survey data
#> FishGlob data are ready in /home/runner/.cache/R/fishglobr/fishglob.duckdb
# then see ?get_getdata
# }
```
