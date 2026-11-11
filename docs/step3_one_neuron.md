# Step 3: One Neuron by Hand

## What we did
Coded a single neuron in R, scored its prediction on one real group with Poisson deviance, took one gradient descent step by hand, then repeated the step 100 times and watched the loss settle.

## Why
Before building a full network, we need to see the learning loop (forward pass, loss, slope, nudge) work on the smallest possible model. It also shows that a single neuron with an exp output is the same model as the Poisson GLM from Step 2.

## How
Script: `r/03_one_neuron.R`
1. Inputs: scaled age (age / 100) and a smoker flag (1 = smoker).
2. Forward pass: z = w1 x age_scaled + w2 x smoker + b, then rate = exp(z), then predicted deaths = rate x exposure.
3. Scored the prediction on one real group (age 40 nonsmokers, train set) with Poisson deviance.
4. One gradient descent step, then a loop of 100 steps on that same group.

## Logic and worked example
Forward pass, with made-up starting weights w = (2.0, 1.5) and b = -3.0, for the real group (age 40, nonsmoker, 1,962 exposure years, 2 deaths):
- z = 2.0 x 0.4 + 1.5 x 0 - 3.0 = -2.2
- rate = exp(-2.2) = 0.1108
- predicted deaths = 0.1108 x 1,962 = 217.40
- observed rate = 2 / 1,962 = 0.00102, so the guess was about 100 times too high.

Deviance by hand: 2 x [ 2 x ln(2 / 217.40) - (2 - 217.40) ] = 2 x (-9.377 + 215.40) = 412.04.

Gradient (formula supplied without proof, to be derived in Step 4):
- slope of loss with respect to z = 2 x (predicted - actual) = 2 x (217.40 - 2) = 430.8
- slope for each weight = that slope x its input: 430.8 x 0.4 = 172.3 (age), 0 (smoker)
- slope for the bias = 430.8

Update rule: new = old - learning rate x slope, with learning rate 0.01.
- new age weight = 2.0 - 0.01 x 172.3 = 0.277
- new bias = -3.0 - 0.01 x 430.8 = -7.308
- new z = 0.277 x 0.4 - 7.308 = -7.197, new predicted deaths = exp(-7.197) x 1,962 = 1.469

## Results
| Step | Predicted deaths | Deviance |
|---|---|---|
| 0 | 217.40 | 412.04 |
| 1 | 1.469 | 0.172 |
| 2 | 1.487 | 0.159 |
| 10 | 1.618 | 0.084 |
| 50 | 1.931 | 0.0024 |
| 100 | 1.993 | 0.00002 |

After 100 steps: age weight 0.382, smoker weight 1.500 (unchanged), bias -7.045. Check: exp(0.3822 x 0.4 - 7.0446) = 0.001016, against the observed rate 0.001019.

Checks: every printed value matched the hand calculation (z, rate, predicted deaths, deviance, gradients, step 1 prediction).

## Bugs and corrections
No code bugs. Two observations:
1. The smoker weight never moved, because a nonsmoker group has smoker input 0, so its slope is always 0. One group cannot teach the neuron about smoking.
2. The age weight and bias are not uniquely determined by one group. Many combinations give the same prediction at age 40. Training on all ages at once is what fixes them.

## Limitations and assumptions
Facts:
- A single neuron with an exp output has the same form as a Poisson GLM: rate = exp(intercept + weights x inputs).
- The loss fell from 412 to near 0 on this one group.

Assumptions:
- ASSUMPTION: the starting weights (2.0, 1.5, -3.0) are made up for illustration. They are not learned or meaningful.
- ASSUMPTION: age is scaled by dividing by 100, to keep inputs small.
- ASSUMPTION: a learning rate of 0.01 happened to suit this group. It is a setting that will be tuned later.
- ASSUMPTION (rough hand estimate, not computed in code): the expected deaths for this group under Gompertz-Makeham are about 1, not 2, so the neuron fitted noise.

Limitations:
- This was one group, not the whole dataset. Fitting one noisy group almost perfectly is memorization, which is why real training uses all groups together.
- The gradient formula 2 x (predicted - actual) was given without proof. We derive it in Step 4.
- A single neuron has no hidden layer, so it cannot do better than the GLM.