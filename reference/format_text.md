# Format R source code

`format_text()` formats one R source string and returns the result.
`format_file()` formats one UTF-8 file in place and reports invisibly
whether its contents changed. Both functions use the formatter embedded
in the `arity-formatter` Rust crate; they do not invoke the arity CLI or
discover an `arity.toml` file.

## Usage

``` r
format_text(
  text,
  line_width = 80L,
  indent_width = 2L,
  line_ending = c("auto", "lf", "crlf", "native"),
  roxygen_markdown = FALSE,
  verify = TRUE
)

format_file(
  path,
  line_width = 80L,
  indent_width = 2L,
  line_ending = c("auto", "lf", "crlf", "native"),
  roxygen_markdown = FALSE,
  verify = TRUE
)
```

## Arguments

- text:

  A non-missing character scalar containing valid UTF-8 R source code.
  Strings with a declared encoding are converted to UTF-8.

- line_width:

  Maximum output line width, from 1 through 1000.

- indent_width:

  Number of spaces per indentation level, from 1 through 1000.

- line_ending:

  Output line-ending policy. `"auto"` preserves the style of the first
  source line ending, `"lf"` and `"crlf"` force a style, and `"native"`
  uses the current platform's convention.

- roxygen_markdown:

  Whether roxygen blocks without an explicit `@md` or `@noMd` directive
  should be parsed in markdown mode.

- verify:

  Whether to verify syntax preservation, ordinary comment preservation,
  and idempotence after formatting.

- path:

  A non-missing character scalar naming a UTF-8 file. The contents are
  treated as R source regardless of the file extension.

## Value

`format_text()` returns a character scalar. `format_file()` invisibly
returns `TRUE` when the file changed and `FALSE` otherwise.

## Examples

``` r
format_text("x<-(1+2)*3^4\n")
#> [1] "x <- (1 + 2) * 3^4\n"
path <- tempfile(fileext = ".R")
writeLines("x<-1", path)
format_file(path)
readLines(path)
#> [1] "x <- 1"
unlink(path)
```
