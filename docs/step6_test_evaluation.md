# Step 6: Final Evaluation on the Test Set

## What we did
Scored the Poisson GLM and the final neural network on the test set, which had been sealed until now, and plotted both models' fitted curves against the observed test rates.

## Why
Validation loss was used to choose the stopping round, the learning rate and the seed check, so valid scores are slightly optimistic. The test set is the one independent check.

## How
Script: `r/06_test_evaluation.R`
1. Refit the GLM on the train set only (same as Step 2).
2. Loaded the final network weights from `outputs/final_weights.rds` (seed 3130, learning rate 0.005, best round 11,600).
3. Dry run before the exam: reproduced the four known scores on train and valid, without touching the test set.
4. Scored both models on the test set with the same loss (mean Poisson deviance per group) on the same 165 groups.
5. Plotted both fitted curves with the observed test rates.

Rules set before looking at the test result:
1. Score the test set once, both models together, on the same rows.
2. Report both numbers as they come out.
3. Do not change the network or its settings afterwards.
4. Read a gap smaller than 0.01 per group as a tie. This threshold is a judgment based on how much settings moved the valid score in Step 5 (about 0.01 to 0.02). It is not a statistical test.

## Logic
Mean deviance per group = total Poisson deviance / number of groups. Both models are scored with the same function on the same rows, so the numbers are comparable.

## Results
Dry run (all matched the earlier steps):
| Call | Result |
|---|---|
| GLM train | 0.9732633 |
| GLM valid | 0.8629578 |
| Network train | 0.9149060 |
| Network valid | 0.8521767 |

Test exam (165 groups, 970 deaths):
| Model | Mean deviance | Total deviance |
|---|---|---|
| GLM | 0.8479 | 139.91 |
| Network | 0.8484 | 139.98 |

The network is worse by 0.0004 per group (about 0.05 percent), a tie under the rule above. The GLM total matches Step 2.

Across all three sets:
| Set | GLM | Network | Network minus GLM |
|---|---|---|---|
| Train | 0.9733 | 0.9149 | -0.0584 |
| Valid | 0.8630 | 0.8522 | -0.0108 |
| Test | 0.8479 | 0.8484 | +0.0004 |

The network's advantage shrinks as the data gets further from what it was trained and selected on, and is gone on the test set.

Plot: `outputs/test_fit_glm_vs_network.png`. 62 of 165 test groups had zero deaths and cannot show on the log axis.
- From about age 55 to 95 the two fitted curves are nearly identical and follow the observed rates.
- Below about age 45 the network curve sits above the GLM curve for both smoker groups (the network flattens, the GLM keeps falling).
- Above about age 100 the network curve bends slightly below the GLM.
- Network divided by GLM over ages 20 to 105: minimum 0.85 (age 105, smoker), median 1.06, maximum 3.54 (age 20, smoker).

## Bugs and corrections
No code bugs. The dry run reproduced every earlier number, so the evaluation pipeline was sound before the test set was scored.

Predictions that did not hold:
- We hoped the network's valid advantage from Step 5 would carry over. It did not.
- We expected the median network/GLM ratio to be near 1. It was 1.06.

## Limitations and assumptions
Facts:
- On the test set the two models are tied under the rule above.
- The fitted curves differ mainly at the edges of the age range.

Assumptions:
- ASSUMPTION: the tie threshold of 0.01 per group is a judgment, not a statistical test.
- ASSUMPTION: the shrinking advantage across train, valid and test fits the idea that part of the gain was fitting noise in train and part was selection on valid. This is not proven. With 165 test groups and 970 deaths the test score is also noisy, and we cannot separate those causes with this data.
- ASSUMPTION (reasoning, not measured): the models can differ at young ages yet tie in total because young groups have very few expected deaths, so they add little to the total deviance.
- ASSUMPTION: the data is synthetic (Gompertz-Makeham), so results describe model behaviour on this data, not real mortality.

Limitations:
- One random split, one test set, one network seed (3130). A different split could give a different test gap.
- The observed test dots at young ages are noisy (single deaths in small exposure) and the 62 zero-death groups are missing from the log plot, so the plot cannot settle the young-age question.
- The plotted grid covers ages 20 to 105 for both smoker groups, including ages with no policies, where both models extrapolate. Differences there say nothing about accuracy.
- The test set was used for the score and for the plot. No change was made to the network or settings after seeing either.
- The question of which model is closer to the truth at young ages is left to Step 8, which compares both against the known Gompertz-Makeham curve.