// variables
var express = require('express');
//var redirect = require("express-redirect");
var fs = require("fs");
var bodyParser = require('body-parser');


var app = express(); // express application
app.use(bodyParser.urlencoded({ extended: false }));

// static directory
app.use(express.static('static'))

// Home Page: index.html
app.get('/', (req, res) => {
  res.sendFile('./static/index.html');
});

// create page
app.get('/page', (req, res) => {
  res.sendFile(__dirname + '/static/index.html');
});

app.post('/page', function(req, response){
  var file = req.body.file;
  var content = req.body.myPage;
  htmlFile(file,content,response);
});

port = 3000;

app.listen(port, (err) => {
  console.log(`The magic happens on port: ${port}`);
});
