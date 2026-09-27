# Format R code in RStudio

Formats selected R code in the source editor, or the whole document when
nothing is selected. The addin uses the defaults of
[`format_text()`](format_text.md), including syntax verification. It
does not discover an `arity.toml` file.

## Usage

``` r
format_addin()
```

## Value

Invisibly returns `TRUE` when the buffer changed and `FALSE` otherwise.

## Details

Install arity to make **Format with arity** available in RStudio's
Addins menu. You can assign a keyboard shortcut through **Tools \>
Modify Keyboard Shortcuts**.

Whole-document formatting supports R scripts, `.Rprofile` files, and
untitled R buffers. In other documents, such as R Markdown or Quarto
files, select complete R expressions in the source editor. Each
selection is formatted independently, preserving its initial
indentation. If any selection cannot be formatted, the document is left
unchanged.

Changes are applied to the editor buffer without saving the file. When
formatting a whole document, the cursor is restored to its original row
and column, or the closest position if the document becomes shorter.
