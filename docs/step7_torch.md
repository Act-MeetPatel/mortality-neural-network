# Step 7: Rebuilding the Network with torch

## What we did
Installed the `torch` package for R, rebuilt the same network with it, checked its automatic slopes against our hand-written backpropagation, and trained it from the same starting weights with the same settings as Step 4.

## Why
`torch` finds slopes automatically (autograd). If it reproduces our hand-built network exactly, that is a second, independent check that our code is correct.

## How
Script: `r/07_torch_network.R`
1. Installed `torch` and checked it works. All tensors are created in double precision (`torch_float64()`), so they match R's numbers.
2. Rebuilt the starting weights with the same recipe and seed (3130) as Steps 4 and 5.
3. Wrote the forward pass and loss with torch operations. `y` is replaced by 1 inside the logarithm only (`y_safe`), because groups with zero deaths would otherwise compute log(0). Those terms are multiplied by y = 0, so the loss does not change.
4. `loss$backward()` (autograd) finds every slope. It replaces our `backward()` function.
5. Compared torch's slopes with ours at the starting weights.
6. Trained for 5,000 rounds with `optim_sgd` at learning rate 0.005. Each round: `zero_grad()` (torch adds new slopes onto old ones, so they must be cleared), forward pass and loss, `backward()`, `step()`. The validation loss is measured without recording (`with_no_grad`) and never used for updates.

## Logic
`optim_sgd` applies the same rule as our loop: new = old - learning rate x slope. Torch and our code compute the same loss and the same slopes, so they should follow the same path.

## Results
Slope check at the starting weights (largest slope about 22.4):
| Version | Loss (15 digits) | Slope differences vs ours |
|---|---|---|
| First attempt | 65.9941253662109 | 5.4e-07 to 8.3e-07 |
| After the fix | 65.9941202859812 (identical to ours) | 3.1e-15 to 1.2e-14 |

Training, 5,000 rounds from the same start:
| Check | Result |
|---|---|
| Logged rows | 21 |
| Last row | Epoch 5,000, train 1.109113, valid 0.8710669 (same as Step 4) |
| Largest train loss difference vs Step 4 | 2.0e-12 |
| Largest valid loss difference vs Step 4 | 4.6e-13 |
| Largest weight difference (W1) vs Step 4 | 3.2e-13 |

The torch network and the hand-built network are the same network, to about 12 decimal places. This is a rounding-level difference, expected after thousands of steps.

## Bugs and corrections
1. Single-precision bug. The first torch loss differed from ours by about 5e-06 (7.7e-08 relative), and the slopes by about 5e-07. Stepping through the loss one operation at a time, with `$dtype` after each, showed every step stayed double precision until `2 * s`, where `s` is the loss total and `2` a plain R number. The result became single precision (`torch_Float`), and the division after it stayed single. Fix: build the constant `2 / n` as a double-precision tensor (`to_t(2 / X$shape[1])`) and multiply by it. After the fix the loss is double precision and the slopes agree to about 1e-14.
2. Why a plain number triggers this: not established. We guess that R turns the plain number into a single-precision tensor by default, but we did not test it, and the fix does not depend on it.
3. Predictions that were wrong: we expected slope differences below 1e-10 and got about 5e-07 on the first attempt. Our first search looked at the weight, input and data tensors, which were fine (copied exactly, double precision), so it was in the wrong place. Printing the losses to 7 digits also showed no new information, so the diagnostic had to be repeated with 15 digits.
4. A slip in the chat: one reported slope range gave the minimum as 3.6e-15. The correct value is 3.1e-15. Written correctly above.

## Limitations and assumptions
Facts:
- Torch autograd and our hand-written backward pass agree to about 1e-14 at the starting weights.
- After 5,000 rounds the two networks agree to about 1e-12 in loss and 3e-13 in weights.

Assumptions:
- ASSUMPTION: agreement over 5,000 rounds from one seed (3130) and one learning rate (0.005) is representative. Other seeds and rates were not run in torch.
- ASSUMPTION: the cause of the single-precision change is a default for plain R numbers. Not tested.
- ASSUMPTION: the data is synthetic, so this checks the code, not real mortality.

Limitations:
- Early stopping, the learning rate search and the seed check were not repeated in torch. The final network remains the hand-built one from Step 5 (seed 3130, learning rate 0.005, best round 11,600).
- Torch gives the same answer here, not a better one. Its advantages are less code, speed and larger networks, none of which this small problem needs.
- Package versions and the Mac processor type were not recorded, so the install is not reproducible from these notes alone.