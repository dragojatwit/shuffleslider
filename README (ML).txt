In relation to the ML script "MLAlg.R"

Preprocessing:
	-Numeric features are normilized for better KNN performance
	-The "genres" column is converted to dummy variables
Model Training:
	-Data is split into training and testing sets (80/20)
	-A KNN model is trained using 10-fold cross-validation to fin the best value of k
preprocess_input_song function:
	-This function preprocesses the input song data similarly to how the training data was preprocessed
	-It normalizes the numeic features and encodes the "genres" column
recommended_songs function:
	-This function uses the "preprocess_input_song" function to preprocess the input song
	-It then uses the KNN model to find similar songs
Example Usage:
	-A data frame "input_song" is created with the details of the song for which you want to find similar songs
	-The "recommend_songs" function is called with this data frame to get recommendations

IMPORTANT:
Make sure to replace the example song details in "input_song" with the actual details of the song you want to use as an input. Run this updated code to get recommendations