# 07_torch_network.R
# The same network built with torch, checked against our hand-built version.

library(torch)

# Loads the data and our hand-built forward(), backward(), mean_loss()
source("r/04_network_scratch.R")

# ---- Same starting weights as Steps 4 and 5 (seed 3130) ----
init_params <- function(seed = 3130) {
  set.seed(seed)
  W1 <- matrix(rnorm(2 * n_hidden, sd = init_sd), nrow = 2, ncol = n_hidden)
  b1 <- rep(0, n_hidden)
  W2 <- matrix(rnorm(n_hidden, sd = init_sd), nrow = n_hidden, ncol = 1)
  b2 <- log(sum(train$y) / sum(train$exposure))
  list(W1 = W1, b1 = b1, W2 = W2, b2 = b2)
}
start <- init_params(3130)

# ---- Helper: R numbers -> double-precision tensor ----
to_t <- function(a, grad = FALSE) {
  torch_tensor(a, dtype = torch_float64(), requires_grad = grad)
}

# ---- Data as tensors ----
X_t   <- to_t(train$X)
y_t   <- to_t(train$y)
exp_t <- to_t(train$exposure)

# ---- Parameters as tensors that record their slopes ----
W1_t <- to_t(start$W1, TRUE)
b1_t <- to_t(start$b1, TRUE)
W2_t <- to_t(start$W2, TRUE)
b2_t <- to_t(start$b2, TRUE)

# ---- Same forward pass and loss, written with torch operations ----
torch_mean_loss <- function(X, y, exposure, W1, b1, W2, b2) {
  H      <- torch_tanh(torch_matmul(X, W1) + b1)
  z2     <- torch_matmul(H, W2)[, 1] + b2
  mu     <- torch_exp(z2) * exposure
  y_safe <- torch_clamp(y, min = 1)
  term   <- y * torch_log(y_safe / mu)
  scale  <- to_t(2 / X$shape[1])           # a double-precision constant
  torch_sum(term - (y - mu)) * scale
}

# ---- Let torch find the slopes automatically ----
loss_t <- torch_mean_loss(X_t, y_t, exp_t, W1_t, b1_t, W2_t, b2_t)
loss_t$backward()

# ---- Our own slopes at the same starting weights ----
mine <- backward(train$X, train$y, train$exposure,
                 start$W1, start$b1, start$W2, start$b2)

# ---- Train the torch network: same start, same rate, same rounds as Step 4 ----
learning_rate_t <- 0.005
n_epochs_t      <- 5000
log_every_t     <- 250

# Fresh copies of the starting weights, so training starts from the same place
W1_t <- to_t(start$W1, TRUE)
b1_t <- to_t(start$b1, TRUE)
W2_t <- to_t(start$W2, TRUE)
b2_t <- to_t(start$b2, TRUE)

opt <- optim_sgd(list(W1_t, b1_t, W2_t, b2_t), lr = learning_rate_t)

# Validation data as tensors (measured only, never used for updates)
X_v   <- to_t(valid$X)
y_v   <- to_t(valid$y)
exp_v <- to_t(valid$exposure)

torch_history <- data.frame(epoch = integer(), train_loss = numeric(),
                            valid_loss = numeric())

for (epoch in 0:n_epochs_t) {
  opt$zero_grad()
  loss <- torch_mean_loss(X_t, y_t, exp_t, W1_t, b1_t, W2_t, b2_t)
  loss$backward()
  
  if (epoch %% log_every_t == 0) {
    v <- with_no_grad({
      torch_mean_loss(X_v, y_v, exp_v, W1_t, b1_t, W2_t, b2_t)
    })
    torch_history <- rbind(torch_history,
                           data.frame(epoch      = epoch,
                                      train_loss = loss$item(),
                                      valid_loss = v$item()))
  }
  opt$step()
}
