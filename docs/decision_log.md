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