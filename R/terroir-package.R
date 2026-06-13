#' @keywords internal
"_PACKAGE"

# Avoid R CMD check NOTE for data.table's use of `.` / non-standard eval and to
# document that the package depends on data.table semantics throughout.
.datatable.aware <- TRUE

`%||%` <- function(x, y) if (is.null(x)) y else x

# data.table non-standard evaluation: declare the bare column symbols used in
# `[` expressions so R CMD check does not flag "no visible binding".
utils::globalVariables(c(
  "YYYYMMDD", "date", "variable", "value", "lon", "lat", "unit",
  "source", "source_version", "retrieved_at", "license", "calendar_date",
  "verified_on", "grounding", "fact_family", "evidence_path", "asserted_value",
  ".", ".N", ":="
))
