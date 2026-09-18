# temporary for now, just use Dropbox:
.fishglob_data_urls <- c(
  catch = "https://www.dropbox.com/scl/fi/2a3gahp7vlr91x32v8s3x/catch.rds?rlkey=1c5rj9jlpm9eieerayiwdk3sj&st=psdqvphp&dl=1",
  haul = "https://www.dropbox.com/scl/fi/rfc7j3w8kgpshlpsifgr3/haul.rds?rlkey=wt1tl3jpnbcl1w1jnr2l90nlb&st=tdhkq12r&dl=1",
  taxon = "https://www.dropbox.com/scl/fi/p89r1wb4s9mh25tq2drp1/taxon.rds?rlkey=dsfc9qia96sau9gxqvhrrvv8k&st=4xz6oaom&dl=1",
  survey = "https://www.dropbox.com/scl/fi/rz3r5tv4c91g3nmmxgart/survey.rds?rlkey=p5415tbbva5zc81eihqudf0ac&st=7elda8jq&dl=1"
)

.fishglob_cache_dir <- function() {
  getOption(
    "fishglobr.cache_dir",
    tools::R_user_dir("fishglobr", which = "cache")
  )
}

.fishglob_database_path <- function() {
  file.path(.fishglob_cache_dir(), "fishglob.duckdb")
}

.fishglob_rds_paths <- function() {
  file.path(.fishglob_cache_dir(), paste0(names(.fishglob_data_urls), ".rds"))
}

.download_with_progress <- function(url, destination, table_name) {
  minimum_live_progress_bytes <- 1024^2
  progress_id <- cli::cli_progress_bar(
    name = paste("Downloading", table_name),
    type = "download",
    total = NA,
    auto_terminate = FALSE,
    clear = FALSE
  )
  succeeded <- FALSE
  on.exit({
    if (!is.null(progress_id)) {
      cli::cli_progress_done(
        id = progress_id,
        result = if (succeeded) "done" else "failed"
      )
    }
  }, add = TRUE)

  handle <- curl::new_handle(
    followlocation = TRUE,
    noprogress = FALSE,
    progressfunction = function(download, upload) {
      download_total <- download[[1]]
      download_current <- download[[2]]
      if (download_total >= minimum_live_progress_bytes) {
        cli::cli_progress_update(
          id = progress_id,
          set = download_current,
          total = download_total
        )
      }
      TRUE
    }
  )
  response <- curl::curl_fetch_disk(url, destination, handle = handle)
  if (response$status_code >= 400) {
    cli::cli_abort("Download failed with HTTP status {response$status_code}.")
  }
  # small files can finish before cli has rendered their first update
  # force a single completed state for these:
  downloaded_bytes <- file.info(destination)$size
  if (downloaded_bytes < minimum_live_progress_bytes) {
    cli::cli_progress_update(
      id = progress_id,
      set = downloaded_bytes,
      total = downloaded_bytes,
      force = TRUE
    )
    # avoid rendering the same completed bar again during on.exit().
    cli::cli_progress_done(id = progress_id, result = "clear")
    progress_id <- NULL
  }
  succeeded <- TRUE
}

.download_fishglob_rds <- function(force = FALSE) {
  cache_dir <- .fishglob_cache_dir()
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  rds_paths <- .fishglob_rds_paths()
  names(rds_paths) <- names(.fishglob_data_urls)

  for (table_name in names(.fishglob_data_urls)) {
    destination <- rds_paths[[table_name]]
    if (file.exists(destination) && !force) {
      cli::cli_inform("Using cached {.file {table_name}} data")
      next
    }

    temporary_path <- tempfile(
      pattern = paste0(table_name, "-"),
      tmpdir = cache_dir,
      fileext = ".rds"
    )
    on.exit(unlink(temporary_path), add = TRUE)
    .download_with_progress(.fishglob_data_urls[[table_name]], temporary_path, table_name)
    # confirm Dropbox returned an R object, rather than an HTML error page
    readRDS(temporary_path)
    if (!file.copy(temporary_path, destination, overwrite = TRUE)) {
      cli::cli_abort("Could not cache {.path {destination}}.")
    }
  }

  rds_paths
}

.validate_fishglob_tables <- function(tables) {
  survey <- tables$survey
  haul <- tables$haul
  taxon <- tables$taxon
  catch <- tables$catch
  stopifnot(
    !anyDuplicated(survey$survey_unit),
    !anyDuplicated(haul$haul_id),
    !anyDuplicated(taxon$taxon_id),
    !anyNA(catch$taxon_id),
    all(haul$survey_unit %in% survey$survey_unit),
    all(catch$haul_id %in% haul$haul_id),
    all(catch$taxon_id %in% taxon$taxon_id)
  )
}

.build_fishglob_database <- function(rds_paths, database_path) {
  progress_id <- cli::cli_progress_bar(
    name = "Building local FishGlob database",
    type = "tasks",
    total = length(rds_paths) + 7,
    auto_terminate = FALSE,
    clear = FALSE
  )
  succeeded <- FALSE
  on.exit({
    cli::cli_progress_done(
      id = progress_id,
      result = if (succeeded) "done" else "failed"
    )
  }, add = TRUE)

  tables <- list()
  for (table_name in names(rds_paths)) {
    cli::cli_progress_update(id = progress_id, status = paste("Reading", table_name), inc = 0)
    tables[[table_name]] <- readRDS(rds_paths[[table_name]])
    cli::cli_progress_update(id = progress_id, inc = 1)
  }

  # DuckDB requires valid UTF-8 strings.
  cli::cli_progress_update(id = progress_id, status = "Normalizing text", inc = 0)
  to_utf8 <- function(x) iconv(x, from = "", to = "UTF-8", sub = "\\uFFFD")
  tables <- lapply(tables, function(table) {
    character_columns <- vapply(table, is.character, logical(1))
    table[character_columns] <- lapply(table[character_columns], to_utf8)
    table
  })
  cli::cli_progress_update(id = progress_id, inc = 1)

  cli::cli_progress_update(id = progress_id, status = "Validating source tables", inc = 0)
  .validate_fishglob_tables(tables)
  cli::cli_progress_update(id = progress_id, inc = 1)

  temporary_database <- tempfile(
    pattern = "fishglob-",
    tmpdir = dirname(database_path),
    fileext = ".duckdb"
  )
  on.exit(unlink(temporary_database), add = TRUE)
  con <- DBI::dbConnect(
    duckdb::duckdb(shared_home = FALSE),
    dbdir = temporary_database,
    read_only = FALSE
  )
  on.exit({
    if (!is.null(con) && DBI::dbIsValid(con)) {
      DBI::dbDisconnect(con, shutdown = TRUE)
    }
  }, add = TRUE)

  schema_sql <- c(
    survey = 'CREATE TABLE survey (survey_unit VARCHAR, survey VARCHAR, source VARCHAR, country VARCHAR, continent VARCHAR)',
    taxon = 'CREATE TABLE taxon (taxon_id INTEGER, aphia_id VARCHAR, accepted_name VARCHAR, SpecCode VARCHAR, kingdom VARCHAR, phylum VARCHAR, "class" VARCHAR, "order" VARCHAR, family VARCHAR, genus VARCHAR, "rank" VARCHAR)',
    haul = 'CREATE TABLE haul (haul_id VARCHAR, survey_unit VARCHAR, timestamp VARCHAR, latitude DOUBLE, longitude DOUBLE, sub_area VARCHAR, stat_rec VARCHAR, station VARCHAR, stratum VARCHAR, haul_dur DOUBLE, area_swept DOUBLE, gear VARCHAR, depth DOUBLE, sbt VARCHAR, sst VARCHAR)',
    catch = 'CREATE TABLE "catch" (haul_id VARCHAR, taxon_id INTEGER, verbatim_name VARCHAR, verbatim_aphia_id DOUBLE, num DOUBLE, num_cpue DOUBLE, num_cpua DOUBLE, wgt DOUBLE, wgt_cpue DOUBLE, wgt_cpua DOUBLE)'
  )
  for (table_name in names(schema_sql)) {
    cli::cli_progress_update(id = progress_id, status = paste("Loading", table_name), inc = 0)
    DBI::dbExecute(con, schema_sql[[table_name]])
    DBI::dbAppendTable(con, table_name, tables[[table_name]])
    cli::cli_progress_update(id = progress_id, inc = 1)
  }

  cli::cli_progress_update(id = progress_id, status = "Verifying row counts", inc = 0)
  row_counts <- vapply(names(tables), function(table_name) {
    DBI::dbGetQuery(
      con,
      paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table_name))
    )$n
  }, numeric(1))
  stopifnot(all(row_counts == vapply(tables, nrow, numeric(1))))
  cli::cli_progress_update(id = progress_id, inc = 1)

  DBI::dbDisconnect(con, shutdown = TRUE)
  con <- NULL
  if (!file.copy(temporary_database, database_path, overwrite = TRUE)) {
    cli::cli_abort("Could not create {.path {database_path}}.")
  }
  succeeded <- TRUE
}

#' Download and install FishGlob data
#'
#' Downloads the FishGlob .rds tables from Dropbox into a cache folder and
#' builds a local DuckDB database. Later sessions reuse that database.
#' Intended to be used before [get_data()].
#'
#' @param force If `TRUE`, download all tables again and rebuild the database.
#' @return Invisibly, the path to the cached DuckDB database.
#' @seealso [get_data()]
#' @export
#' @examples
#' \donttest{
#' install_fishglob_data()
#' # then see ?get_getdata
#' }
#'
install_fishglob_data <- function(force = FALSE) {
  rds_paths <- .download_fishglob_rds(force = force)
  database_path <- .fishglob_database_path()
  if (force || !file.exists(database_path)) {
    cli::cli_inform("Building the local FishGlob DuckDB database")
    .build_fishglob_database(rds_paths, database_path)
  }
  cli::cli_inform("FishGlob data are ready in {.path {database_path}}")
  invisible(database_path)
}
