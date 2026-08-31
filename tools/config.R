source("tools/msrv.R")

is_debug <- nzchar(Sys.getenv("DEBUG"))
is_not_cran <- nzchar(Sys.getenv("NOT_CRAN")) || is_debug
vendor_exists <- file.exists("src/rust/vendor.tar.xz")

if (is_debug) {
  message("Creating DEBUG build.")
} else if (!is_not_cran) {
  message("Building for CRAN.")
}

.cran_flags <- if (!is_not_cran && vendor_exists) {
  "-j 2 --offline --frozen"
} else {
  ""
}
.profile <- if (is_debug) "" else "--release"
.clean_target <- if (is_debug) "" else "$(TARGET_DIR)"

webr_target <- "wasm32-unknown-emscripten"
is_wasm <- identical(R.version$platform, webr_target)
if (is_wasm) {
  message("Building for WebR.")
}

target_libpath <- if (is_wasm) webr_target else NULL
configuration <- if (is_debug) "debug" else "release"
.libdir <- paste(c(target_libpath, configuration), collapse = "/")
.target <- if (is_wasm) paste0("--target=", webr_target) else ""
.panic_exports <- if (is_wasm) {
  paste0(
    "CARGO_PROFILE_DEV_PANIC=\"abort\" ",
    "CARGO_PROFILE_RELEASE_PANIC=\"abort\" "
  )
} else {
  ""
}

is_windows <- .Platform[["OS.type"]] == "windows"
input <- if (is_windows) "src/Makevars.win.in" else "src/Makevars.in"
output <- if (is_windows) "src/Makevars.win" else "src/Makevars"

if (file.exists(output)) {
  message("Cleaning previous `", output, "`.")
  invisible(file.remove(output))
}

makevars <- readLines(input)
makevars <- gsub("@CRAN_FLAGS@", .cran_flags, makevars, fixed = TRUE) |>
  gsub("@PROFILE@", .profile, x = _, fixed = TRUE) |>
  gsub("@CLEAN_TARGET@", .clean_target, x = _, fixed = TRUE) |>
  gsub("@LIBDIR@", .libdir, x = _, fixed = TRUE) |>
  gsub("@TARGET@", .target, x = _, fixed = TRUE) |>
  gsub("@PANIC_EXPORTS@", .panic_exports, x = _, fixed = TRUE)

message("Writing `", output, "`.")
connection <- file(output, open = "wb")
writeLines(makevars, connection, sep = "\n")
close(connection)
