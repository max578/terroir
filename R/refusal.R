# ---------------------------------------------------------------------------
# Structured refusals. A missing source package or unknown id yields a
# first-class refusal object (and a visible warning), never a silent failure
# and never an opaque error -- the constellation refusal pattern.
# ---------------------------------------------------------------------------

.refuse <- function(reason, source = NA_character_, warn = TRUE) {
  out <- structure(
    list(reason = reason, source = source),
    class = "terroir_refusal"
  )
  if (warn) cli::cli_warn("terroir refused: {reason}")
  out
}

#' Is an object a terroir refusal?
#'
#' @param x An object.
#' @return Logical scalar.
#' @export
is_refusal <- function(x) inherits(x, "terroir_refusal")

#' @export
print.terroir_refusal <- function(x, ...) {
  cli::cli_text("<terroir_refusal> source {.val {x$source}}")
  cli::cli_text("  {x$reason}")
  invisible(x)
}
