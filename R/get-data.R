.connect_fishglob <- function() {
  database_path <- .fishglob_database_path()
  if (!file.exists(database_path)) {
    cli::cli_abort(
      "FishGlob data are not installed. Run {.code install_fishglob_data()}."
    )
  }
  DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE),
    dbdir = database_path,
    read_only = TRUE
  )
}

.as_lower_text <- function(x) tolower(as.character(x))

#' Query FishGlob survey data
#'
#' @description Functions to query the FishGlob database. These functions assume the user has already run [install_fishglob_data()] once to cache the FishGlob data in a local database on their computer.
#'
#' `get_data()`: The main data querying function. Returns a data frame of matching survey catch records with joined haul, survey, and taxon information.
#'
#' `get_surveys()`: Return available survey-unit IDs.
#'
#' `get_continents()`: Return available continents.
#'
#' `get_sources()`: Return available data sources.
#'
#' `get_scientific_names()`: Return available accepted scientific names.
#'
#' `get_catch_table()`: Return the complete catch table.
#'
#' `get_taxon_table()`: Return the complete taxon table.
#'
#' `get_haul_table()`: Return the complete haul table.
#'
#' `get_survey_table()`: Return the complete survey table.
#'
#' @param scientific_name Scientific name(s). See [get_scientific_names()].
#' @param regex If `TRUE`, interpret `scientific_name` as
#'   regular expressions. For example, `"^hippo*"` matches names starting with "hippo".
#' @param family Taxonomic family name(s). See [get_taxon_table()].
#' @param survey Survey name(s). See [get_surveys()].
#' @param continent Continent name(s), e.g. "europe". See [get_continents()].
#' @param source Data source name(s), e.g. "NOAA" or "DATRAS ICES". See [get_sources()].
#' @param year Vector of years. Defaults to all.
#' @details
#' `get_data()` is the main querying function to return filtered survey catch records. Not all columns are included by default. Additional columns can be
#' appended by joining (e.g., [dplyr::left_join()]) the data returned by `get_data()` with the data from `get_taxon_table()`, `get_haul_table()`, or `get_survey_table()`.
#'
#' @return A data frame of matching data.
#' @seealso [install_fishglob_data()]
#' @export
#' @examples
#' \donttest{
#' # The first time, start by installing the
#' # database locally:
#' install_fishglob_data()
#'
#' # Subsequently, the data does not need to be recached.
#'
#' # Find available agency data sources
#' get_sources()
#'
#' # The full list of available species:
#' spp <- get_scientific_names()
#'
#' # All Canary Rockfish data held by DFO
#' dat <- get_data(
#'   scientific_name = "sebastes pinniger",
#'   source = "DFO"
#' )
#'
#' # All Sebastes data globally from 2000 to 2021
#' dat <- get_data(
#'   scientific_name = "^sebastes*",
#'   regex = TRUE,
#'   year = 2000:2021
#' )
#' }
#'
get_data <- function(
    scientific_name = NULL,
    regex = FALSE,
    family = NULL,
    survey = NULL,
    continent = NULL,
    source = NULL,
    year = NULL
) {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  filters <- list(where = character(), params = list())
  add_filter <- function(filters, column, values) {
    if (is.null(values)) return(filters)
    if (anyNA(values) || length(values) == 0) {
      cli::cli_abort("Filters must contain one or more non-missing values.")
    }
    filters$where <- c(
      filters$where,
      paste0(column, " IN (", paste(rep("?", length(values)), collapse = ", "), ")")
    )
    filters$params <- c(filters$params, as.list(values))
    filters
  }

  if (!is.null(scientific_name)) {
    scientific_name <- .as_lower_text(scientific_name)
    if (regex) {
      filters$where <- c(
        filters$where,
        paste0(
          "(",
          paste(rep("regexp_matches(LOWER(t.accepted_name), ?)", length(scientific_name)), collapse = " OR "),
          ")"
        )
      )
      filters$params <- c(filters$params, as.list(scientific_name))
    } else {
      filters <- add_filter(filters, "LOWER(t.accepted_name)", scientific_name)
    }
  }
  if (!is.null(family)) {
    filters <- add_filter(filters, "LOWER(t.family)", .as_lower_text(family))
  }
  if (!is.null(survey)) {
    survey <- as.character(survey)
    placeholders <- paste(rep("?", length(survey)), collapse = ", ")
    filters$where <- c(filters$where, paste0("(s.survey_unit IN (", placeholders, ") OR s.survey IN (", placeholders, "))"))
    filters$params <- c(filters$params, as.list(survey), as.list(survey))
  }
  if (!is.null(continent)) {
    filters <- add_filter(filters, "LOWER(s.continent)", .as_lower_text(continent))
  }
  if (!is.null(source)) {
    filters <- add_filter(filters, "LOWER(s.source)", .as_lower_text(source))
  }
  if (!is.null(year)) {
    filters <- add_filter(filters, "TRY_CAST(LEFT(h.timestamp, 4) AS INTEGER)", as.integer(year))
  }

  sql <- paste0(
    'SELECT
       h.haul_id,
       h.survey_unit,
       h.timestamp,
       h.latitude,
       h.longitude,
       h.haul_dur,
       h.area_swept,
       h.gear,
       h.depth,
       h.sbt,
       h.sst,
       s.survey,
       s.source,
       s.continent,
       TRY_CAST(LEFT(h.timestamp, 4) AS INTEGER) AS year,
       t.accepted_name AS scientific_name,
       t.aphia_id,
       t.family,
       c.num,
       c.wgt,
       c.num_cpue,
       c.wgt_cpue,
       c.num_cpua,
       c.wgt_cpua
     FROM "catch" AS c
     JOIN haul AS h USING (haul_id)
     JOIN survey AS s USING (survey_unit)
     JOIN taxon AS t USING (taxon_id)',
    if (length(filters$where)) paste0(" WHERE ", paste(filters$where, collapse = " AND ")) else ""
  )

  DBI::dbGetQuery(con, sql, params = filters$params)
}

#' `get_surveys()`: Return available survey-unit IDs
#' @rdname get_data
#' @export
get_surveys <- function() {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT survey_unit FROM survey ORDER BY survey_unit")$survey_unit
}

#' `get_continents()`: Return available continents
#' @rdname get_data
#' @export
get_continents <- function() {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT DISTINCT continent FROM survey ORDER BY continent")$continent
}

#' `get_sources()`: Return available data sources
#' @rdname get_data
#' @export
get_sources <- function() {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT DISTINCT source FROM survey ORDER BY source")$source
}

#' `get_scientific_names()`: Return available accepted scientific names
#' @rdname get_data
#' @export
get_scientific_names <- function() {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT DISTINCT accepted_name FROM taxon ORDER BY accepted_name")$accepted_name
}

.get_table <- function(table_name) {
  con <- .connect_fishglob()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, paste0("SELECT * FROM ", DBI::dbQuoteIdentifier(con, table_name)))
}

#' `get_catch_table()`: Return the complete catch table
#' @rdname get_data
#' @export
get_catch_table <- function() .get_table("catch")

#' `get_taxon_table()`: Return the complete taxon table
#' @rdname get_data
#' @export
get_taxon_table <- function() .get_table("taxon")

#' `get_haul_table()`: Return the complete haul table
#' @rdname get_data
#' @export
get_haul_table <- function() .get_table("haul")

#' `get_survey_table()`: Return the complete survey table
#' @rdname get_data
#' @export
get_survey_table <- function() .get_table("survey")
