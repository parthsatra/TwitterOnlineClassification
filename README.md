# TwitterOnlineClassification
An application for online classification of Twitter tweets into “Love” or “Hate”. 

#Project Overview:

The project is mainly to learn and understand the process of developing a model on streaming data, in this case Twitter. This is a default P3 project to classify tweets as “love” and “hate”. The project can be described in multiple phases as follows:

Data Retrieval: The project fetches the required data from Twitter. streamR package is used to fetch the tweets and then parse them to retrieve the text of the tweet. The tweets are fetched with filter love and hate separately and then combined and shuffled before preprocessing so that we have enough representation from both the classes. 

Data Preprocessing: The data is preprocessed to remove special characters, URLs, white spaces, numbers and punctuations. Then all the remaining words are converted to lowercase characters, uses ASCII encoding, stems the document and finally removes all the stop words. Since we stem first the derivatives to words “love” and “hate”, words like “lovable” are stemmed to “love” and are eventually removed, since we also remove words love and hate. Stops words also include reserved words specified by R, since any of these words if present, might create errors during code execution. Finally we create a document term matrix.

Feature Construction and Feature Selection: The document term matrix only has those terms which have at least a threshold frequency. Thus only terms occurring with a frequency greater than the threshold are selected. Based on these terms the formula is created and later used for the training purpose.

Model Training and Prediction: The model is trained based on the obtained set of trained data and from the previously generated formula based on the feature set. Once the model is trained a fresh test data is fetched from twitter containing both love and hate tweets together. The same preprocessing is done on the test data as well and the same key features generated while training is extracted from test data. If any of the feature is missing then that feature is set to 0 in the corresponding document. Next this generated test data is predicted using the model. We then print the confusion matrix and the accuracy of the model. Finally the same test data along with the classes known is used to update the model for future iterations. 

Please note for greater insights you can also refer to the Rscript present with this file. The script contains the required comments for each step.     

#Instructions to run the script:

Please follow the following instructions to run the script. 
Install the required packages. The packages are present in the script but are commented. If required can be uncommented or can be installed manually. These are as follows:
install.packages('streamR', dependencies=TRUE)
install.packages('ROAuth', dependencies=TRUE)
install.packages('tm', dependencies=TRUE)
install.packages('SnowballC', dependencies=TRUE)
install.packages('RMOA', dependencies=TRUE)

Run the script using the following. Before running this command make sure you have set the right working directory where the script is present. 
source(“Project_3.R”)

The script will ask for your Twitter_Consumer_Key and Twitter_Consumer_Secret for connecting to twitter using the credentials. Once entered you will be redirected to twitter page where you need to login and authorize the client for using your credentials.

Finally you will be able to see the accuracy and the confusion matrix of the test data. To continue the execution with the next set of tweets for testing type ‘yes’. To stop the application type ‘no’
	
