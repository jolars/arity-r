description <- read.dcf("DESCRIPTION")

if (!"SystemRequirements" %in% colnames(description)) {
  stop(
    paste(
      "`SystemRequirements` not found in `DESCRIPTION`.",
      "Specify Cargo and the minimum supported rustc version.",
      sep = "\n"
    )
  )
}

requirements <- description[, "SystemRequirements"]
if (!grepl("cargo", requirements, ignore.case = TRUE)) {
  stop("`SystemRequirements` must specify Cargo (Rust's package manager).")
}
if (!grepl("rustc", requirements, ignore.case = TRUE)) {
  stop("`SystemRequirements` must specify a minimum rustc version.")
}

parts <- strsplit(requirements, ", ")[[1]]
rustc_requirement <- parts[grepl("rustc", parts, fixed = TRUE)]

path <- paste(
  Sys.getenv("PATH"),
  file.path(Sys.getenv("HOME"), ".cargo", "bin"),
  sep = .Platform$path.sep
)
Sys.setenv(PATH = path)

rustc_version <- tryCatch(
  system("rustc --version", intern = TRUE),
  error = function(error) {
    stop(
      paste(
        "The `rustc` command was not found on PATH.",
        "Install Rust from https://www.rust-lang.org/tools/install.",
        sep = "\n"
      )
    )
  }
)
cargo_version <- tryCatch(
  system("cargo --version", intern = TRUE),
  error = function(error) {
    stop(
      paste(
        "The `cargo` command was not found on PATH.",
        "Install Rust from https://www.rust-lang.org/tools/install.",
        sep = "\n"
      )
    )
  }
)

extract_semver <- function(value) {
  if (grepl("\\d+\\.\\d+(\\.\\d+)?", value)) {
    sub(".*?(\\d+\\.\\d+(\\.\\d+)?).*", "\\1", value)
  } else {
    NA_character_
  }
}

msrv <- extract_semver(rustc_requirement)
current <- extract_semver(rustc_version)
if (!is.na(msrv) && utils::compareVersion(msrv, current) == 1) {
  stop(
    sprintf(
      "Minimum supported Rust version is %s, but %s is installed.",
      msrv,
      current
    )
  )
}

message(sprintf("Using %s\nUsing %s", cargo_version, rustc_version))
