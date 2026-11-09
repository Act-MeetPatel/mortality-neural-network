# Step 2: Poisson GLM Baseline

## What we did
Split the policies into train, validation and test sets, fitted a Poisson GLM on the train set, scored it with Poisson deviance on all three sets, and plotted the fit against observed mortality.

## Why
The GLM is the traditional actuarial benchmark. The neural network has to match or beat its deviance on the same rows, or the added complexity is not worth it.

## How
Scripts: `r/01_load_data.R` (updated with the split) and `r/02_glm_baseline.R`.
1. Randomly assigned each of the 10,000 policies to train (7,000), valid (1,500) or test (1,500), with `set.seed(3130)`.
2. Regrouped exposure and deaths by split, attained age and smoker status. Saved to `data/grouped_exposure_deaths.csv`.
3. Fitted `glm(deaths ~ attained_age + smoker_status + offset(log(exposure)), family = poisson)` on train only.
4. Scored train, valid and test with Poisson deviance.
5. Plotted observed and fitted rates for train only.

## Logic and worked example
Model: log(expected deaths) = log(exposure) + b0 + b1 x age + b2 x smoker
So: rate = exp(b0 + b1 x age + b2 x smoker)

Fitted values: b0 = -12.2517, b1 = 0.1096, b2 = 0.9182.
- Age multiplier per year: exp(0.1096) = 1.116 (about +11.6% per year).
- Smoker multiplier: exp(0.9182) = 2.50.
- Age 40 nonsmoker: exp(-12.2517 + 0.1096 x 40) = exp(-7.868) = 0.00038.
- Age 40 smoker: 0.00038 x 2.50 = 0.00096.

Poisson deviance: 2 x sum of [ y x ln(y / mu) - (y - mu) ], where y is actual deaths and mu is predicted deaths. A group with 0 deaths contributes 2 x mu.

## Results
| Set | Rows | Total deviance | Mean per row |
|---|---|---|---|
| Train | 167 | 162.54 | 0.97 |
| Valid | 166 | 143.25 | 0.86 |
| Test | 165 | 139.91 | 0.85 |

Benchmark for the network: valid 143.25 and test 139.91, on the same rows.

Checks:
- Total deviance on train (162.535) equals the residual deviance reported by `summary()` (162.53), so the deviance function is correct.
- Residual deviance / degrees of freedom = 162.53 / 164 = 0.99, consistent with the Poisson assumption.
- Split shares are close to 70/15/15 by exposure (70.4 / 14.9 / 14.7 percent). Death rates are similar across sets (2.12, 2.16 and 2.16 percent).

Plot: `outputs/glm_fit_train.png`. The GLM follows the data well from about age 55 to 100. Below about age 50 most observed points sit above the fitted lines. 39 of 167 train groups had zero deaths and cannot be shown on a log axis.

## Bugs and corrections
1. Design correction: splitting the 168 grouped rows would have put whole age and smoker groups in one set, so the test set would contain ages the model never saw. Fixed by splitting by policy first and then grouping each set.
2. Wrong prediction on our side: we expected valid and test deviance near their row counts (about 160 to 170). They came in at 143 and 140. The cause is that smaller sets have fewer expected deaths per group, which lowers Poisson deviance naturally. It is not a sign of a better fit, so deviance is only comparable on the same rows.

## Limitations and assumptions
Facts:
- The GLM has 3 parameters and no sign of overfitting (valid and test deviance are not worse than train).
- A GLM with age as a straight term gives an exponential curve, so it cannot reproduce the flat floor (Makeham term) at young ages.

Assumptions:
- ASSUMPTION: the log-linear age effect (no age squared term). A richer GLM could do better, and we kept it simple on purpose.
- ASSUMPTION: the split is random by policy, so each set is representative. A different seed would give slightly different numbers.
- ASSUMPTION: gender is ignored, because the source simulation did not use it.
- ASSUMPTION: the data is synthetic (Gompertz-Makeham), so results describe model behaviour on this data, not real mortality.

Limitations:
- Valid and test hold about 15 percent of the policies each, so thin age groups are noisy.
- Zero-death groups are missing from the log-scale plot, which probably exaggerates the young-age gap visually.
- The test deviance was computed now to set the benchmark. The GLM was not tuned on it, and no modelling choice will be based on it.