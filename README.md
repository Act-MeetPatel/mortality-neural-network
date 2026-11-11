# Mortality Neural Network

A neural network built from scratch in R (then rebuilt with `torch`) to predict mortality rates, compared against a traditional Poisson GLM and against the true mortality formula that generated the data.

## Headline result
**On this data the network matched the GLM but did not beat it.** On the held-out test set the two are tied. The network is closer to the true curve at young and very old ages, and the GLM is closer in the middle. This was expected going in, because the data only varies by age and smoker status.

## Data
Synthetic life insurance experience data (10,000 policies, 6,512 deaths) from my separate life insurance pricing project. Deaths were simulated from a Gompertz-Makeham law (parameters taken from actuarial course notes) with a 2.5x smoker multiplier. Because the true mortality is known, we can check every model against it. The results describe how the models behave on this data, not real mortality.

## Method
- **Data:** exposure and deaths grouped by attained age and smoker status. Policies are split at random (seed 3130) into train (70%), validation (15%) and test (15%) before grouping, so every set contains all ages.
- **GLM benchmark:** Poisson, log link, `deaths ~ attained_age + smoker_status`, with log exposure as an offset. Fit on train only.
- **Network:** 2 inputs (age / 100, smoker flag), one hidden layer of 8 tanh neurons, one exp() output neuron. 33 parameters. Poisson deviance loss. Forward and backward passes written by hand in base R.
- **Verification:** the backward pass was checked against a numerical gradient (agreement about 1e-9), and later against `torch` autograd (agreement about 1e-14). A `torch` rebuild trained from the same start matches the hand-built network to about 1e-12.
- **Training:** full-batch gradient descent, learning rate 0.005, early stopping on validation loss.

## Results
Mean Poisson deviance per group (lower is better):

| Set | GLM | Network |
|---|---|---|
| Train | 0.9733 | 0.9149 |
| Validation (used to choose the stopping round) | 0.8630 | 0.8522 |
| Test (used once, at the end) | 0.8479 | 0.8484 |

The network's edge shrinks from train to validation to test, and is gone on the test set (165 groups, 970 deaths). I read a gap smaller than 0.01 per group as a tie. This threshold was set before looking at the test result, and is a judgment, not a statistical test.

**Against the true curve** (train exposure, 167 groups, total distance GLM 10.90 vs network 11.36, a tie):

| Age band | Closer to the truth |
|---|---|
| 20-39 | Network (GLM expects about half the true deaths, network about 94%) |
| 40-59 | GLM |
| 60-79 | GLM |
| 80-99 | Network |
| 100-105 | GLM (little exposure) |

**Other findings**
- A pure exponential GLM cannot represent the constant (Makeham) term, so it underestimates young-age mortality. The network follows the floor better.
- The network predicts about 2.2% too many deaths overall, on both the train and validation exposure. Its output-bias slope is not zero at the saved weights, so training stopped before the overall level was fully fitted. The network was not retuned after seeing the test result.
- The network's smoker-to-nonsmoker ratio drifts with age (about 3.3 at age 40, against a true constant of 2.5). The cause was not investigated.
- Across five random starting seeds, four finished and agree on validation loss within 0.002. One (seed 3) had not finished after 150,000 rounds.

## Repository
```
r/        scripts, run in order 01 to 09
data/     grouped_exposure_deaths.csv
outputs/  plots, result tables, final_weights.rds
docs/     write-up for each step, decision_log.md, session_info.txt
```

| Script | What it does |
|---|---|
| `01_load_data.R` | Pulls exposure and deaths from the pricing database, splits by policy, groups, saves the CSV |
| `02_glm_baseline.R` | Poisson GLM, scores, plot |
| `03_one_neuron.R` | One neuron by hand, one learning step, then a loop |
| `04_network_scratch.R` | The full network: forward pass, backward pass, gradient check, training loop |
| `05_train_network.R` | Loss curves, early stopping, learning rate search, seed check |
| `06_test_evaluation.R` | Final test-set scores for both models, plot |
| `07_torch_network.R` | The same network in `torch`, checked against the hand-built one |
| `08_true_curve_comparison.R` | Both models against the true mortality formula |
| `09_session_info.R` | Records package versions |

## How to reproduce
1. Open `mortality-neural-network.Rproj` in RStudio.
2. Install the packages: `install.packages(c("DBI", "RSQLite", "ggplot2", "torch"))`. The first time `torch` loads, it downloads its engine (a few hundred MB).
3. Run the scripts in order. Only `01_load_data.R` needs the pricing database (set `db_folder` and `db_file` at the top). The grouped CSV is committed, so steps 02 to 08 run without it.
4. `04_network_scratch.R` retrains for 5,000 rounds (seconds). `05_train_network.R` runs several trainings and takes a few minutes.

Each step has a write-up in `docs/` with the logic, a worked example, results, bugs found and limitations. `docs/decision_log.md` records every decision with the code, the reason and notes.

## Limitations and assumptions
- One random split, one network design, one final seed. A different split could give a different test gap.
- Validation loss was used to choose the stopping round and the learning rate, so validation scores are slightly optimistic. Only the test score is an independent check.
- The GLM is deliberately simple (age enters as a straight term). A richer GLM, for example with an age-squared term, might close the young-age gap. This was not tested.
- Gradient descent is plain full-batch. Seed 3 shows that some starting points train very slowly.
- ASSUMPTION: the formula read from the pricing project's code is the one that generated the data. The GLM recovered the 2.5 smoker multiplier, which supports this.
- The data is synthetic, so nothing here is a statement about real populations.

## Versions
R 4.4.1, DBI 1.3.0, RSQLite 2.4.6, ggplot2 4.0.0, torch 0.16.3. Full details in `docs/session_info.txt`.ch.
