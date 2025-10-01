packages <- c("dplyr", "zoo", "ggplot2", "DBI", "RMySQL")  

installed <- packages %in% rownames(installed.packages())  
if (any(!installed)) {
  install.packages(packages[!installed])
}
    
                            # Data Connection and setup

# Load libraries
library(dplyr)    # for data manipulation
library(zoo)      # for moving average
library(ggplot2)  # for plots
library(DBI)
library(RMySQL)   # for connection to our database
library(reshape2)

# Database Connection
con <- dbConnect(RMySQL::MySQL(),
                 dbname = "crop_yield_project",
                 host = "localhost",
                 port = 3306,
                 user = "root",
                 password="Sneha@123")


# Data Loading
df <- dbReadTable(con, "crop_project_clean")

str(df)

                              # EDA(Exploratory data Analysis)

# Bar chart - Average yield by crop

ggplot(yearly_summary %>% group_by(Item) %>% summarise(mean_yield = mean(avg_yield, na.rm = TRUE)),
       aes(x = reorder(Item, -mean_yield), y = mean_yield, fill = Item)) +
  geom_bar(stat = "identity") +
  labs(title = "Average Yield by Crop", x = "Crop", y = "Average Yield (hg/ha)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), legend.position = "none")


# Top 5 crops by average yield
top5 <- yearly_summary %>%
  group_by(Item) %>%
  summarise(mean_yield = mean(avg_yield, na.rm = TRUE)) %>%
  top_n(5, mean_yield)

top5

# Aggregate data by Year and Item
yearly_summary_agg <- yearly_summary %>%
  filter(Item %in% top5$Item) %>%
  group_by(Year, Item) %>%
  summarise(yearly_avg = mean(avg_yield, na.rm = TRUE), .groups = "drop")

yearly_summary_agg

# Plot line chart
ggplot(yearly_summary_agg, aes(x = Year, y = yearly_avg, color = Item)) +
  geom_line(size = 1.2) +
  geom_point(size = 2, alpha = 0.7) +
  labs(title = "Yield Trends for Top 5 Crops",
       x = "Year", y = "Yield (hg/ha)") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "right",
        plot.title = element_text(face="bold"))

                                # Insights are:
# Potatoes have the highest yield and show strong growth over time.
# Sweet potatoes, cassava, and yams show steady improvement, with sweet potatoes rising fastest.
# Plantains remain relatively stable with slower growth, and by 2015 others start catching up.



# Latest year in dataset
latest_year <- max(yearly_summary$Year, na.rm = TRUE)

latest_year

# Get top 5 crops in the latest year with percentages
top5_latest <- yearly_summary %>%
  filter(Year == latest_year) %>%
  group_by(Item) %>%
  summarise(latest_yield = mean(avg_yield, na.rm = TRUE), .groups = "drop") %>%
  slice_max(latest_yield, n = 5) %>%
  mutate(percentage = round(100 * latest_yield / sum(latest_yield), 1),
         label = paste0(Item, " (", percentage, "%)"))

print(top5_latest)  # check values

# Donut chart
ggplot(top5_latest, aes(x = 2, y = latest_yield, fill = label)) +
  geom_col(width = 1, color = "white") +
  coord_polar(theta = "y") +
  xlim(0.5, 2.5) +  # makes it a donut (hollow center)
  labs(title = paste("Yield Share of Top 5 Crops in", latest_year)) +
  theme_void(base_size = 14) +
  theme(legend.position = "right",
        legend.title = element_blank(),
        plot.title = element_text(face = "bold", hjust = 0.5))



# Scatter plot with linear trend lines showing the relationship between rainfall and yield
ggplot(df, aes(x = avg_rainfall, y = avg_yield, color = Item)) +
  geom_point(alpha = 0.5) +
  geom_smooth(method = "lm", se = FALSE, color = "black") +
  labs(title = "Yield vs Rainfall by Crop",
       x = "Rainfall (mm)", y = "Yield (hg/ha)") +
  theme_minimal() +
  facet_wrap(~ Item, scales = "free_y")

                               # Insights are:
# (i) Maize/Wheat → too much rain hurts.
# (ii) Yams/Sorghum → more rain helps.
# (iii) Cassava/Soybeans → rain doesn’t matter much.
# (iv) Rainfall is only one factor → technology and management play huge roles in yield 
#      differences.


# Correlation Heatmap
yearly_summary <- yearly_summary %>% ungroup()
numeric_data <- yearly_summary %>%
  select(avg_yield, avg_rainfall, avg_temp, avg_pesticides) %>%
  mutate(across(everything(), ~as.numeric(as.character(.)))) %>%
  as.data.frame()

corr_matrix <- cor(numeric_data, use = "complete.obs")

melted_corr <- reshape2::melt(corr_matrix)

ggplot(melted_corr, aes(Var1, Var2, fill = value)) +
  geom_tile() +
  geom_text(aes(label = round(value, 2)), color = "black") +
  scale_fill_gradient2(low = "red", high = "green", mid = "white", midpoint = 0) +
  labs(title = "Correlation Heatmap") +
  theme_minimal()

                               # Inisghts are
# 1,Crop yield is not strongly correlated with rainfall, temperature, or pesticide usage in dataset.
# 2,Environmental factors (rainfall and temperature) are moderately related to each other, but they 
#   don’t clearly drive yield here.
# 3.This suggests that other hidden factors (like soil quality, farming techniques, or fertilizer 
#   use) might play a bigger role in yield.

str(df)

# Check the structure of your dataset
str(df)

# Convert crop/item column to factor if needed
df$Item <- as.factor(df$Item)

df$Item


# Split into train and test
set.seed(123)
train_index <- sample(1:nrow(df), 0.7 * nrow(df))
train_data <- df[train_index, ]
test_data  <- df[-train_index, ]


lm_model <- lm(avg_yield ~ avg_rainfall + avg_temp + avg_pesticides + Item, data = train_data)
summary(lm_model)

# Predict on test data
pred_lm <- predict(lm_model, test_data)
pred_lm

# Calculate RMSE
rmse_lm <- sqrt(mean((test_data$avg_yield - pred_lm)^2))
rmse_lm

plot(test_data$avg_yield, pred_lm,
     xlab = "Actual Yield",
     ylab = "Predicted Yield",
     main = "Predicted vs Actual Yield")
abline(0, 1, col = "red", lwd=4)  # 45-degree line

                                # Insights are
# 1. Model predicts low yields reasonably well:
#    Points for smaller yields are closer to the line.

# 2. Your model struggles for very high yields:
#    Points are more scattered above and below the line at higher yields.
#    Suggests some factors affecting high yields may not be fully captured.

# 3. Overall prediction:
#   The model gives a general trend (increasing predicted yield with increasing actual yield) but 
#   isn’t perfect.
#   RMSE (Root Mean Squared Error) can quantify this accuracy numerically.


residuals_lm <- test_data$avg_yield - pred_lm
plot(pred_lm, residuals_lm,
     xlab = "Predicted Yield",
     ylab = "Residuals",
     main = "Residuals vs Predicted")
abline(h = 0, col = "red", lwd=4)

model_log_lm <- lm(log(avg_yield) ~ avg_rainfall + avg_temp + avg_pesticides + Item, data = train_data)
model_log_lm

# Make predictions with the new model
pred_log_lm <- predict(model_log_lm, newdata = test_data)

#  Calculate the new residuals
# The actual values must also be on the log scale for a correct comparison
residuals_log_lm <- log(test_data$avg_yield) - pred_log_lm

#  Plot the new "Residuals vs Predicted" chart
plot(pred_log_lm, residuals_log_lm,
     xlab = "Predicted log(Yield)",
     ylab = "Residuals",
     main = "Residuals vs Predicted (After Log Transform)")
abline(h = 0, col = "red", lwd=4)


# Relationship between Rainfall and Yield
plot(train_data$avg_rainfall, train_data$avg_yield,
     xlab="Rainfall", ylab="Yield", main="Relationship between Rainfall and Yield")
abline(lm(avg_yield ~ avg_rainfall, data=train_data), col="red", lwd=4)

