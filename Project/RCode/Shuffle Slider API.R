library(plumber)
library(dplyr)
library(class)
library(caret)
library(jsonlite)

# Load the trained model and training data
model_path <- "Project/data/NeWTeSTInGMoDel.RData"

if (file.exists(model_path)) {
  load(model_path)
  message("Model loaded successfully")
} else {
  stop("Trained model not found")
}

#Load the csv file

dataset_5k <- read.csv("Project/data/dataset(5k).csv", sep = ",", header = TRUE)


# Global variable to store the processed input song data
global_input_song_data <- NULL

global_input_track_id <- NULL

# Preprocess the csv data
preprocess_data <- function(data) {
  # Define the numeric features to be used
  numeric_features <- c('popularity', 'duration_ms', 'danceability', 'energy', 'loudness', 
                        'speechiness', 'acousticness', 'instrumentalness', 'liveness', 
                        'valence', 'tempo')
  
  # Select only the required numeric features and the track_id
  data <- data %>% select(track_id, all_of(numeric_features))
  
  # Scale the numeric features
  data[numeric_features] <- scale(data[numeric_features])
  
  return(data)
}

processed_data <- preprocess_data(dataset_5k)

# Split the data into training and test sets, retaining track_id separately
set.seed(123)
message("Splitting data")
train_index <- createDataPartition(processed_data$popularity, p = 0.8, list = FALSE)
train_data <- processed_data[train_index,]
test_data <- processed_data[-train_index,]

#separate track id for test
test_track_id <- test_data$track_id
test_data <- test_data %>% select(-track_id)

print("all vars")
print(ls())
print("class of model")
print(class(knn_model))


# Function to make predictions and include track_id
make_predictions <- function(model, new_data, track_ids) {
  #new_data <- rbind(new_data, as.data.frame(global_input_song_data, stringsAsFactors = FALSE))
  predictions <- predict(model, newdata = new_data)
  result <- data.frame(track_id = track_ids, predicted_popularity = predictions)
  return(result)
}

# Function to preprocess input song data
preprocess_input_song <- function(song_data, numeric_features) {
  # Check if numeric features exist in song_data
  missing_features <- setdiff(numeric_features, colnames(song_data))
  if (length(missing_features) > 0) {
    stop(paste("Missing numeric features:", paste(missing_features, collapse = ", ")))
  }
  
  # Replace infinite values with NA
  song_data[sapply(song_data[numeric_features], is.infinite)] <- NA
  
  # Impute missing values with the mean of each column
  if (any(is.na(song_data[numeric_features]))) {
    warning("Input song data contains missing values. Imputing missing values with mean.")
    song_data[numeric_features] <- lapply(song_data[numeric_features], function(x) {
      if (is.numeric(x)) {
        # Impute missing values with the mean of each column
        x[is.na(x)] <- mean(x, na.rm = TRUE)
      }
      return(x)
    })
  }
  
  # Check for zero variance in numeric features
  variances <- sapply(song_data[numeric_features], sd, na.rm = TRUE)
  zero_variance_features <- names(variances)[variances == 0]
  if (length(zero_variance_features) > 0) {
    warning(paste("Features with zero variance detected:", paste(zero_variance_features, collapse = ", ")))
  }
  
  # Print processed data to check for NaN values
  print("Preprocessed song data before scaling:")
  print(song_data)
  
  # Scale numeric features
  song_data[numeric_features] <- scale(song_data[numeric_features])
  
  # Print processed data to check for NaN values
  print("Preprocessed song data after scaling:")
  print(song_data)
  
  return(song_data)
}




# Create the Plumber API object
pr <- plumber$new()
options("plumber.port" = 5555)

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  
  # Handle preflight requests
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  
  plumber::forward()
}

#* @post /process
#* @param the songdata sent in the request
function(req) {
  tryCatch({
    raw_body <- req$postBody
    #print(paste("Raw body:", raw_body))
    
    # Parse JSON body
    body <- jsonlite::fromJSON(raw_body)
    
    # Ensure body contains all necessary fields
    required_fields <- c("popularity", "duration_ms", "danceability", "energy", "loudness", 
                         "speechiness", "acousticness", "instrumentalness", "liveness", 
                         "valence", "tempo")
    missing_fields <- setdiff(required_fields, names(body))
    if (length(missing_fields) > 0) {
      stop(paste("Missing fields in request body:", paste(missing_fields, collapse = ", ")))
    }
    
    song_data <- data.frame(
      popularity = body$popularity,
      duration_ms = body$duration_ms,
      danceability = body$danceability,
      energy = body$energy,
      loudness = body$loudness,
      speechiness = body$speechiness,
      acousticness = body$acousticness,
      instrumentalness = body$instrumentalness,
      liveness = body$liveness,
      valence = body$valence,
      tempo = body$tempo,
      stringsAsFactors = FALSE
    )
    
    global_input_track_id <<- body$id
    
    # Store the processed song data globally
    global_input_song_data <<- song_data
    
    return(list(message = "Song data processed successfully"))
  }, error = function(e) {
    # Handle errors
    message <- paste("Error:", e$message)
    print(message) # Print error message to the log
    return(list(error = message))
  })
}

#* @apiTitle Music Recommendation API
#* Recommend songs based on stored input song data
#* @get /recommend
#* @serializer json
function() {
  if (is.null(global_input_song_data)) {
    return(list(error = "No song data available. Please POST song data first."))
  }
  print("global input data:")
  print(global_input_song_data)
  
  # Preprocess global_input_song_data
  input_song_data <- preprocess_input_song(global_input_song_data, c('popularity', 'duration_ms', 'danceability', 'energy', 'loudness', 
                                                                     'speechiness', 'acousticness', 'instrumentalness', 'liveness', 
                                                                     'valence', 'tempo'))
  
  print("preprocessed input data:")
  print(input_song_data)
  
  # Combine the input song data with the test data
  combined_test_data <- rbind(test_data, input_song_data)
  
  # Combine track IDs
  combined_track_ids <- c(test_track_id, global_input_track_id)
  
  print(input_song_data)
  
  predictions <- make_predictions(knn_model, combined_test_data, test_track_id)

  write.csv(predictions, "Project/data/writtenOutput.csv", row.names = FALSE)
  
  df <- read.csv("Project/data/writtenOutput.csv")
  
  
  
  # Generate a random row index between 1 and 999
  random_index <- sample(1:999, 1)
  
  # Extract the random row
  random_row <- df[random_index, ]
  
  # Convert the first row to a list
  row_list <- as.list(random_row)
  
  # Convert the list to JSON
  json_body <- toJSON(row_list, pretty = TRUE)
  
  print("recommendations: ")
  print(json_body)
  return(list(json_body = json_body))
}
