local_config_project <- function(config = NULL, .local_envir = parent.frame()) {
  path <- withr::local_tempdir(.local_envir = .local_envir)
  dir.create(file.path(path, ".git"))
  if (!is.null(config)) {
    writeLines(config, file.path(path, "arity.toml"))
  }
  withr::local_envvar(
    c(ARITY_CONFIG = NA_character_),
    .local_envir = .local_envir
  )
  path
}

read_source <- function(path) {
  readChar(path, file.info(path)$size, useBytes = TRUE)
}
