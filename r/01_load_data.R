# 01_load_data.R
# Pull exposure and deaths from the life pricing database,
# grouped by attained age and smoker status.

library(DBI)
library(RSQLite)

# ---- Settings (change here if anything moves) ----
db_folder <- "~/Desktop/Projects/life-insurance-pricing-model"
db_file   <- "sql/pricing_model.db"

# ---- Connect ----
con <- dbConnect(SQLite(), file.path(db_folder, db_file))
dbListTables(con)

# ---- Grouped data: one row per age and smoker group ----
query <- "
SELECT e.attained_age,
       p.smoker_status,
       SUM(e.exposure_fraction) AS exposure,
       COUNT(d.death_id)        AS deaths
FROM Exposure e
JOIN Policy p ON e.policy_id = p.policy_id
LEFT JOIN Death d ON d.policy_id = e.policy_id
                 AND d.attained_age = e.attained_age
WHERE e.in_deferral = 0
GROUP BY e.attained_age, p.smoker_status
"
grouped <- dbGetQuery(con, query)
head(grouped)
colSums(grouped[, c("exposure", "deaths")])