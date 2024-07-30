# Load necessary libraries
library(plumber)
library(dplyr)
library(class)
library(caret)

# Load the trained model and training data
model_path <- "C:/Users/david/OneDrive/Desktop/project/data/trained_knn_model_new.RData"

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
#* Recommend songs based on input song data
#* @param popularity Popularity of the song
#* @param duration_ms Duration of the song in milliseconds
#* @param danceability Danceability of the song
#* @param energy Energy of the song
#* @param loudness Loudness of the song
#* @param speechiness Speechiness of the song
#* @param acousticness Acousticness of the song
#* @param instrumentalness Instrumentalness of the song
#* @param liveness Liveness of the song
#* @param valence Valence of the song
#* @param tempo Tempo of the song
#* @param track_genre Genre of the track
#* @get /recommend
function(popularity, duration_ms, danceability, energy, loudness, speechiness, acousticness, 
         instrumentalness, liveness, valence, tempo, track_genre) {
  input_song <- data.frame(
    track_id = "new_track_id",
    artists = "new_artist",
    album_name = "new_album_name",
    track_name = "new_track_name",
    popularity = as.numeric(popularity),
    duration_ms = as.numeric(duration_ms),
    danceability = as.numeric(danceability),
    energy = as.numeric(energy),
    loudness = as.numeric(loudness),
    speechiness = as.numeric(speechiness),
    acousticness = as.numeric(acousticness),
    instrumentalness = as.numeric(instrumentalness),
    liveness = as.numeric(liveness),
    valence = as.numeric(valence),
    tempo = as.numeric(tempo),
    track_genre = track_genre
  )
  
  recommendations <- recommend_songs(input_song)
  return(list(recommendations = recommendations))
}

# Run the API
pr$run(port = 8000)
