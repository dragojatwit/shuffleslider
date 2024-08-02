library(plumber)
library(dplyr)
library(class)
library(caret)
library(jsonlite)

# Load the trained model and training data
model_path <- "Project/data/trained_knn_model_new.RData"

if (file.exists(model_path)) {
  load(model_path)
  message("Model loaded successfully")
} else {
  stop("Trained model not found")
}

# Global variable to store the processed input song data
global_input_song_data <- NULL

# Function to preprocess input song data
preprocess_input_song <- function(song_data, numeric_features) {
  
  print("Initial song_data structure:")
  print(str(song_data))
  print("Column names:")
  print(colnames(song_data))
  
  # Check if numeric features exist in song_data
  missing_features <- setdiff(numeric_features, colnames(song_data))
  if (length(missing_features) > 0) {
    stop(paste("Missing numeric features:", paste(missing_features, collapse = ", ")))
  }
  
  # Scale numeric features
  song_data[numeric_features] <- scale(song_data[numeric_features])
  
  
  return(song_data)
}

# Function to recommend similar songs
recommend_songs <- function(input_song_data, k = 5) {
  numeric_features <- c('popularity', 'duration_ms', 'danceability', 'energy', 'loudness', 
                        'speechiness', 'acousticness', 'instrumentalness', 'liveness', 
                        'valence', 'tempo')
  
  input_song_data <- preprocess_input_song(input_song_data, numeric_features)
  
  
  
  neighbors <- knn(
    train = dplyr::select(train_data, -popularity), 
    test = dplyr::select(input_song_data, -popularity), 
    cl = train_data$popularity, 
    k = k
  )
  
  recommended_songs <- train_data[neighbors,]
  return(recommended_songs)
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
    print(paste("Raw body:", raw_body))
    
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
      tempo = body$tempo
    )
    
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
  
  recommendations <- recommend_songs(global_input_song_data)
  
  return(list(recommendations = recommendations))
}
