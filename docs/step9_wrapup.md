# Step 9: Wrap-up

## What we did
Recorded the R and package versions, checked that the project reproduces from a restarted R session, wrote the README, and produced a full recap of the project.

## Why
The Step 7 write-up noted that package versions were not recorded, so the project could not be reproduced from its notes alone. The project had also never been run from a clean start.

## How
1. `r/09_session_info.R` records the version of R and the four packages the project loads (DBI, RSQLite, ggplot2, torch) and saves `sessionInfo()` to `docs/session_info.txt`.
2. Restarted R (Session, Restart R), then ran `source("r/01_load_data.R")` and `source("r/06_test_evaluation.R")`.
3. Checked with `git status --short data` whether the rebuilt CSV differed from the committed one.
4. Wrote `README.md`: headline result, method, results tables, repository map, how to reproduce, limitations, versions.
5. Added `docs/*.html` to `.gitignore`, so the generated copy of the decision log stops showing up in the Git tab. The `.md` files are not affected.

## Results
Versions: R 4.4.1, DBI 1.3.0, RSQLite 2.4.6, ggplot2 4.0.0, torch 0.16.3.

Reproducibility check, after the restart:
| Check | Result |
|---|---|
| GLM test score | mean 0.8479215, total 139.9071 (same as Step 6) |
| Network test score | mean 0.8483679, total 139.9807 (same as Step 6) |
| Rebuilt CSV vs committed CSV | no difference (`git status --short data` printed nothing) |
| `docs/session_info.txt` | exists |

The last three rows are as reported by the user. The test scores were printed and matched. The output of the `git status` and file checks was not pasted, so it is a report and not something we saw.

Running `06` scores the test set again, with identical numbers. No modelling choice depends on it.

## Bugs and corrections
1. The first reproducibility report showed the test scores and versions but not the CSV check, which was the most important line. It was requested and confirmed instead of assumed.
2. The Step 7 gap (versions not recorded) is closed here.

## Limitations and assumptions
Facts:
- The scores after a restarted session match the committed results.

Assumptions:
- ASSUMPTION: the project reproduces on another computer. Not tested. Floating-point results can differ in the last digits across machines, and the hand-built training loop and `torch` could differ by about 1e-12 or more.
- ASSUMPTION: the four recorded packages are the only ones that matter. `sessionInfo()` in `docs/session_info.txt` lists the rest.

Limitations:
- R was restarted, but packages were already installed. A fresh install of the packages was not tested.
- `01_load_data.R` needs the pricing project's database at the path set at the top. The grouped CSV is committed, so scripts 02 to 08 run without it.
- `05_train_network.R` takes several minutes, mainly the seed 3 rerun with a 150,000-round cap.
- The LinkedIn post was drafted but not posted or saved in the repository.