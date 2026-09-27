#' Format R code in RStudio
#'
#' Formats selected R code in the source editor, or the whole document when
#' nothing is selected. The addin discovers `arity.toml` from the document's
#' directory, or the working directory for untitled buffers, following the
#' configuration rules of [format_text()]. Syntax verification is enabled.
#'
#' Install arity to make **Format with arity** available in RStudio's Addins
#' menu. You can assign a keyboard shortcut through **Tools > Modify Keyboard
#' Shortcuts**.
#'
#' Whole-document formatting supports R scripts, `.Rprofile` files, and untitled
#' R buffers. In other documents, such as R Markdown or Quarto files, select
#' complete R expressions in the source editor. Each selection is formatted
#' independently, preserving its initial indentation. If any selection cannot be
#' formatted, the document is left unchanged.
#'
#' Changes are applied to the editor buffer without saving the file. When
#' formatting a whole document, the cursor is restored to its original row and
#' column, or the closest position if the document becomes shorter.
#'
#' @return
#' Invisibly returns `TRUE` when the buffer changed and `FALSE` otherwise.
#' @export
format_addin <- function() {
  if (!rstudioapi::isAvailable("0.99.1111")) {
    stop("This addin requires RStudio 0.99.1111 or later.", call. = FALSE)
  }

  context <- rstudioapi::getSourceEditorContext()
  if (is.null(context) || !nzchar(context$id) || context$id == "#console") {
    stop("Open a document in RStudio's source editor first.", call. = FALSE)
  }

  selections <- Filter(function(x) nzchar(x$text), context$selection)
  if (
    !length(selections) &&
      nzchar(context$path) &&
      !grepl("\\.[rR]$|(^|[/\\\\])\\.Rprofile$", context$path)
  ) {
    stop(
      "Whole-document formatting supports R scripts and .Rprofile files. ",
      "Select R code to format other document types.",
      call. = FALSE
    )
  }
  directory <- if (nzchar(context$path)) dirname(context$path) else getwd()
  style <- .resolve_format_config(TRUE, directory)
  if (length(selections)) {
    # Format every selection before editing, so an error cannot apply a partial edit.
    formatted <- vapply(
      selections,
      .format_selection,
      character(1),
      contents = context$contents,
      style = style
    )
    original <- vapply(selections, function(x) x$text, character(1))
    changed <- formatted != original
    if (any(changed)) {
      rstudioapi::modifyRange(
        lapply(selections[changed], function(x) x$range),
        formatted[changed],
        id = context$id
      )
    }
    return(invisible(any(changed)))
  }

  original <- paste(context$contents, collapse = "\n")
  formatted <- do.call(
    format_text,
    c(list(text = original, config = FALSE), style)
  )
  changed <- !identical(formatted, original)
  if (changed) {
    rstudioapi::modifyRange(
      rstudioapi::document_range(c(1, 1, Inf, 1)),
      formatted,
      id = context$id
    )
    if (length(context$selection)) {
      rstudioapi::setCursorPosition(
        context$selection[[1L]]$range$start,
        id = context$id
      )
    }
  }
  invisible(changed)
}

.format_selection <- function(selection, contents, style) {
  text <- selection$text
  formatted <- do.call(format_text, c(list(text = text, config = FALSE), style))
  start <- selection$range$start
  prefix <- substr(contents[[start[[1L]]]], 1L, start[[2L]] - 1L)
  if (grepl("[^ \t]", prefix)) {
    prefix <- ""
  }
  leading <- regmatches(text, regexpr("^[ \t]*", text))
  indent <- paste0(prefix, leading)
  if (!nzchar(indent) || !nzchar(formatted)) {
    return(formatted)
  }

  # Appending a newline keeps any trailing empty line when splitting the text.
  lines <- strsplit(paste0(formatted, "\n"), "\n", fixed = TRUE)[[1L]]
  indents <- rep(indent, length(lines))
  indents[[1L]] <- leading
  indents[!nzchar(lines) | lines == "\r"] <- ""

  # Indenting inside a multiline string or quoted name would change its value.
  previous <- options(keep.parse.data = TRUE)
  on.exit(options(previous), add = TRUE)
  # R's parser needs LF endings in character input; only token line spans matter here.
  parse_text <- gsub("\r\n", "\n", formatted, fixed = TRUE)
  tokens <- utils::getParseData(parse(text = parse_text, keep.source = TRUE))
  multiline <- tokens[tokens$terminal & tokens$line1 < tokens$line2, ]
  for (i in seq_len(nrow(multiline))) {
    indents[seq.int(multiline$line1[[i]] + 1L, multiline$line2[[i]])] <- ""
  }
  paste0(indents, lines, collapse = "\n")
}
