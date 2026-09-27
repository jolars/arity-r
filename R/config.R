.resolve_format_config <- function(config, directory) {
  if (
    !identical(config, TRUE) &&
      !identical(config, FALSE) &&
      !(is.character(config) &&
        length(config) == 1L &&
        !is.na(config) &&
        nzchar(config))
  ) {
    stop(
      "`config` must be `TRUE`, `FALSE`, or a nonempty file path.",
      call. = FALSE
    )
  }

  explicit <- if (is.character(config)) path.expand(config) else NULL
  fallback <- Sys.getenv("ARITY_CONFIG", unset = "")
  fallback <- if (nzchar(fallback)) path.expand(fallback) else NULL
  .unwrap_extendr_result(format_config_native(
    path.expand(directory),
    explicit,
    identical(config, FALSE),
    fallback
  ))
}
