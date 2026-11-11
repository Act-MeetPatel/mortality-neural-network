# Step 5: Training the Network Properly

## What we did
Plotted the loss curve from the first training run, added early stopping on the validation loss, compared five learning rates, checked stability across five random starting seeds, and saved the final network. The test set was not used.

## Why
Step 4 trained for a fixed 5,000 rounds and was still improving. Early stopping finds a good stopping point without using the test set. The learning rate and seed checks show how much the result depends on settings.

## How
Script: `r/05_train_network.R`
1. Loss curve: plotted train and valid loss per round on a log scale, with the GLM scores as dashed lines.
2. Early stopping: every 100 rounds the validation loss is measured. The weights from the best round are kept. Training stops after 20 checks (2,000 rounds) with no new best. The validation loss is only measured, and never used to update weights.
3. Learning rate comparison: 0.002, 0.005, 0.01, 0.02, 0.05, each with a cap of 50,000 rounds.
4. Seed check: learning rate 0.005, seeds 3130, 1, 2, 3, 4. The seed changes only the random starting weights.
5. Seed 3 was rerun with a cap of 150,000 rounds.
6. Saved tables to `outputs/` and the final weights to `outputs/final_weights.rds`.

## Logic
- Early stopping: keep the weights from the round with the lowest validation loss, stop when it has not improved for 2,000 rounds.
- Mean deviance per group = total Poisson deviance / number of groups. It is only comparable across models on the same rows.
- The GLM benchmark (Step 2), mean deviance per group: train 0.9733, valid 0.8630.

Worked check: the seed 3130 run at 0.005 reproduced the Step 4 log exactly (epoch 0: 65.994 train and 15.101 valid, epoch 5,000: 1.109 and 0.871), and stopped at 13,600 = best round 11,600 + 2,000 patience.

## Results
Loss curve: `outputs/loss_curve_first_run.png`. Both curves fall steeply, then flatten. Valid ends close to the GLM line and train stays above its own, still sloping down at 5,000 rounds.

Learning rates (cap 50,000 rounds):
| Rate | Best round | Best valid | Train at best | Note |
|---|---|---|---|---|
| 0.002 | 7,700 | 0.8496 | 0.9379 | Finished |
| 0.005 | 11,600 | 0.8522 | 0.9149 | Finished |
| 0.01 | 50,000 | 0.8693 | 0.8837 | Hit the cap, still improving |
| 0.02 | n/a | n/a | n/a | Diverged before round 100 |
| 0.05 | n/a | n/a | n/a | Diverged before round 100 |

For 0.02 and 0.05 the loss became non-finite, so the run was cut off. The starting weights remained the "best" and these are not results.

Path comparison, 0.01 vs 0.005 (train / valid):
| Round | 0.01 | 0.005 |
|---|---|---|
| 500 | 6.03 / 2.02 | 2.71 / 1.18 |
| 2,000 | 1.96 / 1.13 | 1.33 / 0.90 |
| 5,000 | 1.02 / 0.914 | 1.11 / 0.871 |
| 10,000 | 0.911 / 0.881 | 0.934 / 0.853 |

The larger rate was slower early, passed 0.005 on train between rounds 2,000 and 5,000, but stayed worse on valid.

Seed check (learning rate 0.005):
| Seed | Best round | Valid | Valid minus GLM | Finished |
|---|---|---|---|---|
| 3130 | 11,600 | 0.8522 | -0.0108 | Yes |
| 1 | 10,300 | 0.8524 | -0.0105 | Yes |
| 2 | 42,200 | 0.8524 | -0.0106 | Yes |
| 4 | 37,200 | 0.8544 | -0.0086 | Yes |
| 3 | 150,000 | 0.8642 | +0.0012 | No, hit the 150,000 cap, still improving |

Final network: seed 3130, learning rate 0.005, weights from round 11,600.
| Set | GLM | Network |
|---|---|---|
| Train | 0.9733 | 0.9149 |
| Valid | 0.8630 | 0.8522 |

The valid gain is 0.0108 per group, about 1.2 percent of the GLM's score. In total deviance (about, from per-group values x number of groups) valid is 141.5 for the network against 143.25 for the GLM.

Checks: reloading `final_weights.rds` gave valid loss 0.8521767, identical to the run it was saved from.

## Bugs and corrections
1. Wrong prediction: we expected learning rate 0.01 to be ahead early and then stall. It was slower early. Our idea that tanh neurons saturate was not supported by the data and was not tested, so no cause is claimed.
2. Seed 3 hit the 50,000-round cap, so its first result (valid 0.8915) was not final. A rerun with 150,000 rounds hit the cap again. It is reported as unfinished.
3. The mean valid loss across all five seeds (0.8606) was misleading, because it included the unfinished seed 3. The mean of the four finished runs is 0.8529.

## Limitations and assumptions
Facts:
- Four of five seeds finished and agree on valid within 0.002, each beating the GLM by 0.009 to 0.011 per group.
- Learning rates 0.02 and above diverge with this network, because the exp() output overflows.
- Seed 3 needed more than 150,000 rounds, over 10 times the fastest seed (10,300).

Assumptions:
- ASSUMPTION: the grid of 5 learning rates and 5 seeds is enough to show stability. It is a small grid.
- ASSUMPTION: patience of 20 checks (2,000 rounds) is long enough to avoid stopping early on a plateau. Seed 3 shows slow runs exist, and it is possible others would have improved with more patience.
- ASSUMPTION: 0.005 and 0.002 are tied. The valid gap of 0.0026 per group is within noise, and 0.005 was chosen because it reached its best round faster.
- ASSUMPTION: the data is synthetic (Gompertz-Makeham), so results describe model behaviour on this data, not real mortality.

Limitations:
- The validation loss was used to choose the stopping round, the learning rate and the seed check. Every valid number is therefore slightly optimistic. Only the sealed test set is an independent check.
- All five seeds use the same 166 validation groups, so seed agreement is not independent confirmation of the gain.
- The gain over the GLM is small and the settings changed the valid score by about as much (0.02 per group between learning rates 0.005 and 0.01).
- Seed 3 is unfinished, and the cause of its slow start is unknown.
- Only one architecture (8 tanh neurons, 1 hidden layer) was trained.
- The test set has not been used.