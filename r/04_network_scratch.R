# 04_network_scratch.R
# Neural network from scratch:
# 2 inputs -> 8 tanh hidden neurons -> 1 output neuron with exp()

# ---- Settings ----
age_scale <- 100
n_hidden  <- 8

# ---- Load data ----
data_all <- read.csv("data/grouped_exposure_deaths.csv")

make_inputs <- function(d) {
  list(
    X        = cbind(age    = d$attained_age / age_scale,
                     smoker = as.numeric(d$smoker_status == "Smoker")),
    y        = d$deaths,
    exposure = d$exposure
  )
}

train <- make_inputs(subset(data_all, split == "train"))
valid <- make_inputs(subset(data_all, split == "valid"))
test  <- make_inputs(subset(data_all, split == "test"))


# ---- Starting weights ----
init_sd <- 0.5

set.seed(3130)
W1 <- matrix(rnorm(2 * n_hidden, sd = init_sd), nrow = 2, ncol = n_hidden)
b1 <- rep(0, n_hidden)
W2 <- matrix(rnorm(n_hidden, sd = init_sd), nrow = n_hidden, ncol = 1)
b2 <- log(sum(train$y) / sum(train$exposure))


# ---- Forward pass: inputs -> hidden layer -> output rate ----
forward <- function(X, W1, b1, W2, b2) {
  Z1   <- sweep(X %*% W1, 2, b1, "+")   # hidden neurons: multiply and add
  H    <- tanh(Z1)                      # hidden neurons: squish
  z2   <- as.vector(H %*% W2) + b2      # output neuron: multiply and add
  rate <- exp(z2)                       # output neuron: squish
  list(Z1 = Z1, H = H, z2 = z2, rate = rate)
}

# ---- Loss: Poisson deviance (same as Step 2) ----
poisson_deviance <- function(y, mu) {
  term <- ifelse(y == 0, 0, y * log(y / mu))
  2 * sum(term - (y - mu))
}


# ---- Backward pass: slope of the mean loss for every parameter ----
backward <- function(X, y, exposure, W1, b1, W2, b2) {
  n   <- nrow(X)
  out <- forward(X, W1, b1, W2, b2)
  mu  <- out$rate * exposure
  
  g   <- matrix(2 * (mu - y), ncol = 1)   # slope at the output, one per group
  dW2 <- t(out$H) %*% g / n
  db2 <- sum(g) / n
  dH  <- g %*% t(W2)                      # blame on each hidden output
  dZ1 <- dH * (1 - out$H^2)               # pushed back through the tanh
  dW1 <- t(X) %*% dZ1 / n
  db1 <- colSums(dZ1) / n
  
  list(dW1 = dW1, db1 = db1, dW2 = dW2, db2 = db2,
       loss = poisson_deviance(y, mu) / n)
}


# ---- Numerical check of the slopes ----
mean_loss <- function(X, y, exposure, W1, b1, W2, b2) {
  mu <- forward(X, W1, b1, W2, b2)$rate * exposure
  poisson_deviance(y, mu) / nrow(X)
}

check_gradients <- function(X, y, exposure, W1, b1, W2, b2, eps = 1e-5) {
  params  <- list(W1 = W1, b1 = b1, W2 = W2, b2 = b2)
  loss_of <- function(p) mean_loss(X, y, exposure, p$W1, p$b1, p$W2, p$b2)
  slopes  <- lapply(params, function(m) m * 0)
  
  for (nm in names(params)) {
    for (i in seq_along(params[[nm]])) {
      up   <- params
      down <- params
      up[[nm]][i]   <- up[[nm]][i] + eps
      down[[nm]][i] <- down[[nm]][i] - eps
      slopes[[nm]][i] <- (loss_of(up) - loss_of(down)) / (2 * eps)
    }
  }
  slopes
}


# ---- Training loop (full-batch gradient descent) ----
learning_rate <- 0.005
n_epochs      <- 5000
log_every     <- 250

history <- data.frame(epoch = integer(), train_loss = numeric(),
                      valid_loss = numeric())

for (epoch in 0:n_epochs) {
  grads <- backward(train$X, train$y, train$exposure, W1, b1, W2, b2)
  
  if (epoch %% log_every == 0) {
    valid_loss <- mean_loss(valid$X, valid$y, valid$exposure, W1, b1, W2, b2)
    history <- rbind(history, data.frame(epoch      = epoch,
                                         train_loss = grads$loss,
                                         valid_loss = valid_loss))
  }
  
  W1 <- W1 - learning_rate * grads$dW1
  b1 <- b1 - learning_rate * grads$db1
  W2 <- W2 - learning_rate * grads$dW2
  b2 <- b2 - learning_rate * grads$db2
}
