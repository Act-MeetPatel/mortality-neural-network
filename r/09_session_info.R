# 09_session_info.R
# Record the R and package versions used in this project.

pkgs <- c("DBI", "RSQLite", "ggplot2", "torch")

versions <- data.frame(
  package = c("R", pkgs),
  version = c(paste(R.version$major, R.version$minor, sep = "."),
              sapply(pkgs, function(p) as.character(packageVersion(p))))
)
row.names(versions) <- NULL
versions

writeLines(capture.output(sessionInfo()), "docs/session_info.txt")