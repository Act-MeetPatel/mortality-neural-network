# Step 1: Data Extraction

## What we did
Pulled exposure and death data from the life insurance pricing project's SQLite database, grouped it by attained age and smoker status, and saved it as a CSV.

## Why
Poisson loss needs two numbers per group: exposure (years lived) and deaths. Grouping shrinks 316,390 exposure rows to 168 rows with the same information for this loss, which makes training much faster. Saving a CSV means later steps never need the database.

## How
Script: `r/01_load_data.R`
1. Connect to `pricing_model.db` with DBI and RSQLite.
2. Join Exposure to Policy on `policy_id` to attach smoker status.
3. LEFT JOIN Death on `policy_id` and `attained_age`, so exposure rows with no death are kept and count as 0 deaths.
4. Drop deferral years (`in_deferral = 1`), since no claims are possible then.
5. GROUP BY attained age and smoker status. SUM exposure, COUNT deaths.
6. Save to `data/grouped_exposure_deaths.csv`.

## Logic and worked example
Observed rate = deaths / exposure.
- Age 20 nonsmoker: 1 death / 138 exposure years = 0.0072 (0.72%).
- Whole dataset: 6,512 deaths / 305,246 exposure years = 0.0213 (2.13%).

## Results
| Item | Value |
|---|---|
| Policies | 10,000 |
| Exposure rows (before filtering) | 316,390 |
| Deaths | 6,512 |
| Exposure after removing deferral years | 305,246 |
| Deferral exposure removed | 11,144 |
| Grouped rows (84 ages x 2 smoker groups) | 168 |

Checks: deaths after grouping (6,512) equal the full Death table, so no deaths were lost in the join. Totals after reading the CSV back matched the totals before saving.

## Bugs found and fixed
1. The R template `.gitignore` contained the rule `docs/`, so git silently ignored our documentation folder. Found with `git check-ignore -v`. Fixed by commenting out line 44.
2. Early exploration was done only in the Console, so nothing was saved. Fixed by moving all code into `r/01_load_data.R`.

## Limitations and assumptions
Facts:
- Deaths all fall outside deferral periods (total deaths unchanged after filtering).

Assumptions:
- ASSUMPTION: a death matches the exposure row with the same `policy_id` and `attained_age`. The matching totals support this but do not prove it for every row.
- ASSUMPTION: gender is ignored, because the source simulation did not vary mortality by gender.
- ASSUMPTION: full-year exposure (`exposure_fraction` = 1), inherited from the pricing project.
- ASSUMPTION: the data is synthetic and was generated from Gompertz-Makeham. Results describe how the models handle this data, not real mortality.

Limitations:
- Thin groups (for example age 20 smokers, 31 exposure years) give noisy rates.
- Grouping removes individual-level detail such as issue age and product type.