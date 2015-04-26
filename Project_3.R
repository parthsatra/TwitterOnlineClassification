#Description: An application for online classification of Twitter Tweets into "Love" or "Hate".

#Clear environment variables.
rm(list=ls())

#Install and load libraries. Uncomment if required.
#install.packages('streamR', dependencies=TRUE)
#install.packages('ROAuth', dependencies=TRUE)
#install.packages('tm', dependencies=TRUE)
#install.packages('SnowballC', dependencies=TRUE)
#install.packages('RMOA', dependencies=TRUE)
library("streamR")
library("ROAuth")
library("tm")
library("SnowballC")
library("RMOA")

##################################### FUNCTIONS #####################################

#Function that establishes a connection to Twitter using streamR.
#Takes consumerKey and consumerSecret as input.
twitterConnection <- function(consumerKey, consumerSecret) {
  requestURL <- "https://api.twitter.com/oauth/request_token"
  accessURL <- "https://api.twitter.com/oauth/access_token"
  authURL <- "https://api.twitter.com/oauth/authorize"
  my_oauth <- OAuthFactory$new(consumerKey=consumerKey,
                               consumerSecret=consumerSecret, requestURL=requestURL,
                               accessURL=accessURL, authURL=authURL)
  my_oauth$handshake(cainfo = system.file("CurlSSL", "cacert.pem", package = "RCurl"))
  return (my_oauth)
}

#Function that extracts the text field from tweets.
extractTweetText <- function(tweet_list) {
  tweet_information <- readTweets(tweet_list)
  tweet_text <- unlist(lapply(tweet_information, '[[', 'text'))
  return (tweet_text)
}

#Function that retrieves love and hate tweets from twitter and extracts the text field from the tweets.
#Returns a character vector consisting of the text field of love and hate tweets.
#Used only for training data.
returnTrainingTweets <- function(timeout=1, tweets=NULL, oauth) {
  twitterLoveData <- filterStream(file="", track="love", timeout=timeout, tweets=tweets, oauth=oauth, 
                                  language="en")
  twitterHateData <- filterStream(file="", track="hate", timeout=timeout, tweets=tweets, oauth=oauth, 
                                  language="en")
  twitterTrainingData <- c(twitterLoveData, twitterHateData)
  twitterTrainingData <- extractTweetText(twitterTrainingData)
  return (twitterTrainingData)
}

#Function that retrieves love and hate tweets from twitter and extracts the text field from the tweets.
#Returns a character vector consisting of the text field of love and hate tweets.
#Used only for test data.
returnTestTweets <- function(timeout=1, tweets=NULL, oauth) {
  twitterTestData <- filterStream(file="", track=c("love", "hate"), timeout=timeout,
                                  tweets=tweets, oauth=oauth)
  twitterTestData <- extractTweetText(twitterTestData)
  return (twitterTestData)
}

#Function that generates a label "hate" if a tweet contains the word "hate". Similar for "love". 
generateClassLabel <- function(tweet) {
  as.vector(ifelse(grepl("hate", tweet), "hate", "love"))
}

#Function that returns the class labels of input tweets.
getClassLabels <- function(tweet_list) {
  classLabel <- sapply(tweet_list, generateClassLabel)
  names(classLabel) <- NULL
  return (classLabel)
}

#Function to filter special characters and URLs from tweets.
filterTweets <- function(tweet) {
  text <- gsub("http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+", "", tweet)
  text <- gsub("[^a-zA-Z0-9_ ]", "", text)
  text <- gsub("\t", " ", text)
  return (text)
}

#Function that preprocesses tweets. The steps are outlined below.
# 1)Use the filterTweets custom function to remove links, special symbols, etc.
# 2)Create a corpus.        3)Strip whitespaces.
# 4)Transform to UTF-8 encoding.       5)Transform to lowercase.
# 6)Remove numbers.       7)Remove punctuations.        8)Remove stopwords.
# 9)Stem words.       10)Create DocumentTermMatrix.
#This function takes care of feature construction and selection through the frequency parameter.
preprocessTweets <- function(twitterData, frequency) {
  document <- vapply(twitterData, filterTweets, "")
  my_stopwords <- c(stopwords("SMART"), "love", "hate", "break", "next", "if", "else", 
                    "repeat", "while", "function", "for", "TRUE", "FALSE", "NULL", "Inf",
                    "NaN", "NA", "input")
  my_corpus <- Corpus(VectorSource(twitterData))
  my_corpus <- tm_map(my_corpus, stripWhitespace)
  my_corpus <- tm_map(my_corpus, content_transformer(function(x) iconv(x, to='ASCII', sub='byte')), mc.cores=1)
  my_corpus <- tm_map(my_corpus, content_transformer(tolower))
  my_corpus <- tm_map(my_corpus, removeNumbers)
  my_corpus <- tm_map(my_corpus, removePunctuation)
  my_corpus <- tm_map(my_corpus, removeWords, my_stopwords)
  my_corpus <- tm_map(my_corpus, stemDocument)
  my_corpus <- tm_map(my_corpus, removeWords, my_stopwords)
  DTM <- DocumentTermMatrix(my_corpus, control=list(wordLengths=c(4,Inf), 
                                                    bounds=list(global=c(frequency,Inf))))
  dataframe <- as.data.frame(as.matrix(DTM))
  return (dataframe)
}

#Function to extract key features from test data which are same as obtained during training.
extractFeatures <- function(trainingDataFrame, testDataFrame) {
  modifiedData <- subset(testDataFrame, select = colnames(testDataFrame) %in% colnames(trainingDataFrame))
  diff <- setdiff(colnames(trainingDataFrame), colnames(modifiedData))
  t <- modifiedData
  t[,diff] = 0
  diffData <- t
  diffData <- diffData[,-length(names(diffData))]
  return (diffData)
}

#Function to get accuracy of classification.
getAccuracy <- function(confusion_matrix) {
  if(nrow(confusion_matrix) == 1){
    accuracy <- confusion_matrix[1,2]/sum(confusion_matrix)
  }else {
    accuracy <- (confusion_matrix[1,1]+confusion_matrix[2,2])/sum(confusion_matrix)
  }
  return (accuracy)
}

##################################### MAIN #####################################

#Prompt for user consumerKey and consumerSecret and establish twitter connection.
consumerKey <- readline(prompt="Enter your Twitter Consumer Key: ")
consumerSecret <- readline(prompt="Enter your Twitter Consumer Secret: ")
my_oauth <- twitterConnection(consumerKey, consumerSecret)

#Retrieve training data from Twitter, preprocess it and create a training data frame.
trainingData <- returnTrainingTweets(timeout=100, tweets=1500, oauth=my_oauth)
trainingClassLabels <- getClassLabels(trainingData)
trainingDataFrame <- preprocessTweets(trainingData, 10)
words <- colnames(trainingDataFrame)
trainingDataFrame$classLabel <- trainingClassLabels

#Construct a formula for the classification task based on the feature set.
#Construct a stream from the training data.
myformula <- as.formula(paste('classLabel', paste(words, collapse=' + '), sep=' ~ '))
trainingDataFrame <- factorise(trainingDataFrame)
stream <- datastream_dataframe(trainingDataFrame)

#Create a Hoeffding Tree and train it on the training data stream.
hdt <- HoeffdingTree(numericEstimator = "GaussianNumericAttributeClassObserver")
twitterStreamingModel <- trainMOA(model = hdt, formula = myformula, data=stream)

#Loop check condition.
loopCheck <- "yes"

#Repeatedly predicting the test data and updating the model.
while(loopCheck == "yes") {
  #Retrieve test tweets, preprocess them and create test data frame.
  testData <- NULL
  testData <- returnTestTweets(timeout=10, oauth=my_oauth)
  testClassLabels <- getClassLabels(testData)
  testDataFrame <- preprocessTweets(testData, 0)
  
  #Extract key features from test data which are same as training data.
  processedTestData <- extractFeatures(trainingDataFrame, testDataFrame)
  factorizedTestData <- factorise(processedTestData)
  
  #Predict test data, print confusion matrix and accuracy.
  predictions <- predict(twitterStreamingModel, newdata=factorizedTestData, type="response")
  confusion_matrix <- table(predictions, testClassLabels)
  print(confusion_matrix)
  print(getAccuracy(confusion_matrix))
  
  #Update the model.
  processedTestData$classLabel <- testClassLabels
  processedTestData <- factorise(processedTestData)
  stream <- datastream_dataframe(processedTestData)
  twitterStreamingModel <- trainMOA(model = hdt, formula = myformula, data=stream, reset=FALSE)
  
  #Check condition for re-testing the next set of sample tweets.
  loopCheck <- readline(prompt="Enter yes to continue and no to stop: ")
  loopCheck <- tolower(loopCheck)
}

#consumerKey <- "Z5oh0yYwZe10luAbY1FT8spz8"
#consumerSecret <- "970U8ccZkE9ia83ZCIj3P7uO7Yubfc9iaglRHyXo6ErkOcBk2M"
