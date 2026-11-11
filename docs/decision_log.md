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
| 1 hidden layer, 8 neurons | `n_hidden <- 8` | Simplest backpropagation, enough for 2 inputs, 33 parameters | Not compared with other sizes yet |
| tanh in the hidden layer | `tanh(Z1)` | Smooth squish should give smooth curves, slope is 1 - tanh^2 | My reasoning, not tested. ReLU is the main alternative |
| exp() on the output | `rate <- exp(z2)` | Keeps rates positive, same log link as the GLM | n/a |
| Inputs as matrices | `make_inputs()` | All groups processed at once, no loop | X is 167 x 2 for train |
| Random starting weights, sd 0.5 | `rnorm(..., sd = init_sd)` | Identical weights would make every neuron learn the same thing | `init_sd` is a setting |
| Hidden biases start at 0 | `b1 <- rep(0, n_hidden)` | Random weights already make the neurons differ | n/a |
| Output bias starts at log of the overall rate | `b2 <- log(sum(y) / sum(exposure))` | First guess is near the average rate, not 100% | Random weights still pushed the start to 3,249 vs 4,558 deaths |
| Same seed | `set.seed(3130)` | Same weights every run | Matches the rest of the project |
| Slopes divided by number of groups | `/ n` in `backward()` | Learning rate no longer depends on set size | Same as using mean deviance |
| Check slopes numerically | `check_gradients()`, eps 1e-5 | A wrong slope would silently ruin training | All 33 agreed to about 1e-9 |
| Full-batch gradient descent | `for (epoch in ...)` | Only 167 groups, so no need for mini-batches | n/a |
| Learning rate 0.005, 5,000 rounds | `learning_rate`, `n_epochs` | First try, safe and slow | Loss still falling at the end. To be tuned in Step 5 |
| Valid loss recorded, never used for updates | `valid_loss` in `history` | Keeps valid an honest check | Test set still sealed |
| Early stopping on validation loss | `train_network()`, patience 20 checks | Stops before the network memorizes noise | Keeps the weights from the best round, not the last |
| Check validation every 100 rounds | `eval_every = 100` | Cheap enough, fine enough to see the trend | Setting |
| Compare 5 learning rates | `rates <- c(0.002, ..., 0.05)` | Find the safe range | 0.02 and 0.05 diverged, 0.01 slow |
| Lock learning rate 0.005 | `final_rate <- 0.005` | Tied with 0.002 on valid (gap within noise), reached its best round faster | Chosen using valid loss, so slightly optimistic |
| Check stability with 5 seeds | `seeds <- c(3130, 1, 2, 3, 4)` | Test whether the gain depends on the starting weights | 4 of 5 finished and agreed within 0.002 |
| Report seed 3 as unfinished | `seed3_long`, cap 150,000 | Still improving after 150,000 rounds | Not chased further. Cause unknown |
| Final model is seed 3130 | `run1$best$params` | The seed used throughout the project | Valid 0.8522, train 0.9149 |
| Save the final weights | `saveRDS(..., "outputs/final_weights.rds")` | Step 6 loads the exact network instead of retraining | Reloaded valid loss matched exactly |
| Test set kept sealed | n/a | It stays the one honest final check | Not touched in Step 5 |
| Dry run before the test exam | `score_glm()` and `score_net()` on train and valid | Proves the pipeline reproduces known numbers, so a bug cannot waste the one honest exam | All four matched |
| Rules fixed before looking at test | Written in the Step 6 notes | Stops the result from bending the conclusion | Includes: never retune after seeing test |
| Tie threshold 0.01 per group | Part B rule | Step 5 settings moved valid by 0.01 to 0.02, so smaller gaps cannot count as a win | My judgment, not a statistical test |
| Score both models once, same rows, same loss | `test_results` | Fair comparison | Test: GLM 0.8479, network 0.8484 |
| Report the tie as it came out | n/a | Network did not beat the GLM on held-out data | Advantage shrank from -0.058 (train) to -0.011 (valid) to +0.0004 (test) |
| Plot both curves on the test set | `p_test`, age grid 20 to 105 | See where the models differ | For understanding only, nothing changed afterwards |
| Drop zero-death groups from the plot | `subset(test_df, deaths > 0)` | Zeros cannot show on a log axis | 62 of 165 dropped |
| Leave the young-age question to Step 8 | n/a | Test dots are too noisy there, and the true curve is known | Network above GLM below about age 45, cause not established |
| Use torch for R, not Python | `install.packages("torch")` | Stays in RStudio, no Python setup | Same engine as PyTorch |
| Double-precision tensors | `to_t()` with `torch_float64()` | Match R's numbers, so we can compare exactly | Default is single precision |
| Same start, same rate, same rounds as Step 4 | `start <- init_params(3130)`, 0.005, 5,000 | Only the tool changes, so any difference is a bug | Matched to about 1e-12 |
| Parameters track slopes | `requires_grad = TRUE` | Autograd needs to know what to differentiate | Data tensors do not |
| Replace zero deaths by 1 inside the log only | `y_safe <- torch_clamp(y, min = 1)` | Avoids log(0) giving NaN | Loss unchanged, those terms are multiplied by y = 0 |
| Loss constant as a double tensor | `scale <- to_t(2 / X$shape[1])` | Multiplying by a plain number turned the loss into single precision | Found by checking `$dtype` after each step. Cause of the default not tested |
| Use torch's optimizer | `optim_sgd(..., lr = 0.005)` | Same rule as ours: new = old - rate x slope | `zero_grad()` needed each round |
| Validation measured without recording | `with_no_grad({...})` | Valid is only measured, never learned from | Same principle as Step 4 |
| Do not rerun tuning in torch | n/a | Would give the same answers | Final network stays the hand-built one |
| Compare against the true formula, not just noisy data | `true_qx()` | The test set is too noisy to show where the models differ | Uses no test data |
| Read the pricing code for the exact formula and its call | `02_simulate_deaths_exposure.R` | Smoker effect and probability conversion could not be guessed | Called with attained age. Lines above 45 not read |
| Copy `true_qx()` with `ifelse` | `ifelse(smoker == "Smoker", ...)` | Handles a column of ages at once | Parameters stay adjustable |
| Error measure: Poisson deviance of model expected deaths against true expected deaths | `dev_true()` | Same loss family as training, and the truth has no noise | Lower is closer |
| Weight by train exposure, only groups with exposure | `merge(grid, w)` | Weights errors by where policyholders are, and avoids ages with no data | A different weighting could change band winners |
| Five age bands | `cut(..., c(19, 39, 59, 79, 99, 105))` | See where each model is better | Setting. The 100-105 band has only 676 exposure years |
| Calibration = model deaths / true deaths | `glm_calib`, `net_calib` | Shows over or under prediction by band | 1.00 is exact |
| Check total deaths against the truth on the valid exposure | `level_check` | Uses exposure only, so no random death counts | Network +2.2%, GLM -0.35% |
| Do not retune the network after finding the level error | n/a | Rule 3 from Step 6: no changes after seeing the test result | Reported as a finding and a limitation |
| Plot rates and ratio to truth, dot size = exposure | `p_rates`, `p_ratio` | Shows where errors are and whether they carry weight | Errors sit at ages with little exposure |
| Save level check and band table | `outputs/level_check.csv`, `outputs/band_table.csv` | Numbers in the write-up are reproducible from files | Console checks moved into the script |
| Record package versions | `r/09_session_info.R`, `docs/session_info.txt` | Step 7 flagged versions as missing, and reproducibility needs them | Only the four loaded packages are listed in the README. The rest are in `sessionInfo()` |
| Check reproducibility from a restarted R session | `source("r/01_load_data.R")`, `source("r/06_test_evaluation.R")` | A project that only works in the session that built it is not finished | Same scores. Another computer not tested |
| Compare the rebuilt CSV with the committed one | `git status --short data` | If the split changed, every later number would change | Printed nothing, as reported |
| README states the result as a tie | `README.md` | Honest headline, and the tie rule is labelled as a judgment | The data is synthetic, so the README says so |
| Ignore generated HTML in `docs/` only | `docs/*.html` in `.gitignore` | Stops `decision_log.html` appearing in the Git tab | A broad `docs/` rule hid the whole folder in Step 0, so this one is narrow |
| Leave the LinkedIn post for later | n/a | Chosen by you | A draft exists in the chat, and is not in the repository |