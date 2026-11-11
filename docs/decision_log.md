# Decision Log

| Decision | Code | Why | Other notes |
|---|---|---|---|
| Problem: mortality rates | n/a | The true curve (Gompertz-Makeham) is known, so we can check the network | Lapse prediction was the alternative |
| Data: synthetic data from the life pricing project | n/a | Reuse existing work, known truth | Only age and smoker vary |
| Build: scratch in R, then torch | n/a | Learn first, then compare | Both in RStudio |
| Loss: Poisson deviance | n/a | Deaths are rare counts with exposure | Same assumption as the GLM baseline |
| Repo: mortality-neural-network, public | GitHub + RStudio clone | Portfolio piece | .gitignore set to R |
| Folders: data, r, outputs, docs | New Folder button | Keeps data, code, results and notes apart | Empty folders appear on GitHub once filled |
| Un-ignore docs/ | `# docs/` in .gitignore line 44 | R template hides docs/, and our documentation lives there | Bug found in Step 0 |
| Read the pricing database without changing it | `dbConnect(SQLite(), ...)` | Reuse the project's data, keep the original safe | Path and file name set as variables at the top |
| Skip deferral years | `WHERE e.in_deferral = 0` | No claims are possible during deferral | 11,144 exposure years removed |
| LEFT JOIN for deaths | `LEFT JOIN Death d ON ...` | Keeps exposure rows with no death as 0 deaths | A plain JOIN would drop them |
| Group by attained age and smoker status | `GROUP BY` | Poisson loss only needs totals per group | 316,390 rows became 168 |
| Save grouped data as CSV | `write.csv(...)` | Later steps run without the database | Totals re-checked after reading it back |
| Work in scripts, not the Console | `r/01_load_data.R` | Reproducible and pushable to GitHub | Rule for the rest of the project |
| Split by policy, not by grouped rows | `sample(policies$policy_id)` | Every set sees all ages, so the test is honest | Splitting the 168 grouped rows would have hidden whole ages from training |
| Split sizes 70/15/15 | `train_share`, `valid_share` | Standard split: learn, tune, final exam | Set as variables, so they can change |
| Seed 3130 | `set.seed(3130)` | Same split every run | Matches the pricing project |
| Temporary table for split labels | `dbWriteTable(..., temporary = TRUE)` | Joins the labels in SQL without changing the pricing database | Table disappears on disconnect |
| GLM form: age + smoker, Poisson, log link, exposure offset | `glm(deaths ~ attained_age + smoker_status + offset(log(exposure)), ...)` | Standard actuarial benchmark, same loss as the network | Age enters as a straight term only |
| Fit on train only | `data = train` | Valid and test stay unseen | n/a |
| Compare models by Poisson deviance on the same rows | `poisson_deviance()` | Fair comparison. Deviance differs by set size, so only same-row comparisons count | Train deviance matched `summary()` |
| Plot train only, drop zero-death groups | `subset(train, deaths > 0)` | Test stays sealed, and zeros can't show on a log axis | 39 of 167 groups dropped |
| Scale age by dividing by 100 | `age_scale <- 100`, `x <- c(age / age_scale, smoker)` | Keeps inputs near 0 to 1, so training stays stable | Setting, can be changed |
| Output neuron uses exp() | `rate <- exp(z)` | Keeps rates positive, same log link as the GLM | One neuron is then a Poisson GLM |
| Predicted deaths = rate x exposure | `mu <- rate * row$exposure` | Poisson offset idea | n/a |
| Start with made-up weights | `w <- c(2.0, 1.5)`, `b <- -3.0` | Only to show the arithmetic | Real networks start from small random numbers |
| Slope formula 2 x (predicted - actual) | `grad_z <- 2 * (mu - y)` | The slope of Poisson deviance with an exp output | Given without proof, derived in Step 4 |
| Learning rate 0.01 | `learning_rate <- 0.01` | Big enough to learn, small enough not to overshoot on this group | Setting, will be tuned |
| Train on one group first | `row <- subset(...)` | Simplest way to see the learning loop | Memorizes noise, so real training uses all groups |