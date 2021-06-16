rm(list =ls())

library(readr)

#running on the command line so sets wd to current folder


#now make a list of the names the folders
all_names <- list.files()

#copy these files over 
files_to_copy <- c("MN908947.3.fa","sequence-pipeline.R")

files_to_stay <-c("copy-scripts.R")

folder_names <- setdiff(setdiff(all_names, files_to_copy), files_to_stay)

#folder_names_df <- as.data.frame(folder_names)
#first, save the list of folder names as a txt file in your current folder
#write_delim(folder_names_df, file="folder_names.txt")


#then copy down your list:
for (i in 1:length(folder_names)){
  file.copy(from=paste(getwd(), files_to_copy[1], sep="/"), to=paste(getwd(), folder_names[i], sep="/"))
  file.copy(from=paste(getwd(), files_to_copy[2], sep="/"), to=paste(getwd(), folder_names[i], sep="/"))
}
#and save the files to each of the locations
