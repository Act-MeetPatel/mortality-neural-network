# 03_one_neuron.R
# One neuron, by hand.

# ---- Inputs for one group (made-up example) ----
age      <- 40
smoker   <- 0        # 1 = smoker, 0 = nonsmoker
exposure <- 1000     # exposure years

# ---- Settings ----
age_scale <- 100     # age is divided by this to keep inputs small

x <- c(age / age_scale, smoker)

# ---- Weights and bias (made up, not learned) ----
w <- c(2.0, 1.5)
b <- -3.0

# ---- Forward pass ----
z                <- sum(w * x) + b
rate             <- exp(z)
predicted_deaths <- rate * exposure


# ---- A real group: age 40 nonsmokers in the train set ----
data_all <- read.csv("data/grouped_exposure_deaths.csv")
row <- subset(data_all, split == "train" & attained_age == 40 &
                smoker_status == "Nonsmoker")

# ---- Loss: Poisson deviance ----
poisson_deviance <- function(y, mu) {
  term <- ifelse(y == 0, 0, y * log(y / mu))
  2 * sum(term - (y - mu))
}

mu <- rate * row$exposure          # predicted deaths for this group


# ---- Gradient: how the loss changes if we nudge each parameter ----
y      <- row$deaths
grad_z <- 2 * (mu - y)
grad_w <- grad_z * x
grad_b <- grad_z

# ---- One gradient descent step ----
learning_rate <- 0.01
w_new <- w - learning_rate * grad_w
b_new <- b - learning_rate * grad_b

z_new  <- sum(w_new * x) + b_new
mu_new <- exp(z_new) * row$exposure
poisson_deviance(y, mu_new)


# ---- Repeat the step many times on this one group ----
n_steps <- 100
w_run   <- w
b_run   <- b
history <- data.frame(step = 0:n_steps, predicted = NA, deviance = NA)

for (i in 0:n_steps) {
  z_run  <- sum(w_run * x) + b_run
  mu_run <- exp(z_run) * row$exposure
  history$predicted[i + 1] <- mu_run
  history$deviance[i + 1]  <- poisson_deviance(y, mu_run)
  
  grad_z <- 2 * (mu_run - y)
  w_run  <- w_run - learning_rate * grad_z * x
  b_run  <- b_run - learning_rate * grad_z
}

history[c(1, 2, 3, 4, 6, 11, 21, 51, 101), ]

