# 05_train_network.R
# Train the network properly: loss curves, longer training, tuning.

library(ggplot2)

# Runs Step 4: loads the data, defines the functions, and trains for 5,000 rounds
source("r/04_network_scratch.R")

# ---- GLM benchmark (mean deviance per group, from Step 2) ----
glm_lines <- data.frame(set  = c("train", "valid"),
                        loss = c(0.9732633, 0.8629578))

# ---- Loss curve from the first run ----
loss_long <- rbind(
  data.frame(epoch = history$epoch, loss = history$train_loss, set = "train"),
  data.frame(epoch = history$epoch, loss = history$valid_loss, set = "valid")
)

p <- ggplot(loss_long, aes(x = epoch, y = loss, colour = set)) +
  geom_line(linewidth = 1) +
  geom_hline(data = glm_lines, aes(yintercept = loss, colour = set),
             linetype = "dashed") +
  scale_y_log10() +
  labs(title = "Network loss during training (5,000 rounds)",
       x = "Epoch", y = "Mean deviance per group (log scale)",
       colour = "Set", caption = "Dashed lines: GLM from Step 2")
p

dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/loss_curve_first_run.png", p, width = 8, height = 5, dpi = 150)

# ---- Fresh starting weights (same recipe and seed as Step 4) ----
init_params <- function(seed = 3130) {
  set.seed(seed)
  W1 <- matrix(rnorm(2 * n_hidden, sd = init_sd), nrow = 2, ncol = n_hidden)
  b1 <- rep(0, n_hidden)
  W2 <- matrix(rnorm(n_hidden, sd = init_sd), nrow = n_hidden, ncol = 1)
  b2 <- log(sum(train$y) / sum(train$exposure))
  list(W1 = W1, b1 = b1, W2 = W2, b2 = b2)
}

# ---- Training with early stopping ----
train_network <- function(learning_rate, max_epochs, eval_every = 100,
                          patience = 20, seed = 3130) {
  p    <- init_params(seed)
  best <- list(valid_loss = Inf, epoch = 0, params = p)
  history <- data.frame(epoch = integer(), train_loss = numeric(),
                        valid_loss = numeric())
  evals_since_best <- 0
  
  for (epoch in 0:max_epochs) {
    g <- backward(train$X, train$y, train$exposure, p$W1, p$b1, p$W2, p$b2)
    
    if (epoch %% eval_every == 0) {
      v <- mean_loss(valid$X, valid$y, valid$exposure, p$W1, p$b1, p$W2, p$b2)
      if (!is.finite(v)) break
      history <- rbind(history, data.frame(epoch = epoch,
                                           train_loss = g$loss,
                                           valid_loss = v))
      if (v < best$valid_loss) {
        best <- list(valid_loss = v, epoch = epoch, params = p)
        evals_since_best <- 0
      } else {
        evals_since_best <- evals_since_best + 1
      }
      if (evals_since_best >= patience) break
    }
    
    p$W1 <- p$W1 - learning_rate * g$dW1
    p$b1 <- p$b1 - learning_rate * g$db1
    p$W2 <- p$W2 - learning_rate * g$dW2
    p$b2 <- p$b2 - learning_rate * g$db2
  }
  list(best = best, history = history, stopped_at = epoch)
}

# ---- Run it ----
run1 <- train_network(learning_rate = 0.005, max_epochs = 50000)


# ---- Try several learning rates ----
rates <- c(0.002, 0.005, 0.01, 0.02, 0.05)
runs  <- list()

for (lr in rates) {
  runs[[as.character(lr)]] <- train_network(learning_rate = lr,
                                            max_epochs = 50000)
}

train_at_best <- function(r) {
  mean_loss(train$X, train$y, train$exposure,
            r$best$params$W1, r$best$params$b1,
            r$best$params$W2, r$best$params$b2)
}

lr_table <- data.frame(
  learning_rate = rates,
  best_epoch    = sapply(runs, function(r) r$best$epoch),
  stopped_at    = sapply(runs, function(r) r$stopped_at),
  best_valid    = sapply(runs, function(r) r$best$valid_loss),
  train_at_best = sapply(runs, train_at_best)
)
row.names(lr_table) <- NULL


# ---- Stability check: same network, different random starting weights ----
final_rate <- 0.005
seeds      <- c(3130, 1, 2, 3, 4)
seed_runs  <- list()

for (s in seeds) {
  seed_runs[[as.character(s)]] <- train_network(learning_rate = final_rate,
                                                max_epochs = 50000, seed = s)
}

seed_table <- data.frame(
  seed          = seeds,
  best_epoch    = sapply(seed_runs, function(r) r$best$epoch),
  stopped_at    = sapply(seed_runs, function(r) r$stopped_at),
  best_valid    = sapply(seed_runs, function(r) r$best$valid_loss),
  train_at_best = sapply(seed_runs, train_at_best)
)
row.names(seed_table) <- NULL
seed_table$valid_vs_glm <- seed_table$best_valid - 0.8629578


# ---- Seed 3 again, with a higher round cap ----
seed3_long <- train_network(learning_rate = final_rate,
                            max_epochs = 150000, seed = 3)


# ---- Update seed 3 with its longer run, and mark unfinished runs ----
seed_table$best_epoch[seed_table$seed == 3]    <- seed3_long$best$epoch
seed_table$stopped_at[seed_table$seed == 3]    <- seed3_long$stopped_at
seed_table$best_valid[seed_table$seed == 3]    <- seed3_long$best$valid_loss
seed_table$train_at_best[seed_table$seed == 3] <- train_at_best(seed3_long)
seed_table$valid_vs_glm <- seed_table$best_valid - 0.8629578
seed_table$finished     <- seed_table$best_epoch < seed_table$stopped_at

# ---- Save tables and the final network (seed 3130, learning rate 0.005) ----
dir.create("outputs", showWarnings = FALSE)
write.csv(lr_table,   "outputs/learning_rate_table.csv", row.names = FALSE)
write.csv(seed_table, "outputs/seed_table.csv",          row.names = FALSE)
saveRDS(run1$best$params, "outputs/final_weights.rds")
