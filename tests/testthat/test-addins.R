withr::local_dir(local_config_project())

local_editor <- function(
  contents = c("x<-1", ""),
  selection = list(list(
    range = rstudioapi::document_range(c(1, 1, 1, 1)),
    text = ""
  )),
  path = "",
  available = TRUE,
  context = list(
    id = "source-document",
    path = path,
    contents = contents,
    selection = selection
  ),
  .env = parent.frame()
) {
  editor <- new.env(parent = emptyenv())
  editor$edits <- list()
  editor$cursors <- list()
  local_mocked_bindings(
    isAvailable = function(...) available,
    getSourceEditorContext = function() context,
    modifyRange = function(location, text, id) {
      editor$edits[[length(editor$edits) + 1L]] <- list(
        location = location,
        text = text,
        id = id
      )
    },
    setCursorPosition = function(position, id) {
      editor$cursors[[length(editor$cursors) + 1L]] <- list(
        position = position,
        id = id
      )
    },
    documentSave = function(...) stop("The addin must not save documents."),
    .package = "rstudioapi",
    .env = .env
  )
  editor
}

editor_selection <- function(text, range) {
  list(text = text, range = rstudioapi::document_range(range))
}

test_that("the addin formats the source buffer and restores its cursor", {
  cursor <- editor_selection("", c(2, 2, 2, 2))
  editor <- local_editor(
    contents = c("x<-1", "y<-2", ""),
    selection = list(cursor)
  )

  result <- withVisible(format_addin())

  expect_false(result$visible)
  expect_true(result$value)
  expect_length(editor$edits, 1L)
  expect_identical(editor$edits[[1L]]$text, "x <- 1\ny <- 2\n")
  expect_identical(editor$edits[[1L]]$id, "source-document")
  expect_equal(
    editor$edits[[1L]]$location,
    rstudioapi::document_range(c(1, 1, Inf, 1))
  )
  expect_identical(
    editor$cursors,
    list(list(position = cursor$range$start, id = "source-document"))
  )
})

test_that("the addin uses unsaved edits without changing the saved file", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeLines("x<-0", path)
  editor <- local_editor(contents = "x<-1", path = path)

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "x <- 1")
  expect_identical(readLines(path), "x<-0")
})

test_that("the addin formats only the selected code", {
  selection <- editor_selection("x<-1", c(2, 1, 2, 5))
  editor <- local_editor(
    contents = c("# Heading", "x<-1", "Untouched prose."),
    selection = list(selection),
    path = "report.qmd"
  )

  expect_true(format_addin())
  expect_identical(
    editor$edits,
    list(list(
      location = list(selection$range),
      text = "x <- 1",
      id = "source-document"
    ))
  )
  expect_length(editor$cursors, 0L)
})

test_that("selected code keeps its indentation and final newline", {
  text <- "  x<-1\n  y<-2\n"
  editor <- local_editor(
    contents = c("f <- function() {", "  x<-1", "  y<-2", "}"),
    selection = list(editor_selection(text, c(2, 1, 4, 1)))
  )

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "  x <- 1\n  y <- 2\n")
})

test_that("selection indentation accounts for whitespace before the range", {
  editor <- local_editor(
    contents = c("f <- function() {", "  x<-1", "  y<-2", "}"),
    selection = list(editor_selection("x<-1\n  y<-2", c(2, 3, 3, 7)))
  )

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "x <- 1\n  y <- 2")
})

test_that("indenting selections preserves multiline literal values", {
  text <- "  x<-\"first\nsecond\"\n  y<-2\n"
  editor <- local_editor(
    contents = c("  x<-\"first", "second\"", "  y<-2", ""),
    selection = list(editor_selection(text, c(1, 1, 4, 1)))
  )

  expect_true(format_addin())
  formatted <- editor$edits[[1L]]$text
  expect_identical(formatted, "  x <- \"first\nsecond\"\n  y <- 2\n")
  expect_identical(
    parse(text = formatted, keep.source = FALSE),
    parse(text = text, keep.source = FALSE)
  )
})

test_that("selection formatting works when parse data is disabled", {
  previous <- options(keep.parse.data = FALSE)
  on.exit(options(previous), add = TRUE)
  editor <- local_editor(
    contents = c("  x<-\"first", "second\""),
    selection = list(editor_selection("  x<-\"first\nsecond\"", c(1, 1, 2, 8)))
  )

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "  x <- \"first\nsecond\"")
  expect_false(getOption("keep.parse.data"))
})

test_that("whitespace-only selections do not format the whole document", {
  selection <- editor_selection("  \n", c(1, 1, 2, 1))
  editor <- local_editor(
    contents = c("  ", "x<-1"),
    selection = list(selection)
  )

  expect_true(format_addin())
  expect_identical(
    editor$edits,
    list(list(
      location = list(selection$range),
      text = "\n",
      id = "source-document"
    ))
  )
})

test_that("inline selections leave surrounding code outside the edit", {
  selection <- editor_selection("x+1", c(1, 10, 1, 13))
  editor <- local_editor(
    contents = "f <- g(h(x+1))",
    selection = list(selection)
  )

  expect_true(format_addin())
  expect_identical(
    editor$edits,
    list(list(
      location = list(selection$range),
      text = "x + 1",
      id = "source-document"
    ))
  )
})

test_that("multiple selections are formatted in one editor operation", {
  first <- editor_selection("x<-1", c(1, 1, 1, 5))
  cursor <- editor_selection("", c(2, 1, 2, 1))
  last <- editor_selection("z<-3", c(3, 1, 3, 5))
  editor <- local_editor(
    contents = c("x<-1", "y<-2", "z<-3"),
    selection = list(first, cursor, last)
  )

  expect_true(format_addin())
  expect_identical(
    editor$edits,
    list(list(
      location = list(first$range, last$range),
      text = c("x <- 1", "z <- 3"),
      id = "source-document"
    ))
  )
})

test_that("a formatting error leaves all selections unchanged", {
  editor <- local_editor(
    contents = c("x<-1", "y<-("),
    selection = list(
      editor_selection("x<-1", c(1, 1, 1, 5)),
      editor_selection("y<-(", c(2, 1, 2, 5))
    )
  )

  expect_error(format_addin(), "parser diagnostic")
  expect_length(editor$edits, 0L)
})

test_that("invalid document syntax leaves the buffer unchanged", {
  editor <- local_editor(contents = "x<-(")

  expect_error(format_addin(), "parser diagnostic")
  expect_length(editor$edits, 0L)
  expect_length(editor$cursors, 0L)
})

test_that("unchanged and empty buffers do not create editor operations", {
  for (contents in list("", character(), c("x <- 1", ""))) {
    editor <- local_editor(contents = contents)

    expect_false(format_addin())
    expect_length(editor$edits, 0L)
    expect_length(editor$cursors, 0L)
  }
})

test_that("unchanged selections do not create editor operations", {
  editor <- local_editor(
    contents = "  x <- 1",
    selection = list(editor_selection("  x <- 1", c(1, 1, 1, 9)))
  )

  expect_false(format_addin())
  expect_length(editor$edits, 0L)
})

test_that("whole-document formatting supports R scripts and profiles", {
  for (path in c("script.R", "script.r", ".Rprofile", "project/.Rprofile")) {
    editor <- local_editor(path = path)
    expect_true(format_addin())
    expect_length(editor$edits, 1L)
  }
})

test_that("other document types require a selection of R code", {
  for (path in c("report.Rmd", "report.qmd", "report.Rnw", "script.py")) {
    editor <- local_editor(path = path)

    expect_error(format_addin(), "Select R code")
    expect_length(editor$edits, 0L)
  }
})

test_that("the addin reports unavailable RStudio and missing source editors", {
  editor <- local_editor(available = FALSE)
  expect_error(format_addin(), "RStudio")
  expect_length(editor$edits, 0L)

  for (context in list(NULL, list(id = ""), list(id = "#console"))) {
    editor <- local_editor(context = context)
    expect_error(format_addin(), "Open a document")
    expect_length(editor$edits, 0L)
  }
})

test_that(
  "the addin discovers config beside a named buffer even before it exists",
  {
    project <- local_config_project(c("[format]", "indent-width = 4"))
    other <- local_config_project(c("[format]", "indent-width = 3"))
    withr::local_dir(other)
    editor <- local_editor(
      contents = c("if (TRUE) {", "x<-1", "}"),
      path = file.path(project, "new", "example.R")
    )

    expect_true(format_addin())
    expect_identical(editor$edits[[1L]]$text, "if (TRUE) {\n    x <- 1\n}")
  }
)

test_that(
  "the addin discovers config from the working directory for untitled buffers",
  {
    project <- local_config_project(c("[format]", "indent-width = 3"))
    withr::local_dir(project)
    editor <- local_editor(contents = c("if (TRUE) {", "x<-1", "}"))

    expect_true(format_addin())
    expect_identical(editor$edits[[1L]]$text, "if (TRUE) {\n   x <- 1\n}")
  }
)

test_that("relative buffer paths can name directories that do not exist yet", {
  project <- local_config_project(c("[format]", "indent-width = 3"))
  withr::local_dir(project)
  editor <- local_editor(
    contents = c("if (TRUE) {", "x<-1", "}"),
    path = file.path("new", "example.R")
  )

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "if (TRUE) {\n   x <- 1\n}")
})

test_that(
  "selected code uses the document's config and preserves indentation",
  {
    project <- local_config_project(c("[format]", "indent-width = 4"))
    other <- local_config_project()
    withr::local_dir(other)
    source <- "  if (TRUE) {\n  x<-1\n  }"
    editor <- local_editor(
      contents = strsplit(source, "\n", fixed = TRUE)[[1L]],
      selection = list(editor_selection(source, c(1, 1, 3, 4))),
      path = file.path(project, "report.qmd")
    )

    expect_true(format_addin())
    expect_identical(
      editor$edits[[1L]]$text,
      "  if (TRUE) {\n      x <- 1\n  }"
    )
  }
)

test_that("configuration errors leave the editor unchanged", {
  project <- local_config_project(c("[format]", "indent-width = 0"))
  withr::local_dir(project)

  for (selection in list(
    list(editor_selection("", c(1, 1, 1, 1))),
    list(editor_selection("x<-1", c(1, 1, 1, 5)))
  )) {
    editor <- local_editor(contents = "x<-1", selection = selection)
    expect_error(format_addin(), "arity[.]toml")
    expect_length(editor$edits, 0L)
    expect_length(editor$cursors, 0L)
  }
})

test_that("selected code honors configured CRLF endings without changing literal contents", {
  project <- local_config_project(c("[format]", 'line-ending = "crlf"'))
  withr::local_dir(project)
  text <- "  x<-\"first\r\nsecond\"\r\n  y<-2\r\n"
  editor <- local_editor(
    contents = c("  x<-\"first", "second\"", "  y<-2", ""),
    selection = list(editor_selection(text, c(1, 1, 4, 1)))
  )

  expect_true(format_addin())
  expect_identical(
    editor$edits[[1L]]$text,
    "  x <- \"first\r\nsecond\"\r\n  y <- 2\r\n"
  )
})

test_that("CRLF configuration does not indent empty selection lines", {
  project <- local_config_project(c("[format]", 'line-ending = "crlf"'))
  withr::local_dir(project)
  editor <- local_editor(
    contents = c("  ", "x<-1"),
    selection = list(editor_selection("  \n", c(1, 1, 2, 1)))
  )

  expect_true(format_addin())
  expect_identical(editor$edits[[1L]]$text, "\r\n")
})
