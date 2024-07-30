library(plumber)

#* @apiTitle My First API

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

#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg="") {
  list(msg = paste("The message is:", msg))
}

#* Example data endpoint
#* @get /data
function() {
  data <- data.frame(
    uri = "spotify:track:26I6RaeZZrIMyGAUwfNCxo"
  )
  return(data)
}

#* @post /process
#* @param playlistUrl The URL of the playlist sent in the request body
#* @json
function(req) {
  tryCatch({
    # Log raw request body
    raw_body <- req$postBody
    print(paste("Raw body:", raw_body))
    
    # Parse JSON body
    body <- jsonlite::fromJSON(raw_body)
    
    # Check if playlistUrl is present
    if (is.null(body$playlistUrl)) {
      stop("playlistUrl is missing in the request body.")
    }
    
    # Return a response
    return(list(message = "Data received successfully", playlistUrl = body$playlistUrl))
  }, error = function(e) {
    # Handle errors
    message <- paste("Error:", e$message)
    print(message) # Print error message to the log
    return(list(error = message))
  })
}
