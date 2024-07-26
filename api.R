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
a

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

