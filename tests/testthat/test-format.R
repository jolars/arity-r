test_that("format_text formats R source with the default style", {
  expect_identical(format_text("x<-(1+2)*3^4\n"), "x <- (1 + 2) * 3^4\n")
})

test_that("format_text honors width and indentation", {
  source <- "f <- function() { g(alpha, beta, gamma) }\n"
  formatted <- format_text(source, line_width = 20, indent_width = 4)

  expect_match(formatted, "\\n    g\\(", fixed = FALSE)
  expect_true(max(nchar(strsplit(formatted, "\n", fixed = TRUE)[[1]])) <= 20)
})

test_that("format_text honors line-ending policies", {
  source <- "x<-1\r\ny<-2\r\n"

  expect_identical(
    format_text(source, line_ending = "auto"),
    "x <- 1\r\ny <- 2\r\n"
  )
  expect_identical(format_text(source, line_ending = "lf"), "x <- 1\ny <- 2\n")
  expect_identical(
    format_text("x<-1\ny<-2\n", line_ending = "crlf"),
    "x <- 1\r\ny <- 2\r\n"
  )

  native <- if (.Platform$OS.type == "windows") "\r\n" else "\n"
  expected <- paste0("x <- 1", native, "y <- 2", native)
  expect_identical(format_text(source, line_ending = "native"), expected)
})

test_that("roxygen markdown mode is explicit", {
  source <- paste0(
    "#' Title\n",
    "#'\n",
    "#' @details\n",
    "#' Before.\n",
    "#'\n",
    "#'     code_looking <- \"indented\"\n",
    "#' @name x\n",
    "NULL\n"
  )

  rd_first <- format_text(source, roxygen_markdown = FALSE)
  markdown <- format_text(source, roxygen_markdown = TRUE)

  expect_match(rd_first, "#' code_looking")
  expect_match(markdown, "#'     code_looking", fixed = TRUE)
})

test_that("verification is optional and enabled by default", {
  source <- "if (x) y else z\n"

  expect_identical(format_text(source), format_text(source, verify = FALSE))
  expect_error(format_text("x <- (\n"), "parser diagnostic")
  expect_error(format_text("x <- (\n", verify = FALSE), "parser diagnostic")
})

test_that("format_text validates its public arguments", {
  expect_error(format_text(c("x", "y")), "`text`")
  expect_error(format_text(NA_character_), "`text`")
  expect_error(format_text("x", line_width = 0), "`line_width`")
  expect_error(format_text("x", indent_width = 1001), "`indent_width`")
  expect_error(format_text("x", line_width = 1.5), "`line_width`")
  expect_error(format_text("x", line_ending = "windows"), "arg")
  expect_error(format_text("x", roxygen_markdown = NA), "`roxygen_markdown`")
  expect_error(format_text("x", verify = 1), "`verify`")
})

test_that("format_file writes only changed files", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeChar("x<-1\n", path, eos = NULL, useBytes = TRUE)

  first <- withVisible(format_file(path))
  expect_false(first$visible)
  expect_true(first$value)
  expect_identical(
    readChar(path, file.info(path)$size, useBytes = TRUE),
    "x <- 1\n"
  )

  stamp <- file.info(path)$mtime
  Sys.sleep(0.01)
  second <- withVisible(format_file(path))
  expect_false(second$visible)
  expect_false(second$value)
  expect_identical(file.info(path)$mtime, stamp)
})

test_that("format_file treats every path as R source", {
  path <- tempfile(fileext = ".txt")
  on.exit(unlink(path))
  writeChar("x<-1\n", path, eos = NULL, useBytes = TRUE)

  expect_true(format_file(path))
  expect_identical(
    readChar(path, file.info(path)$size, useBytes = TRUE),
    "x <- 1\n"
  )
})

test_that("format_file leaves invalid input unchanged", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  source <- "x <- (\n"
  writeChar(source, path, eos = NULL, useBytes = TRUE)

  expect_error(format_file(path), "parser diagnostic")
  expect_identical(
    readChar(path, file.info(path)$size, useBytes = TRUE),
    source
  )
})

test_that("format_file reports file errors", {
  missing <- tempfile(fileext = ".R")
  expect_error(format_file(missing), "failed to read")

  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeBin(as.raw(c(0xff, 0xfe)), path)
  expect_error(format_file(path), "UTF-8")
  expect_identical(readBin(path, "raw", n = 2), as.raw(c(0xff, 0xfe)))
})
