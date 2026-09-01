# Arity

`arity` provides R bindings to the formatter behind
[arity](https://arity.cc). The package embeds the published
[`arity-formatter`](https://docs.rs/arity-formatter) Rust crate; it does
not invoke the `arity` command-line interface.

Format source held in memory:

``` r

library(arity)

format_text("x<-(1+2)*3^4\n")
```

``` R
## [1] "x <- (1 + 2) * 3^4\n"
```

Or format one file in place:

``` r

changed <- format_file("R/example.R")
```
