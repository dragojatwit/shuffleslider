Welcome to Shuffle Slider!

In order to run this program there are two prerequisites:
1. Installation of NodeJS to run the webapp on a local server
2. Installation of Rstudio to run the API which hosts the Machine Learning Algorithm
3. Installation of Rstudio package rstudioapi

To access the program
1. Navigate to shuffleslider/project/Rcode and launch Shuffle Slider API.R and run it
2. Navigate back to the root directory (shuffleslider/)
3. In console run "npm run dev" to launch the webapp on localhost
4. Navigate in a web browser to http://localhost:5173

Directory

index.html - base and only html file for website;
src/api_script.js - javascript which handles html template switching and api communication;
public/style.css - all css;
project/Shuffle Slider API.R - API to communicate with machine learning algorithm;
project/Data - all ML algorithms and datasets;
