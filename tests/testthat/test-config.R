test_that(
  "text formatting discovers the nearest config from the working directory",
  {
    project <- local_config_project(c("[format]", "indent-width = 4"))
    nested <- file.path(project, "R", "nested")
    dir.create(nested, recursive = TRUE)
    withr::local_dir(nested)
    source <- "if (TRUE) {\nx<-1\n}\n"

    expect_identical(format_text(source), "if (TRUE) {\n    x <- 1\n}\n")

    writeLines(c("[format]", "indent-width = 3"), "arity.toml")
    expect_identical(format_text(source), "if (TRUE) {\n   x <- 1\n}\n")
  }
)

test_that("file formatting discovers config from the file rather than the working directory", {
  project <- local_config_project(c("[format]", "indent-width = 4"))
  other <- local_config_project(c("[format]", "indent-width = 3"))
  withr::local_dir(other)
  dir.create(file.path(project, "R"))
  path <- file.path(project, "R", "example.R")
  writeLines(c("if (TRUE) {", "x<-1", "}"), path)

  expect_true(format_file(path))
  expect_identical(read_source(path), "if (TRUE) {\n    x <- 1\n}\n")
  expect_false(format_file(path))
})

test_that("discovery stops at git directories and worktree git files", {
  project <- local_config_project(c("[format]", "indent-width = 4"))
  source <- "if (TRUE) {\nx<-1\n}\n"

  for (git_file in c(FALSE, TRUE)) {
    nested <- file.path(project, if (git_file) "worktree" else "repository")
    dir.create(nested)
    if (git_file) {
      writeLines("gitdir: elsewhere", file.path(nested, ".git"))
    } else {
      dir.create(file.path(nested, ".git"))
    }
    withr::with_dir(nested, {
      expect_identical(format_text(source), "if (TRUE) {\n  x <- 1\n}\n")
      writeLines(c("[format]", "indent-width = 3"), "arity.toml")
      expect_identical(format_text(source), "if (TRUE) {\n   x <- 1\n}\n")
    })
  }
})

test_that(
  "explicit formatting arguments override config including default values",
  {
    project <- local_config_project(c(
      "[format]",
      "line-width = 20",
      "indent-width = 4",
      'line-ending = "crlf"'
    ))
    withr::local_dir(project)
    source <- "f <- function() { g(alpha, beta, gamma) }\n"

    expect_identical(
      format_text(source),
      format_text(
        source,
        line_width = 20,
        indent_width = 4,
        line_ending = "crlf",
        config = FALSE
      )
    )
    expect_identical(
      format_text(
        source,
        line_width = 80L,
        indent_width = 2L,
        line_ending = "auto"
      ),
      format_text(source, config = FALSE)
    )
    expect_identical(
      format_text(source, indent_width = 2L),
      format_text(source, line_width = 20, line_ending = "crlf", config = FALSE)
    )

    path <- file.path(project, "example.R")
    writeLines(source, path, sep = "")
    format_file(path, line_width = 80L, indent_width = 2L, line_ending = "auto")
    expect_identical(read_source(path), format_text(source, config = FALSE))
  }
)

test_that("an explicit config replaces discovery and environment fallback", {
  project <- local_config_project("invalid TOML")
  withr::local_dir(project)
  withr::local_envvar(c(ARITY_CONFIG = "missing.toml"))
  writeLines(c("[format]", "indent-width = 3"), "custom.toml")
  source <- "if (TRUE) {\nx<-1\n}\n"

  expect_identical(
    format_text(source, config = "custom.toml"),
    "if (TRUE) {\n   x <- 1\n}\n"
  )
  writeLines(source, "example.R", sep = "")
  expect_true(format_file("example.R", config = "custom.toml"))
  expect_identical(read_source("example.R"), "if (TRUE) {\n   x <- 1\n}\n")
})

test_that(
  "disabling configuration ignores files but retains explicit arguments",
  {
    project <- local_config_project("invalid TOML")
    withr::local_dir(project)
    withr::local_envvar(c(ARITY_CONFIG = "missing.toml"))
    source <- "if (TRUE) {\nx<-1\n}\n"

    expect_identical(
      format_text(source, config = FALSE),
      "if (TRUE) {\n  x <- 1\n}\n"
    )
    expect_identical(
      format_text(source, config = FALSE, indent_width = 3),
      "if (TRUE) {\n   x <- 1\n}\n"
    )
    writeLines(source, "example.R", sep = "")
    expect_true(format_file("example.R", config = FALSE))
    expect_identical(read_source("example.R"), "if (TRUE) {\n  x <- 1\n}\n")
  }
)

test_that("ARITY_CONFIG is a fallback and configurations are not merged", {
  project <- local_config_project()
  withr::local_dir(project)
  writeLines(
    c("[format]", "indent-width = 4", 'line-ending = "crlf"'),
    "user.toml"
  )
  withr::local_envvar(c(ARITY_CONFIG = "user.toml"))
  source <- "if (TRUE) {\nx<-1\n}\n"

  expect_identical(format_text(source), "if (TRUE) {\r\n    x <- 1\r\n}\r\n")
  writeLines(c("[format]", "indent-width = 3"), "arity.toml")
  expect_identical(format_text(source), "if (TRUE) {\n   x <- 1\n}\n")

  dir.create("nested")
  writeLines("[format]", file.path("nested", "arity.toml"))
  withr::with_dir("nested", {
    expect_identical(format_text(source), "if (TRUE) {\n  x <- 1\n}\n")
  })
})

test_that("absent, empty, and unrelated configuration use default formatting", {
  project <- local_config_project()
  withr::local_dir(project)
  withr::local_envvar(c(ARITY_CONFIG = ""))

  expect_identical(format_text("x<-1"), "x <- 1")
  for (config in list(
    character(),
    c(
      'exclude = ["*.R"]',
      'extend-exclude = ["generated/"]',
      "cache = false",
      "[format]",
      "description = false",
      "[lint]",
      'ignore = ["unused-binding"]',
      "[compat]",
      'r = "4.2"',
      "[index]",
      "auto-build = false"
    )
  )) {
    writeLines(config, "arity.toml")
    expect_identical(format_text("x<-1"), "x <- 1")
    writeLines("x<-1", "example.R")
    expect_true(format_file("example.R"))
  }
})

test_that("invalid config reports its path and leaves source unchanged", {
  project <- local_config_project()
  withr::local_dir(project)
  writeLines("x<-1", "example.R")

  for (config in list(
    "[format",
    c("[format]", "line-widht = 100"),
    c("[format]", "line-width = 0"),
    c("[format]", "indent-width = 1001"),
    c("[format]", "line-width = 1.5"),
    c("[format]", 'line-ending = "windows"'),
    c("[formatt]", "indent-width = 4")
  )) {
    writeLines(config, "arity.toml")
    expect_error(format_text("x<-1"), "arity[.]toml")
    expect_error(format_file("example.R"), "arity[.]toml")
    expect_identical(read_source("example.R"), "x<-1\n")
  }
})

test_that("missing explicit and fallback configs are errors", {
  project <- local_config_project()
  withr::local_dir(project)

  expect_error(format_text("x<-1", config = "missing.toml"), "missing[.]toml")
  expect_error(format_text("x<-1", config = project), "config")
  withr::local_envvar(c(ARITY_CONFIG = "missing.toml"))
  expect_error(format_text("x<-1"), "missing[.]toml")
})

test_that("config accepts only a flag or nonempty path", {
  for (config in list(
    NA,
    NULL,
    1,
    "",
    NA_character_,
    c(TRUE, FALSE),
    c("a", "b")
  )) {
    expect_error(format_text("x<-1", config = config), "`config`")
    expect_error(format_file("example.R", config = config), "`config`")
  }
})

test_that("unreadable and non-UTF-8 configurations are errors", {
  project <- local_config_project()
  withr::local_dir(project)
  writeLines("x<-1", "example.R")
  path <- file.path(project, "arity.toml")
  writeBin(as.raw(c(0xff, 0xfe)), path)
  expect_error(format_file("example.R"), "arity[.]toml")
  expect_identical(read_source("example.R"), "x<-1\n")

  writeLines("[format]", path)
  Sys.chmod(path, "0000")
  withr::defer(Sys.chmod(path, "0600"))
  skip_if(file.access(path, 4L) == 0L, "Cannot make the config unreadable.")
  expect_error(format_file("example.R"), "arity[.]toml")
  expect_identical(read_source("example.R"), "x<-1\n")
})
