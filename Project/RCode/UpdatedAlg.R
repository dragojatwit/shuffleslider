# Load necessary libraries
library(readr)
library(caret)
library(dplyr)

# Load the new dataset
message("Starting data insertion")
data <- read.csv("C:/Users/david/OneDrive/Desktop/project/data/dataset(5k).csv", sep = ",", header = TRUE)
message("Data insertion completed")

# Preprocess the data
preprocess_data <- function(data) {
  numeric_features <- c('popularity', 'duration_ms', 'danceability', 'energy', 'loudness', 
                        'speechiness', 'acousticness', 'instrumentalness', 'liveness', 
                        'valence', 'tempo')
  data[numeric_features] <- scale(data[numeric_features])
  
  data$track_genre <- as.factor(data$track_genre)
  data <- cbind(data, model.matrix(~ track_genre - 1, data = data))
  
  # Select the columns that exist in the dataset
  data <- dplyr::select(data, -c(track_id, artists, album_name, track_name, explicit, track_genre))
  return(data)
}
message("Starting data preprocessing")
data <- preprocess_data(data)
message("Data preprocessing complete")

# Split the data into training and test sets
set.seed(123)
message("Splitting data")
train_index <- createDataPartition(data$popularity, p = 0.8, list = FALSE)
train_data <- data[train_index,]
test_data <- data[-train_index,]
message("Data split complete")

# Train the KNN model
train_knn_model <- function(train_data) {
  knn_model <- train(
    popularity ~ ., 
    data = train_data, 
    method = 'knn', 
    tuneLength = 1,  # Reduce tuning length for simplicity
    trControl = trainControl(method = 'cv')
  )
  return(knn_model)
}
message("Training KNN model")

knn_model <- train_knn_model(train_data)
message("KNN model trained")

# Save the trained model and the training data
message("Saving model")
save(knn_model, train_data, file = "C:/Users/david/OneDrive/Desktop/project/data/trained_knn_model_new.RData")
message("Model saved")
