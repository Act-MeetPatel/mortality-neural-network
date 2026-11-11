# Step 4: Neural Network from Scratch

## What we did
Built a neural network in base R (no packages): 2 inputs, one hidden layer of 8 tanh neurons, and one output neuron with exp(). Wrote the forward pass and backpropagation, proved the slopes correct with a numerical check, and ran a first training loop of 5,000 rounds.

## Why
Building it by hand shows exactly how a network learns. The slope check proves the backward pass is correct before we trust any training result.

## How
Script: `r/04_network_scratch.R`
1. Turned each set into matrices: X (scaled age and smoker flag), y (deaths) and exposure.
2. Created 33 starting parameters: W1 (2 x 8), b1 (8), W2 (8 x 1), b2 (1).
3. Forward pass: hidden = tanh(X W1 + b1), then rate = exp(hidden W2 + b2), then predicted deaths = rate x exposure.
4. Loss: Poisson deviance, averaged over groups.
5. Backward pass: slopes for all 33 parameters by the chain rule.
6. Gradient check: compared each slope with a numerical estimate.
7. Training loop: full-batch gradient descent on the train set, validation loss recorded but never used to update weights.

## Logic and worked example
Forward pass, per group:
- Z1 = X W1 + b1, then H = tanh(Z1)
- z2 = H W2 + b2, then rate = exp(z2), then mu = rate x exposure

Backward pass, per group (g is the slope at the output):
- g = 2 x (mu - y). Derivation: slope of loss with respect to mu is 2 x (mu - y) / mu, slope of mu with respect to z2 is mu, and the mu cancels.
- Check against Step 3: 2 x (217.40 - 2) = 430.8.
- dW2 = t(H) g / n, and db2 = sum(g) / n
- blame on H = g t(W2), then blame on Z1 = (blame on H) x (1 - H^2), because the slope of tanh is 1 - tanh^2
- dW1 = t(X) (blame on Z1) / n, and db1 = column sums of (blame on Z1) / n
- Dividing by n (the number of groups) makes these the slopes of the mean deviance.

Starting point worked check:
- b2 = ln(4,558 / 214,868) = -3.853, so exp(b2) = 0.0212, the overall death rate.
- With random weights, the network predicted 3,249 deaths against 4,558 actual.
- db2 = 2 x (3,249.06 - 4,558) / 167 = -15.676.
- Mean loss = 11,021.02 / 167 = 65.994.

## Results
Gradient check (all 33 parameters, nudge size 1e-5), largest slope about 22.4:
| Parameter group | Max difference |
|---|---|
| W1 | 2.4e-09 |
| b1 | 2.0e-09 |
| W2 | 2.9e-09 |
| b2 | 2.0e-09 |

Training (learning rate 0.005, 5,000 rounds), mean deviance per group:
| Epoch | Train | Valid |
|---|---|---|
| 0 | 65.994 | 15.101 |
| 250 | 5.142 | 1.712 |
| 500 | 2.710 | 1.178 |
| 1,000 | 1.731 | 0.972 |
| 2,500 | 1.283 | 0.891 |
| 5,000 | 1.109 | 0.871 |

GLM benchmark (Step 2), same measure: train 0.973, valid 0.863.

At round 5,000 the network is close to the GLM but not equal or better, and both losses were still falling. Valid loss fell together with train loss, so there is no sign of overfitting.

## Bugs and corrections
1. Two of our predictions were off. We expected starting rates of 0.01 to 0.04, and they were 0.008 to 0.019. We expected a starting deviance near the flat model (9,460), and it was 11,021. Cause: b2 gives the average rate only when the hidden layer contributes zero, and the random weights added a downward push. Not a code bug.
2. Check lines had been placed inside the script. They were moved to the Console, so the script contains only pipeline code.

## Limitations and assumptions
Facts:
- All 33 slopes agree with the numerical check to about 1e-9, so backpropagation is correct for the starting weights.
- Training was stopped by a fixed number of rounds, not by convergence.

Assumptions:
- ASSUMPTION: one hidden layer of 8 neurons is enough for two inputs. Chosen for simplicity, and not tested against alternatives.
- ASSUMPTION: tanh suits a smooth mortality curve. This is reasoning, not a tested result. ReLU might work as well.
- ASSUMPTION: age scaled by dividing by 100, random weights drawn with standard deviation 0.5, and b2 set to the log of the overall rate. All are settings.
- ASSUMPTION: learning rate 0.005 and 5,000 rounds are a first try, not tuned.
- ASSUMPTION: the data is synthetic (Gompertz-Makeham), so results describe model behaviour on this data, not real mortality.

Limitations:
- The gradient check was run at the starting weights only. It is strong evidence, not proof for every later point.
- One random starting point (seed 3130). Another seed could train differently.
- Valid and test sets are small, so valid loss is noisy.
- The test set has not been used, and stays sealed until the final evaluation.