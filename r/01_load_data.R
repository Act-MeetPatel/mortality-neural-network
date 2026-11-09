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

# ---- Split policies into train / validation / test ----
train_share <- 0.70
valid_share <- 0.15   # test gets whatever is left

policies <- dbGetQuery(con, "SELECT policy_id FROM Policy")

set.seed(3130)
shuffled_ids <- sample(policies$policy_id)
n       <- length(shuffled_ids)
n_train <- round(train_share * n)
n_valid <- round(valid_share * n)

split_table <- data.frame(
  policy_id = shuffled_ids,
  split = c(rep("train", n_train),
            rep("valid", n_valid),
            rep("test",  n - n_train - n_valid))
)
table(split_table$split)

# ---- Put the split labels in a temporary table ----
dbWriteTable(con, "split_table", split_table, temporary = TRUE)

# ---- Grouped data: one row per split, age and smoker group ----
query <- "
SELECT s.split,
       e.attained_age,
       p.smoker_status,
       SUM(e.exposure_fraction) AS exposure,
       COUNT(d.death_id)        AS deaths
FROM Exposure e
JOIN Policy p      ON e.policy_id = p.policy_id
JOIN split_table s ON e.policy_id = s.policy_id
LEFT JOIN Death d  ON d.policy_id = e.policy_id
                  AND d.attained_age = e.attained_age
WHERE e.in_deferral = 0
GROUP BY s.split, e.attained_age, p.smoker_status
"
grouped <- dbGetQuery(con, query)

# ---- Checks ----
aggregate(cbind(exposure, deaths) ~ split, data = grouped, FUN = sum)
colSums(grouped[, c("exposure", "deaths")])

# ---- Save grouped data for later steps ----
dir.create("data", showWarnings = FALSE)
write.csv(grouped, "data/grouped_exposure_deaths.csv", row.names = FALSE)

# ---- Close the connection ----
dbDisconnect(con)
