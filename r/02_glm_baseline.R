# 02_glm_baseline.R
# Poisson GLM baseline: deaths ~ age + smoker, with exposure as offset.

# ---- Load and split ----
data_all <- read.csv("data/grouped_exposure_deaths.csv")
train <- subset(data_all, split == "train")
valid <- subset(data_all, split == "valid")
test  <- subset(data_all, split == "test")

# ---- Fit the GLM on train only ----
glm_fit <- glm(deaths ~ attained_age + smoker_status + offset(log(exposure)),
               family = poisson(link = "log"),
               data   = train)
summary(glm_fit)


# ---- Poisson deviance (the loss we compare models with) ----
poisson_deviance <- function(y, mu) {
  term <- ifelse(y == 0, 0, y * log(y / mu))
  2 * sum(term - (y - mu))
}

# ---- Predicted deaths for each set ----
mu_train <- predict(glm_fit, newdata = train, type = "response")
mu_valid <- predict(glm_fit, newdata = valid, type = "response")
mu_test  <- predict(glm_fit, newdata = test,  type = "response")

# ---- Score table ----
results <- data.frame(
  set  = c("train", "valid", "test"),
  rows = c(nrow(train), nrow(valid), nrow(test)),
  total_deviance = c(poisson_deviance(train$deaths, mu_train),
                     poisson_deviance(valid$deaths, mu_valid),
                     poisson_deviance(test$deaths,  mu_test))
)
results$mean_deviance <- results$total_deviance / results$rows
results


# ---- Plot: observed vs GLM rates (train only) ----
library(ggplot2)

train$observed_rate <- train$deaths / train$exposure
train$glm_rate      <- mu_train / train$exposure

sum(train$deaths == 0)                  # groups that can't show on a log axis
plot_data <- subset(train, deaths > 0)

p <- ggplot(plot_data, aes(x = attained_age)) +
  geom_point(aes(y = observed_rate, colour = smoker_status), alpha = 0.6) +
  geom_line(aes(y = glm_rate, colour = smoker_status), linewidth = 1) +
  scale_y_log10() +
  labs(title = "Poisson GLM vs observed mortality (train set)",
       x = "Attained age", y = "Death rate (log scale)",
       colour = "Smoker status")
p

dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/glm_fit_train.png", p, width = 8, height = 5, dpi = 150)
