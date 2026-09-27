
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# Arity

<!-- badges: start -->

[![R-CMD-check](https://github.com/jolars/arity-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jolars/arity-r/actions/workflows/R-CMD-check.yaml)
[![CRAN
status](https://www.r-pkg.org/badges/version/arity)](https://CRAN.R-project.org/package=arity)
<!-- badges: end -->

`arity` provides R bindings to the formatter behind
[arity](https://arity.cc). The package embeds the published
[`arity-formatter`](https://docs.rs/arity-formatter) Rust crate; it does
not invoke the `arity` command-line interface.

## Installation

### CRAN version

``` r
install.packages("arity")
```

### Development Version

``` r
devtools::install_github("jolars/arity-r")
```

## Usage

Format source held in memory:

``` r
library(arity)

format_text("x<-(1+2)*3^4\n")
```

    ## [1] "x <- (1 + 2) * 3^4\n"

Or format one file in place:

``` r
changed <- format_file("R/example.R")
```

## RStudio addin

After installing the package, choose **Format with arity** from
RStudio’s **Addins** menu. The addin formats selected R code, or the
whole document when nothing is selected. To assign a keyboard shortcut,
open **Tools \> Modify Keyboard Shortcuts** and search for **Format with
arity**.

The addin works with unsaved edits and untitled R scripts. It preserves
the initial indentation of selected code and leaves changes in the
editor for you to save. Whole-document formatting supports R scripts and
`.Rprofile` files. For R Markdown or Quarto documents, select complete R
expressions in the source editor.

Formatting uses the defaults of `format_text()`; it does not read
`arity.toml`.
