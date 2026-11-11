# Step 8: Comparing Both Models with the True Mortality Curve

## What we did
Found the exact formula that generated the data, computed the true one-year death probability for every age and smoker group, and measured how close the GLM and the network are to it. No test data was used, and nothing was changed in the network.

## Why
The test set is a noisy sample of the truth, so it could not answer where the two models differ. The truth is a formula and has no noise.

## How
Script: `r/08_true_curve_comparison.R`
1. Read the pricing project's code (`02_simulate_deaths_exposure.R`, and an identical copy in `04_mortality_study.R`) to get the exact formula. The simulation calls `calculate_qx(current_age, smoker_status)` and then draws `runif(1) < qx`, and the death record stores the same `current_age`. No death is drawn during deferral. Only the lines around that call were read (lines 45 to 59), so anything above line 45 was not seen.
2. Copied the function as `true_qx()`, with `ifelse` so it handles a whole column of ages.
3. Built a grid of ages 20 to 105 for both smoker groups, with the true rate, the GLM rate (refit on train only) and the network rate (final weights from Step 5).
4. Restricted the comparison to the 167 age and smoker groups that have train exposure, so ages with no data are left out.
5. For each group, scored each model's expected deaths against the true expected deaths with Poisson deviance, weighted by train exposure, and summed within age bands.
6. Compared total expected deaths with the truth and with observed deaths on train and on the validation exposure.
7. Plotted the rates and the ratio to the truth.

## Logic and worked example
True formula (copied from the pricing project):
- Force of mortality: mu = A + B x C^age, with A = 0.00022, B = 0.0000027, C = 1.124
- Smokers: mu x 2.5
- One-year death probability: qx = 1 - exp(-mu), which cannot exceed 1

Worked example, age 40 nonsmoker (hand calculation, approximate):
- 1.124^40 is about 107.3, so B x C^40 is about 0.000290
- mu = 0.00022 + 0.000290 = 0.000510
- qx = 1 - exp(-0.000510), about 0.000510. Code gives 0.0005096.
- Smoker: mu x 2.5 = 0.001274, code gives qx = 0.0012736.

Error measure per group: 2 x [ T x ln(T / M) - (T - M) ], where T is the true expected deaths (true qx x exposure) and M is the model's expected deaths. The truth has no randomness, so this measures only the gap between model and truth.

Calibration = model expected deaths / true expected deaths. 1.00 is exact.

## Results
Rates at four ages (model / truth in brackets):
| Age, group | True | GLM | Network |
|---|---|---|---|
| 20, nonsmoker | 0.000248 | 0.000043 (0.17) | 0.000142 (0.57) |
| 40, nonsmoker | 0.000510 | 0.000383 (0.75) | 0.000492 (0.97) |
| 40, smoker | 0.001274 | 0.000959 (0.75) | 0.001632 (1.28) |
| 100, nonsmoker | 0.2755 | 0.2746 (1.00) | 0.2970 (1.08) |

True rates over ages 20 to 105 run from 0.000248 to 0.7643.

By age band (train exposure, 167 groups):
| Band | Exposure | True deaths | GLM calibration | Network calibration | GLM distance | Network distance | Closer |
|---|---|---|---|---|---|---|---|
| 20-39 | 24,987 | 12.0 | 0.54 | 0.94 | 4.88 | 0.44 | Network |
| 40-59 | 66,630 | 123.1 | 1.01 | 1.14 | 0.73 | 3.32 | GLM |
| 60-79 | 86,015 | 1,205.7 | 1.03 | 1.04 | 1.80 | 3.40 | GLM |
| 80-99 | 36,560 | 3,019.9 | 0.98 | 1.005 | 3.26 | 1.91 | Network |
| 100-105 | 676 | 214.9 | 1.02 | 1.10 | 0.25 | 2.28 | GLM |
| Total | 214,868 | 4,575.5 | n/a | n/a | 10.90 | 11.36 | Tie |

Overall level (total expected deaths):
| Set | Observed | Truth | GLM | Network |
|---|---|---|---|---|
| Train | 4,558 | 4,575.5 | 4,558.0 | 4,677.9 (+2.6% vs observed, +2.2% vs truth) |
| Valid | 984 | 970.2 | 966.8 (-0.35% vs truth) | 991.3 (+2.2% vs truth) |

The network's output-bias slope on the train set at the final weights is 1.436 (hand calculation from the Step 4 formula: 2 x (4,677.9 - 4,558) / 167 = 1.436). A converged network would have this near zero. So the network stopped before it finished fitting its overall level.

Plots: `outputs/true_vs_models_rates.png` and `outputs/true_vs_models_ratio.png`.
- Above about age 50 all three curves nearly coincide. At young ages the true curve flattens (Makeham floor), the GLM keeps falling, and the network sits in between.
- The GLM's ratio to truth is nearly the same for both smoker groups (its smoker effect is exactly 2.5 at every age, equal to the true multiplier), so its only error is the age shape.
- The network's ratio rises above 1 around ages 40 to 55, peaking near 1.1 for nonsmokers and about 1.3 to 1.4 for smokers (read from the plot, approximate). Its smoker to nonsmoker ratio at age 40 is 3.3, against the true 2.5.
- The large dots (groups with the most exposure, ages 60 to 90) are within a few percent of 1 for both models.

## Bugs and corrections
No code bugs. Mistakes and wrong predictions in the analysis:
1. We guessed the network would be closer to the truth in the young and middle bands and the GLM in the oldest. It was mixed: the network won 20-39 and 80-99, the GLM won 40-59, 60-79 and 100-105.
2. We said young ages contribute little to the total deviance, so a large error there hardly matters. Against the truth that is wrong: 20-39 is the GLM's largest error band (4.88 of 10.90). It looked small on the test set because the test data is noisy and holds about a fifth of the train exposure. A rough estimate (the 20-39 gap of about 4.4 scaled by that exposure share, not computed in code) puts the young-age difference at about 0.9 deviance units on the test set, against a total of about 140, which is too small for the test to detect.
3. The network's overall level error was not predicted. It was found when the band calibrations were summed.
4. The observed validation deaths (984, against a truth of 970.2) hid the level error, because they landed 14 deaths above the truth, inside the random noise of about 31. Comparing with the true expected deaths removes that noise.
5. A rounding slip in chat: the true age 40 nonsmoker rate was quoted as 0.000509 once, and 0.0005096 rounds to 0.000510.

## Limitations and assumptions
Facts:
- The pricing project's function, as copied, uses A = 0.00022, B = 0.0000027, C = 1.124, a smoker multiplier of 2.5 and qx = 1 - exp(-mu).
- Overall the two models are equally close to the truth (10.90 against 11.36), consistent with the tie on the test set in Step 6.
- The network is about 2.2% above the true total deaths on both the train and the validation exposure. The GLM is within 0.4%.

Assumptions:
- ASSUMPTION: the formula in the pricing project is the one that generated the data. Supported by the GLM recovering the 2.5 smoker multiplier (exp(0.918) = 2.50) and by the simulation calling it with the same age that the death record stores. Lines above 45 of the simulation script were not read.
- ASSUMPTION: current_age in the simulation is the attained age used in our exposure table. Supported by all 6,512 deaths matching an exposure row on attained age in Step 1.
- ASSUMPTION: the output bias is not converged because early stopping on validation loss ended training before the network's level was fitted. Supported by the slope of 1.436, but other seeds were not checked.
- ASSUMPTION: the data is synthetic, so these results describe model behaviour against a known formula, not real mortality.

Limitations:
- The comparison weights errors by train exposure and covers only groups with train exposure. A different weighting, or ages with no data, could change which model wins a band.
- The level error and the shape errors were not separated, so we do not know how much of the network's 11.36 comes from each.
- The cause of the network's smoker to nonsmoker ratio drifting away from 2.5 is unknown. Not tested.
- We did not check whether either model outputs a probability above 1 at any age. The true rate is capped by construction. Ratios at 100 to 105 (1.02 for the GLM, 1.10 for the network) suggest both are in range, but no check was made.
- The network is not changed. The level error could be fixed (for example by rescaling its output), but doing so after seeing the test result would break the rule set in Step 6, so it is reported as a finding.
- Only one network and one seed (3130) are compared with the truth. Seed 3 was not finished (Step 5), and the other seeds were not compared with the truth.
- The checks on the network's level (`level_check`, `g_final$db2`) came from Console commands first, and were then added to the script.