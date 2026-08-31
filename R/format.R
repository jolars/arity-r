#' Format R source code
#'
#' `format_text()` formats one R source string and returns the result.
#' `format_file()` formats one UTF-8 file in place and reports invisibly whether
#' its contents changed. Both functions use the formatter embedded in the
#' `arity-formatter` Rust crate; they do not invoke the arity CLI or discover an
#' `arity.toml` file.
#'
#' @param text A non-missing character scalar containing valid UTF-8 R source
#'   code. Strings with a declared encoding are converted to UTF-8.
#' @param path A non-missing character scalar naming a UTF-8 file. The contents
#'   are treated as R source regardless of the file extension.
#' @param line_width Maximum output line width, from 1 through 1000.
#' @param indent_width Number of spaces per indentation level, from 1 through
#'   1000.
#' @param line_ending Output line-ending policy. `"auto"` preserves the style of
#'   the first source line ending, `"lf"` and `"crlf"` force a style, and
#'   `"native"` uses the current platform's convention.
#' @param roxygen_markdown Whether roxygen blocks without an explicit `@@md` or
#'   `@@noMd` directive should be parsed in markdown mode.
#' @param verify Whether to verify syntax preservation, ordinary comment
#'   preservation, and idempotence after formatting.
#'
#' @return
#' `format_text()` returns a character scalar. `format_file()` invisibly returns
#' `TRUE` when the file changed and `FALSE` otherwise.
#' @export
#'
#' @examples
#' format_text("x<-(1+2)*3^4\n")
format_text <- function(
  text,
  line_width = 80L,
  indent_width = 2L,
  line_ending = c("auto", "lf", "crlf", "native"),
  roxygen_markdown = FALSE,
  verify = TRUE
) {
  text <- .as_utf8_string(text, "text")
  options <- .format_options(
    line_width,
    indent_width,
    line_ending,
    roxygen_markdown,
    verify
  )

  .unwrap_extendr_result(
    format_text_native(
      text,
      options$line_width,
      options$indent_width,
      options$line_ending,
      options$roxygen_markdown,
      options$verify
    )
  )
}

#' @rdname format_text
#' @export
#'
#' @examples
#' path <- tempfile(fileext = ".R")
#' writeLines("x<-1", path)
#' format_file(path)
#' readLines(path)
#' unlink(path)
format_file <- function(
  path,
  line_width = 80L,
  indent_width = 2L,
  line_ending = c("auto", "lf", "crlf", "native"),
  roxygen_markdown = FALSE,
  verify = TRUE
) {
  .assert_string(path, "path")
  options <- .format_options(
    line_width,
    indent_width,
    line_ending,
    roxygen_markdown,
    verify
  )

  changed <- .unwrap_extendr_result(
    format_file_native(
      path,
      options$line_width,
      options$indent_width,
      options$line_ending,
      options$roxygen_markdown,
      options$verify
    )
  )
  invisible(changed)
}

.format_options <- function(
  line_width,
  indent_width,
  line_ending,
  roxygen_markdown,
  verify
) {
  list(
    line_width = .assert_width(line_width, "line_width"),
    indent_width = .assert_width(indent_width, "indent_width"),
    line_ending = match.arg(line_ending, c("auto", "lf", "crlf", "native")),
    roxygen_markdown = .assert_flag(roxygen_markdown, "roxygen_markdown"),
    verify = .assert_flag(verify, "verify")
  )
}

.assert_string <- function(value, argument) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop(
      "`",
      argument,
      "` must be a non-missing character scalar.",
      call. = FALSE
    )
  }
  invisible(value)
}

.as_utf8_string <- function(value, argument) {
  .assert_string(value, argument)
  if (identical(Encoding(value), "bytes")) {
    stop("`", argument, "` must contain valid UTF-8.", call. = FALSE)
  }

  value <- enc2utf8(value)
  if (!validUTF8(value)) {
    stop("`", argument, "` must contain valid UTF-8.", call. = FALSE)
  }
  value
}

.unwrap_extendr_result <- function(value) {
  if (inherits(value, "extendr_error")) {
    stop(as.character(value$value)[[1L]], call. = FALSE)
  }
  value
}

.assert_width <- function(value, argument) {
  valid <- is.numeric(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    is.finite(value) &&
    value == trunc(value) &&
    value >= 1 &&
    value <= 1000
  if (!valid) {
    stop(
      "`",
      argument,
      "` must be a whole number from 1 through 1000.",
      call. = FALSE
    )
  }
  as.integer(value)
}

.assert_flag <- function(value, argument) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`", argument, "` must be `TRUE` or `FALSE`.", call. = FALSE)
  }
  value
}
