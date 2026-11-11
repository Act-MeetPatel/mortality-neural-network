# 08_true_curve_comparison.R
# Compare the GLM and the network with the TRUE mortality that generated the data.
# Uses no test data.

source("r/04_network_scratch.R")   # data, forward(), and settings

# ---- True mortality: copied from the pricing project (02_simulate_deaths_exposure.R) ----
true_qx <- function(age, smoker, A = 0.00022, B = 0.0000027, C = 1.124,
                    smoker_multiplier = 2.5) {
  mu <- A + B * (C ^ age)
  mu <- ifelse(smoker == "Smoker", mu * smoker_multiplier, mu)
  1 - exp(-mu)
}

# ---- The two models, exactly as in Step 6 ----
train_df <- subset(data_all, split == "train")
glm_fit  <- glm(deaths ~ attained_age + smoker_status + offset(log(exposure)),
                family = poisson(link = "log"), data = train_df)
final    <- readRDS("outputs/final_weights.rds")

# ---- One table: every age and smoker group ----
grid <- expand.grid(attained_age  = 20:105,
                    smoker_status = c("Nonsmoker", "Smoker"),
                    stringsAsFactors = FALSE)
grid$exposure <- 1                       # so predicted deaths = rate

grid$True <- true_qx(grid$attained_age, grid$smoker_status)
grid$GLM  <- predict(glm_fit, newdata = grid, type = "response")

X_grid <- cbind(age    = grid$attained_age / age_scale,
                smoker = as.numeric(grid$smoker_status == "Smoker"))
grid$Network <- forward(X_grid, final$W1, final$b1, final$W2, final$b2)$rate

# ---- Exposure weights: where the policyholders actually are (train set only) ----
w <- aggregate(exposure ~ attained_age + smoker_status, data = train_df, FUN = sum)
names(w)[3] <- "w_exposure"

# Keep only age/smoker groups that have exposure (no extrapolated ages)
cmp <- merge(grid[, c("attained_age", "smoker_status", "True", "GLM", "Network")],
             w, by = c("attained_age", "smoker_status"))

cmp$band <- cut(cmp$attained_age, breaks = c(19, 39, 59, 79, 99, 105),
                labels = c("20-39", "40-59", "60-79", "80-99", "100-105"))

# ---- Poisson deviance between true expected deaths and each model's ----
dev_true <- function(mu_true, mu_model) {
  2 * (mu_true * log(mu_true / mu_model) - (mu_true - mu_model))
}

cmp$exp_true <- cmp$True    * cmp$w_exposure
cmp$exp_glm  <- cmp$GLM     * cmp$w_exposure
cmp$exp_net  <- cmp$Network * cmp$w_exposure
cmp$dev_glm  <- dev_true(cmp$exp_true, cmp$exp_glm)
cmp$dev_net  <- dev_true(cmp$exp_true, cmp$exp_net)

# ---- One row per age band ----
band_table <- aggregate(cbind(w_exposure, exp_true, exp_glm, exp_net,
                              dev_glm, dev_net) ~ band, data = cmp, FUN = sum)
band_table$glm_calib <- band_table$exp_glm / band_table$exp_true
band_table$net_calib <- band_table$exp_net / band_table$exp_true

# ---- Plots: truth vs both models (train-exposure groups only) ----
library(ggplot2)

keys <- cmp[, c("attained_age", "smoker_status", "w_exposure")]

rates_long <- rbind(
  data.frame(keys, model = "True",    rate = cmp$True),
  data.frame(keys, model = "GLM",     rate = cmp$GLM),
  data.frame(keys, model = "Network", rate = cmp$Network)
)
rates_long$model <- factor(rates_long$model, levels = c("True", "GLM", "Network"))

p_rates <- ggplot(rates_long, aes(attained_age, rate,
                                  colour = model, linetype = model)) +
  geom_line(linewidth = 0.9) +
  facet_wrap(~ smoker_status) +
  scale_y_log10() +
  labs(title = "True mortality vs GLM vs network",
       x = "Attained age", y = "One-year death probability (log scale)",
       colour = "Model", linetype = "Model")
p_rates

ratio_long <- rbind(
  data.frame(keys, model = "GLM",     ratio = cmp$GLM / cmp$True),
  data.frame(keys, model = "Network", ratio = cmp$Network / cmp$True)
)

p_ratio <- ggplot(ratio_long, aes(attained_age, ratio, colour = model)) +
  geom_hline(yintercept = 1, linetype = "dashed") +
  geom_line(linewidth = 0.7) +
  geom_point(aes(size = w_exposure), alpha = 0.5) +
  facet_wrap(~ smoker_status) +
  scale_y_log10() +
  labs(title = "Model rate divided by true rate (1 = exact)",
       x = "Attained age", y = "Ratio to truth (log scale)",
       colour = "Model", size = "Train exposure")
p_ratio

dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/true_vs_models_rates.png", p_rates, width = 9, height = 5, dpi = 150)
ggsave("outputs/true_vs_models_ratio.png", p_ratio, width = 9, height = 5, dpi = 150)

# ---- Level check: total predicted deaths vs truth and observed ----
vd <- subset(data_all, split == "valid")

level_check <- data.frame(
  set      = c("train", "valid"),
  observed = c(sum(train_df$deaths), sum(valid$y)),
  truth    = c(sum(cmp$exp_true),
               sum(true_qx(vd$attained_age, vd$smoker_status) * vd$exposure)),
  GLM      = c(sum(cmp$exp_glm),
               sum(predict(glm_fit, newdata = vd, type = "response"))),
  Network  = c(sum(cmp$exp_net),
               sum(forward(valid$X, final$W1, final$b1,
                           final$W2, final$b2)$rate * valid$exposure))
)

g_final <- backward(train$X, train$y, train$exposure,
                    final$W1, final$b1, final$W2, final$b2)

write.csv(band_table,  "outputs/band_table.csv",  row.names = FALSE)
write.csv(level_check, "outputs/level_check.csv", row.names = FALSE)
