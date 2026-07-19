#!/usr/bin/env Rscript

# Static, dependency-free regression checks for the reference-flora build
# scripts. This deliberately parses rather than executes network-backed builds.
args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(args)) stop("Run this test with Rscript", call. = FALSE)
test_file <- normalizePath(sub("^--file=", "", args[[1L]]), winslash = "/", mustWork = TRUE)
scripts_dir <- dirname(test_file)
r_targets <- file.path(scripts_dir, c(
  "build_expected_lists.R",
  "build_completeness_index.R",
  "build_plant_authority.R"
))
targets <- r_targets
texts <- stats::setNames(
  lapply(targets, function(path) paste(readLines(path, warn = FALSE), collapse = "\n")),
  basename(targets)
)

invisible(lapply(r_targets, parse))

forbidden <- c(
  "setwd\\s*\\(",
  "[A-Za-z]:[/\\\\](Users|home)[/\\\\]",
  paste0("/", "Users/"),
  paste0("/", "home/[^/]+/"),
  "[A-Za-z]:[/\\\\](temp|tmp)[/\\\\]"
)
for (name in names(texts)) {
  hits <- vapply(forbidden, grepl, logical(1), x = texts[[name]], perl = TRUE,
                 ignore.case = TRUE)
  if (any(hits)) {
    stop(
      sprintf("%s contains non-portable path pattern(s): %s",
              name, paste(forbidden[hits], collapse = ", ")),
      call. = FALSE
    )
  }
}

required <- list(
  build_expected_lists.R = c(
    "PDE_REPO_ROOT",
    "commandArgs(trailingOnly = FALSE)",
    "file.path(REPO_ROOT, \"R\", \"site_metadata.R\")",
    "file.path(REPO_ROOT, \"data\", \"expected\")",
    "file.path(REPO_ROOT, \"data\", \"sites\")"
  ),
  build_completeness_index.R = c(
    "PDE_REPO_ROOT",
    "BUILD_SITE_DIR",
    "BUILD_EXPECTED_DIR",
    "BUILD_AUTHORITY_RDS",
    "PDE_COMPLETENESS_OUT",
    "BUILD_COMPLETENESS_OUT",
    "load_expected(s, BUILD_EXPECTED_DIR)",
    "load_plant_authority(BUILD_AUTHORITY_RDS)"
  ),
  build_plant_authority.R = c(
    "PDE_REPO_ROOT",
    "SITE_DIR",
    "EXPECTED_DIR",
    "AUTHORITY_DIR",
    "file.path(AUTHORITY_DIR, \"plants_lookup.rds\")"
  )
)
for (name in names(required)) {
  tokens <- required[[name]]
  missing <- tokens[!vapply(tokens, grepl, logical(1), x = texts[[name]], fixed = TRUE)]
  if (length(missing)) {
    stop(sprintf("%s is missing portability contract(s): %s",
                 name, paste(missing, collapse = ", ")), call. = FALSE)
  }
}

cat("Reference-flora build-script portability checks passed.\n")
