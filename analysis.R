########### DataCamp exam project, July 2025,Stojkovic ########### 
rm(list = ls())
#### libraries #### 
library(naniar); library(dplyr); library(forcats); 
library(simputation); library(ggplot2)

#### Import data #### 
mydata <- read.csv("product_sales.csv")

#### Tidy and Validate the Data #### 

## (I) Determine potential issues
miss_var_summary(mydata)
glimpse(mydata)
summary(mydata)

nrow(mydata)
# At first look, the summary flags two issues (a) 1074 NAs in the revenue var which should be dealt with, 
# (b) at least one error/outline in "years_as_customer" (has value 63 which is impossible given that the company exists for only 41 years)

# Check specifically for customers claiming loyalty longer than company's existence (39 years)
mydata %>% filter(years_as_customer > 39) # ok, there are two of them: 63 and 47 years as customers allegedly

# Check for unique values in character data
unique(mydata$sales_method) # "Email" and "Email + Call" appear in two versions, need to be subsumed under one category respectively, so this is (c) third problem
unique(mydata$state) # This looks good

# Check customer_id for duplicates
mydata %>% count(customer_id) %>% 
  filter(n>1) # good, there are no duplicates in customer_id

# so issues in three vars are found: years_as_customer, sales_method, revenue



## (II) Elevate issues with variables

# (1) Identify years_as_customer with apparent typos
mydata[ mydata$years_as_customer %in% c(63, 47), ]
which(mydata$years_as_customer == 63 | mydata$years_as_customer == 47)
#mydata2 <- mydata[c(-13742, -13801), ]

# rather than removing two entire rows due to a typo in years, I will just make them NAs (for now)
mydata <- mydata %>% 
  mutate(
    years_customer_clean = ifelse(years_as_customer %in% c(63, 47), NA, years_as_customer)
  )

summary(mydata$years_as_customer)
summary(mydata$years_customer_clean)




# (2) sales_method: merge the levels of sales_method that belong together

mydata$sales_method <- as.factor(mydata$sales_method) # I convert to a factor, simpler for the analysis and category levels are explicit
summary(mydata$sales_method)

Email_cat <- c("email", "Email")
Email_Call_cat <- c("em + call", "Email + Call")
Call_cat <- "Call"

mydata <- mydata %>%
  mutate(sales_method_clean = fct_collapse(sales_method, 
                                              Email = Email_cat,
                                              "Email + Call" = Email_Call_cat,
                                              Call = Call_cat)) 

summary(mydata$sales_method)
summary(mydata$sales_method_clean)
sum(table(mydata$sales_method_clean))  # all there, sum of categories equals the number of obs



# (3) revenue: impute median for NAs in revenue, based on sales_method var
# Note: I decide to go with imputing rather then dropping those observations because (a) I have information about nb_sold and (b) I have information about 93% of rows for revenue, so enough to estimate means fairly reliably and keep the data

# Before I proceed with imputation, i check the distribution of NAs per sales_method category
is_na_rev <- is.na(mydata$revenue)
prop.table(table(mydata$sales_method_clean, is_na_rev), margin = 1)

# Impute median, but keep the initial/raw data in the 'revenue_raw' variable
mydata <- mydata %>%
  mutate(revenue_raw = revenue) %>%
  impute_median(revenue ~ sales_method_clean)

# Check if the revenue var with and without NA differs, e.g., if mean differs
mydata %>% group_by(sales_method_clean) %>% 
  summarize(avg = mean(revenue_raw, na.rm = T),
            avg2 = mean(revenue)) # AVGs are nearly identical, so I will stick to revenue with imputed medians per sales category



#### Analysis #### 
### I will break down the analysis based on questions from the email/instruction sheet

## (1) "How many customers were there for each approach?" NOTE: "approach" is here sales method - email, vs call vs both

ggplot(mydata, aes(sales_method_clean)) +
  geom_bar() +
  geom_text(stat = "count", aes(label = ..count..), vjust = -0.5) +
  xlab("Sales Method") +
  ggtitle("Figure 1. Deals per Sales Method") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0))

table(mydata$sales_method_clean) # simple and quick count per category level
# Answer to question 1: 4962 customers for Call, 2572 for Email+Call, 7466 for Email 
# END of answering question 1.

## (2a) "What does the spread of the revenue look like overall?"
## (2b) "And for each method?"



summary(mydata$revenue) # simple and quick overview of the key summary stats

# Show the visual distribution for 2a
ggplot(mydata, aes(x = revenue)) +
  geom_histogram(bins = 30, fill = "grey80", color = "black") +
  xlab("Revenue ($)") +
  ggtitle("Figure 2. The Distribution of Revenue") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0))

# Answer to 2a: 
# Overall, the revenue spans broadly from 32.54 to 238.32 dollars. The interquartile range (IQR), i.e., the middle 50% of all revenue data points, is about 55 dollars. Given that this covers 27% of the full range of this variable, I can conclude that the spread/variability is quite substantial.  
# This is a multimodal distribution, with data clustering around three points: around 30-50, around 80-100 and 180-190 (with a smaller bump around 230).
# Most data points are concentrated on the left-hand side, with a long right tail (a few observations stretching even beyond 200 dollars).
# END of answering 2a.


# Deal with 2b now:
mydata %>%
  group_by(sales_method_clean) %>%
  summarise(
    n        = n(),
    n_missing= sum(is.na(revenue)),
    min      = min(revenue, na.rm = TRUE),
    q1       = quantile(revenue, 0.25, na.rm = TRUE),
    median   = median(revenue, na.rm = TRUE),
    mean     = mean(revenue, na.rm = TRUE),
    q3       = quantile(revenue, 0.75, na.rm = TRUE),
    max      = max(revenue, na.rm = TRUE),
    IQR      = q3 - q1
  )

# Plot the distributions per sales method: histogram
ggplot(mydata, aes(revenue, fill = as.factor(sales_method_clean))) +
  geom_histogram(bins = 30, color = "black") +
  xlab("Revenue ($)") +
  labs(fill = "Sales method") +
  ggtitle("Figure 3. The Distribution of Revenue per Sales Method") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0))

# Another look: box plot
ggplot(mydata, aes(revenue, sales_method_clean)) +
  geom_boxplot() +
  labs(x = "Revenue ($)", y = "Sales Method") +
  ggtitle("Figure 4. Differences in Revenue Ranges between Sales Methods") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0))

# Answer to 2b:
# Sales strategy Call: revenue goes from roughly 32 to 71, with the mean of 48. Interquartile range is 11, suggesting a fairly tight variability. There are only a few big outliers on the higher end.
  # The sales method brings modest and predictable revenue, i.e., it very rarely surprises with huge or tiny deals.
# Sales strategy Email: revenue goes from roughly 79 to 149, with the mean of 97. Interquartile range is roughly 16, moderately wider than the Call. This still suggests a fairly tight variability. 
  # On average, Email as a sales method boosts revenue compared to the Call. Additionally, the Email method has also brought a handful of very large deals/revenue inflows.
# Sales strategy Email+Call: revenue goes from 122 to 238, with the mean of 184. Interquartile range (13) still shows a fairly tight spread
  # On average, the Email+Call substantially outperforms the other two. It nearly doubles Email revenue and almost quadruples Call revenue. It is also noticeable that the Email+Call method has a handful of very small and very large deals, i.e., those that are beyond the 1.5×IQR rule. This means that the Email+Call method occasionally both under- and outperforms by a wide margin relative to its mean revenue.
# END of answering 2b.


## (3) "Was there any difference in revenue over time for each of the methods?"

# Plot weekly trends
avg_weekly <- mydata %>%
                group_by(week, sales_method_clean) %>%
                summarise(avg_revenue = mean(revenue, na.rm = TRUE))

ggplot(avg_weekly, aes(week, avg_revenue, linetype = sales_method_clean)) +
  geom_line(size = 1) +
  scale_x_continuous(breaks = 1:6) +
  scale_linetype_manual(values = c(
    "Email + Call"= "dotted",
    "Email"       = "solid",
    "Call"        = "twodash"
  )) +
  labs(
    title = "Figure 5. Average Revenue by Sales Method (Week 1–6)",
    x = "Project Week",
    y = "Average Revenue ($)",
    linetype = "Sales Method"
  ) +
  theme_minimal()


# Answer to Question 3: 
# All three sales methods bring in steadily increasing revenue over six weeks (with only a small dip between Weeks 2 and 3). There are no substantial oscillations. 
# It is noticeable, however, that the Email+Call method increases revenue more sharply than the other two methods over time.
# Call rises from about $35 to $65 (+$30).  
# Email grows from $95 to $129 (+$34).  
# Email+Call jumps from $135 to $225 (+$90).
# Conclusion: The Email+Call method not only starts and ends at the highest levels, it also posts the largest absolute gain, demonstrating that its combination of a quick email plus a brief (10‑minute) call continues to pay off more and more as the campaign proceeds.
# END of answering question 3.



## (4) "Based on the data, which method would you recommend we continue to use?"

anova_res <- aov(revenue ~ sales_method_clean, data = mydata)
summary(anova_res)

TukeyHSD(anova_res)

mydata %>% 
  group_by(sales_method_clean) %>% 
  summarize(avg_rev = mean(revenue)) %>%
  aov(avg_rev~sales_method_clean)
              
            
??aov
## Answer to question 4:
# Based on time investments and revenue outcomes:
# Call only: on avg brings in 47.7$ in revenue, costs ~30 min/customer, that is 1.6$ revenue per minute. This is the lowest yield and the method that costs the most time.
# Email only: on avg brings in 97$ in revenue, costs ~0-5 min/customer, that is 19$ revenue per minute (assumed 2.5 min/email). Very high return on investment and almost no hands-on effort.
# Email+Call: on avg brings in 184$ in revenue, costs ~10 min/customer, that is 18.4$ revenue per minute. Highest revenue and very strong return on investment on time.
## KEY RECOMMENDATIONS: 
# (a) Drop or de-prioritize "the Call only" method. It is the least efficient. A person spends six times as long for less than half the revenue of Email alone.
# (b) Keep "Email only" as the default method. Two quick emails drive nearly 100$ in revenue and require minimal effort.
# (c) Reserve "Email+Call" for high-potential deals. A single 10-min call on top of an email doubles Email-only revenue. It is almost as time-efficient as Email but can capture significantly better deals.

## A METRIC FOR MONITORING:
# I hinted above the Revenue-Per-Minute Efficiency. I would suggest the team to follow this indicator in the future
# Metric definition: Revenue-Per-Minute (RPM)=Average Revenue Per Customer/Average Team Time per Customer (minutes).
# How to use it: Each week (or month), re‑compute RPM for each method (or for Email and Email+Call only, if the Call only is dropped) using the same formula, to re-assess if the profitability of the approach-keep Email as default and Email+Call for high potential deals.
  # Plot the three lines over time—if Email+Call starts to dip below Email‑only in efficiency, reconsider resource allocation.
  # Set an internal target (e.g., maintain RPM ≥18$/min for Email+Call) and trigger a review if it falls more than 10% below baseline.
## END of answering question 4.
## END of metric recommendations.



## (5) "Any other differences between the customers in each group...?"
glimpse(mydata)  

# per-group avg on other variables
mydata %>% 
  group_by(sales_method_clean) %>% 
  summarise(avg_visits = mean(nb_site_visits),
            avg_sold = mean(nb_sold),
            avg_years = mean(years_as_customer))


# check where the customers come most (and least) from
mydata %>%
  count(sales_method_clean, state) %>%
  group_by(sales_method_clean) %>%
  summarise(
    top_state    = state[which.max(n)],
    top_count    = max(n),
    bottom_state = state[which.min(n)],
    bottom_count = min(n)
  ) # CA top for all three, bottom differs

  
## Answer to Question 5:
# The Email+Call customers visit the site slightly more often (avg 26.8 visits) and purchase more items (avg 12.2 items) than the other two groups.
# The Call‑only customers have been with the company slightly longer on average (5.18 years) but generate fewer visits (24.4) and items purchased (9.51).
# The Email-only customers sit in between both based on the number of items purchased (9.73) and average years as customers (4.98).
# Lastly, most customers for all three sales methods come from California: 921 Email, 642 Call and 309 Email+Call. The fewest customers come from North Dakota for Call (7), Vermont for Email (11), and Montana for Email+Call (4).
# END of answering Question 5.
