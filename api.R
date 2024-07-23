
# Load the plumber package
library(plumber)

#* @apiTitle My First API

#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg="") {
  list(msg = paste("The message is:", msg))
}

#* Return the sum of two numbers
#* @param a The first number
#* @param b The second number
#* @get /sum
function(a, b) {
  as.numeric(a) + as.numeric(b)
}

