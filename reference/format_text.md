# Format R source code

`format_text()` formats one R source string and returns the result.
`format_file()` formats one UTF-8 file in place and reports invisibly
whether its contents changed. Both functions use the formatter embedded
in the `arity-formatter` Rust crate.

## Usage

``` r
format_text(
  text,
  line_width = NULL,
  indent_width = NULL,
  line_ending = NULL,
  roxygen_markdown = FALSE,
  verify = TRUE,
  config = TRUE
)

format_file(
  path,
  line_width = NULL,
  indent_width = NULL,
  line_ending = NULL,
  roxygen_markdown = FALSE,
  verify = TRUE,
  config = TRUE
)
```

## Arguments

- text:

  A non-missing character scalar containing valid UTF-8 R source code.
  Strings with a declared encoding are converted to UTF-8.

- line_width:

  Maximum output line width, from 1 through 1000. `NULL` uses the
  configuration value, or 80 when unset.

- indent_width:

  Number of spaces per indentation level, from 1 through 1000. `NULL`
  uses the configuration value, or 2 when unset.

- line_ending:

  Output line-ending policy. `"auto"` preserves the style of the first
  source line ending, `"lf"` and `"crlf"` force a style, and `"native"`
  uses the current platform's convention. `NULL` uses the configuration
  value, or `"auto"` when unset.

- roxygen_markdown:

  Whether roxygen blocks without an explicit `@md` or `@noMd` directive
  should be parsed in markdown mode.

- verify:

  Whether to verify syntax preservation, ordinary comment preservation,
  and idempotence after formatting.

- config:

  `TRUE` discovers configuration automatically, `FALSE` ignores all
  configuration files, or a nonempty character scalar names an explicit
  configuration file. A missing or unreadable selected file is an error.

- path:

  A non-missing character scalar naming a UTF-8 file. The contents are
  treated as R source regardless of the file extension.

## Value

`format_text()` returns a character scalar. `format_file()` invisibly
returns `TRUE` when the file changed and `FALSE` otherwise.

## Details

By default, formatting uses the nearest `arity.toml`, searching upward
from the file's directory for `format_file()` or the working directory
for `format_text()`. The search includes the repository root, then stops
at a `.git` file or directory, or at the filesystem root. If no project
config is found, a nonempty `ARITY_CONFIG` environment variable supplies
a fallback config path. Relative explicit and fallback paths use the
working directory. Configuration files are not merged. Missing settings
use built-in defaults, and explicit formatting arguments override the
selected configuration.

The package reads `line-width`, `indent-width`, and `line-ending` from
the `[format]` table. Settings for other CLI operations, including
exclusions, have no effect. Invalid formatting configuration raises an
error before any source is changed.

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
