# Load necessary libraries
library(readr)
library(class)
library(caret)
library(dplyr)

# Load the dataset
data = read.csv(sep = ",", header = TRUE, "C:\\Users\\koehlerd\\Desktop\\Classes\\Sem 2 Year 4\\Senior Project\\Datasets\\Metadata(1).csv")

# Preprocess the data
# Normalize numeric features
numeric_features <- c('popularity', 'followers', 'first_release', 'last_release', 'num_releases', 'num_tracks', 'monthly_listeners')
data[numeric_features] <- scale(data[numeric_features])

# Encode the 'genres' column
data$genres <- as.factor(data$genres)
data <- cbind(data, model.matrix(~ genres - 1, data = data))

# Remove original 'genres' column and 'ids' column
data <- data %>% select(-genres, -ids)

# Split the data into training and test sets
set.seed(123)
train_index <- createDataPartition(data$popularity, p = 0.8, list = FALSE)
train_data <- data[train_index,]
test_data <- data[-train_index,]

# Train the KNN model
knn_model <- train(
  popularity ~ ., 
  data = train_data, 
  method = 'knn', 
  tuneLength = 10,
  trControl = trainControl(method = 'cv')
)

# Function to preprocess input song data
preprocess_input_song <- function(song_data) {
  song_data[numeric_features] <- scale(song_data[numeric_features])
  song_data$genres <- as.factor(song_data$genres)
  genres_matrix <- model.matrix(~ genres - 1, data = song_data)
  song_data <- cbind(song_data, genres_matrix)
  song_data <- song_data %>% select(-genres, -ids)
  return(song_data)
}

# Function to recommend similar songs
recommend_songs <- function(input_song_data, k = 5) {
  input_song_data <- preprocess_input_song(input_song_data)
  
  neighbors <- knn(
    train = train_data %>% select(-popularity), 
    test = input_song_data %>% select(-popularity), 
    cl = train_data$popularity, 
    k = k
  )
  
  return(neighbors)
}

# Example usage: Create a data frame for the input song
input_song <- data.frame(
  ids = "new_song_id",
  names = "new_song_name",
  popularity = 50,
  followers = 200000,
  genres = "pop",
  first_release = 2020,
  last_release = 2023,
  num_releases = 5,
  num_tracks = 10,
  monthly_listeners = 500000
)

# Recommend similar songs to the input song
recommendations <- recommend_songs(input_song)
print(recommendations)
