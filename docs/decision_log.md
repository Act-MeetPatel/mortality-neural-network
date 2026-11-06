# Decision Log

| Decision | Code | Why | Other notes |
|---|---|---|---|
| Problem: mortality rates | n/a | The true curve (Gompertz-Makeham) is known, so we can check the network | Lapse prediction was the alternative |
| Data: synthetic data from the life pricing project | n/a | Reuse existing work, known truth | Only age and smoker vary |
| Build: scratch in R, then torch | n/a | Learn first, then compare | Both in RStudio |
| Loss: Poisson deviance | n/a | Deaths are rare counts with exposure | Same assumption as the GLM baseline |
| Repo: mortality-neural-network, public | GitHub + RStudio clone | Portfolio piece | .gitignore set to R |
| Folders: data, r, outputs, docs | New Folder button | Keeps data, code, results and notes apart | Empty folders appear on GitHub once filled |