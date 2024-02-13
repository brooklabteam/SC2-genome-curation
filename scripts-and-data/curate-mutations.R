rm(list =ls())

library(seqinr)
library(plyr)
library(dplyr)
library(readr)
library(msa)
library(rjson)



#running on command line, so it automatically sets the wd to the current folder
#print(getwd())

mutations <- read.delim(file = "nextclade.tsv", header = T)
head(mutations)

#collapse to list of mutation names
#reversion substitutions
revSub <- c(unlist(strsplit(c(mutations$privateNucMutations.reversionSubstitutions),",")))
revSub <- revSub[!duplicated(revSub)]

#and the labeled mutations
labelSub <- strsplit(mutations$privateNucMutations.labeledSubstitutions, "|", fixed=T)


privSub <- c(unlist(strsplit(c(mutations$privateNucMutations.unlabeledSubstitutions),",")))
privSub[!duplicated(privSub)]

get.seqs <- function(df){
  if(length(df)>0){
  #first, combine first and last
  df2 <- c(paste0(df[length(df)], ",", df[1]), df[2:(length(df)-1)])
  df3 <- sapply(strsplit(df2,","), "[",2)
  return(df3)
  }
  
}
labelSub_new <- c(unlist(lapply(labelSub, get.seqs))) 
labelSub_new <- labelSub_new[!is.na(labelSub_new)]
labelSub_new <- labelSub_new[!duplicated(labelSub_new)]

allSub <- c(labelSub_new, revSub)

#now, load the json file of the current folder to get the name of the sequence
#now, read the cumulative json file and compare
this_seq <- fromJSON(file="stats.json")
seqname <- this_seq$sample_name

#load the sequence file
tsv <- read.delim(file = paste0(seqname, "_all.tsv"), header = T)
head(tsv)

#make a new column with the name of the mutation
tsv$mutation_name <- NA
tsv$mutation_name[tsv$flagSNP==1] <- paste0(tsv$refseq[tsv$flagSNP==1], tsv$position[tsv$flagSNP==1], tsv$cns[tsv$flagSNP==1])

#and make a new column for manual curation
tsv$cns_manual <- tsv$cns

#now, replace those labeled or reversion substitutions with Ns
intersect.list <- intersect(tsv$mutation_name, allSub)

for (i in 1:length(intersect.list)){
  tsv$cns_manual[tsv$mutation_name==intersect.list[i] & !is.na(tsv$mutation_name)]  <- "N"
}


#now add a flag for the private mutations
tsv$flag_privateSNP <- 0

new.intersect <- intersect(tsv$mutation_name, privSub)

for (i in 1:length(intersect.list)){
  tsv$flag_privateSNP[tsv$mutation_name==new.intersect[i] & !is.na(tsv$mutation_name)]  <- 1
}

#now, reorder and write a new file.

#reorder into something more logical
tsv <- dplyr::select(tsv, seq_name, total_reads, coverage, n_missing, position, reads, rpm, refseq, cns, cns_manual, flagN, flagAmbiguous, flagSNP, ID_SNP, flag_privateSNP)




write_tsv(tsv, paste0(seqname,"_all_manual.tsv"))

