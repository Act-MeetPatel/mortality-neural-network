# 06_test_evaluation.R
# Final exam: GLM vs network on the sealed test set.

# Loads the data and defines forward(), mean_loss(), poisson_deviance().
# (It also reruns the Step 4 training, which only takes seconds.)
source("r/04_network_scratch.R")

# ---- GLM, refit on train only (same as Step 2) ----
train_df <- subset(data_all, split == "train")
valid_df <- subset(data_all, split == "valid")

glm_fit <- glm(deaths ~ attained_age + smoker_status + offset(log(exposure)),
               family = poisson(link = "log"),
               data   = train_df)

# ---- Final network from Step 5 ----
final <- readRDS("outputs/final_weights.rds")

# ---- Scoring helpers: mean deviance per group ----
score_glm <- function(d) {
  mu <- predict(glm_fit, newdata = d, type = "response")
  poisson_deviance(d$deaths, mu) / nrow(d)
}

score_net <- function(s) {
  mean_loss(s$X, s$y, s$exposure, final$W1, final$b1, final$W2, final$b2)
}

# ---- THE TEST EXAM ----
test_df <- subset(data_all, split == "test")

glm_test <- score_glm(test_df)
net_test <- score_net(test)

test_results <- data.frame(
  model          = c("GLM", "Network"),
  mean_deviance  = c(glm_test, net_test),
  total_deviance = c(glm_test, net_test) * nrow(test_df)
)

# ---- Plot: fitted curves from both models, with observed test rates ----
library(ggplot2)

# Fitted curves on an age grid, for both smoker groups
grid <- expand.grid(attained_age  = 20:105,
                    smoker_status = c("Nonsmoker", "Smoker"),
                    stringsAsFactors = FALSE)
grid$exposure <- 1                      # so predicted deaths = rate

grid$GLM <- predict(glm_fit, newdata = grid, type = "response")

X_grid <- cbind(age    = grid$attained_age / age_scale,
                smoker = as.numeric(grid$smoker_status == "Smoker"))
grid$Network <- forward(X_grid, final$W1, final$b1, final$W2, final$b2)$rate

curves <- rbind(
  data.frame(attained_age = grid$attained_age, smoker_status = grid$smoker_status,
             model = "GLM",     rate = grid$GLM),
  data.frame(attained_age = grid$attained_age, smoker_status = grid$smoker_status,
             model = "Network", rate = grid$Network)
)

# Observed test rates (groups with zero deaths can't show on a log axis)
test_df$observed_rate <- test_df$deaths / test_df$exposure


test_points <- subset(test_df, deaths > 0)

p_test <- ggplot() +
  geom_point(data = test_points,
             aes(x = attained_age, y = observed_rate, colour = smoker_status),
             alpha = 0.5) +
  geom_line(data = curves,
            aes(x = attained_age, y = rate, colour = smoker_status,
                linetype = model),
            linewidth = 0.9) +
  scale_y_log10() +
  labs(title = "GLM vs network on the test set",
       x = "Attained age", y = "Death rate (log scale)",
       colour = "Smoker status", linetype = "Model")
p_test

ggsave("outputs/test_fit_glm_vs_network.png", p_test,
       width = 8, height = 5, dpi = 150)
