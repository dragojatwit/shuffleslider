library(plumber)
library(dplyr)
library(class)
library(caret)
library(jsonlite)

# Load the trained model and training data
model_path <- "C:/Users/koehlerd/Desktop/Classes/Sem 2 Year 4/Senior Project/Datasets/trained_knn_model_new.RData"

if (file.exists(model_path)) {
  load(model_path)
  message("Model loaded successfully")
} else {
  stop("Trained model not found")
}

# Function to preprocess input song data
preprocess_input_song <- function(song_data, numeric_features) {
  song_data[numeric_features] <- scale(song_data[numeric_features])
  song_data$track_genre <- as.factor(song_data$track_genre)
  genres_matrix <- model.matrix(~ track_genre - 1, data = song_data)
  song_data <- cbind(song_data, genres_matrix)
  song_data <- dplyr::select(song_data, -c(track_id, artists, album_name, track_name, explicit, track_genre))
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

# Function to get song data from Spotify API (dummy function)
get_song_data_from_url <- function(url) {
  # Here you would add the code to fetch song data from the URL using Spotify API.
  # This is a dummy function returning hardcoded values for demonstration purposes.
  song_data <- data.frame(
    track_id = "new_track_id",
    artists = "new_artist",
    album_name = "new_album_name",
    track_name = "new_track_name",
    popularity = 50,
    duration_ms = 200000,
    danceability = 0.8,
    energy = 0.7,
    loudness = -5,
    speechiness = 0.05,
    acousticness = 0.1,
    instrumentalness = 0.0,
    liveness = 0.15,
    valence = 0.6,
    tempo = 120,
    track_genre = "pop"
  )
  return(song_data)
}

# Create the Plumber API object
pr <- plumber$new()

# CORS middleware
pr$filter("cors", function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(res$toResponse())
  } else {
    forward()
  }
})

#* @apiTitle Music Recommendation API
#* Recommend songs based on input song URL
#* @param url URL of the song
#* @get /recommend
function(url) {
  if (is.null(url) || url == "") {
    res$status <- 400
    return(list(error = "URL is required"))
  }
  
  song_data <- get_song_data_from_url(url)
  recommendations <- recommend_songs(song_data)
  
  return(list(recommendations = recommendations))
}

# Run the API
pr$run(port = 8000)
