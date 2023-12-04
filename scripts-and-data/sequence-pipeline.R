rm(list =ls())

library(seqinr)
library(plyr)
library(dplyr)
library(readr)
library(msa)
library(rjson)



#running on command line, so it automatically sets the wd to the current folder
#print(getwd())


#load the reads
tsv <- read.delim(file = "samtools_depth.txt", header = F)
tsv$position = 1:nrow(tsv)

#read json file to get name
json <- fromJSON(file="stats.json")
seqname = json$sample_name
#seqname = sapply(strsplit(basename(getwd()), split="_outputs"), '[', 1)

#tsv$seq_name = seqname
#head(tsv)


#start.pos <- min(tsv$position[tsv$reads>0])
#stop.pos <- max(tsv$position[tsv$reads>0])


#and include the master 
refseq <-  seqinr::read.fasta(file = "MN908947.3.fa", as.string = T, forceDNAtolower = F)


#now load the 
#and add the consensus
if(file.exists("consensus.fa")){
  fasta <- seqinr::read.fasta(file = "consensus.fa", as.string = T, forceDNAtolower = F)
  
}else if (file.exists(paste0(seqname,".consensus.fasta"))){
  fasta <- seqinr::read.fasta(file = paste0(seqname,".consensus.fasta"), as.string = T, forceDNAtolower = F)
}

# seqname2 = names(fasta)
# seqname2 <- gsub(pattern = "/", replacement = "_", seqname2)
# seqname2 <- gsub(pattern = " ", replacement = "_", seqname2)



# if the fasta file 
tsv$seq_name <- seqname
names(tsv) <- c("reads","position",  "seq_name")
names(fasta) <- seqname

#save the two as a concatenated file
all_fasta <- list()
all_fasta[[1]] <- refseq
all_fasta[[2]] <- fasta

write.fasta(all_fasta, file="all_fasta.fasta", names = c(names(refseq), names(fasta)), as.string = T)

#load concatenated file as a string and align with msa
all_fasta <- readDNAStringSet(file = "all_fasta.fasta", format = "fasta")
#alignment may take a moment
aln <- msa(all_fasta, method="Muscle")


tsv$refseq <- as.character(as.vector(aln@unmasked[["MN908947.3"]][1:nrow(tsv)]))

tsv$cns <- as.character(as.vector(aln@unmasked[[names(fasta)]][1:nrow(tsv)]))


#now add a column flagging the mutations
tsv$flagN <- 0
tsv$flagN[tsv$cns=="N"] <- 1

tsv$flagAmbiguous <- 0
tsv$flagAmbiguous[tsv$cns=="M" |tsv$cns=="K" |tsv$cns=="R" |tsv$cns=="Y" | tsv$cns=="B" | tsv$cns=="D" |tsv$cns=="H" |tsv$cns=="V"| tsv$cns=="W"] <- 1


#now identify mutations 
tsv$flagSNP <- 0
tsv$flagSNP[tsv$cns!=tsv$refseq & tsv$cns!="-"] <- 1 
tsv$flagSNP[tsv$flagSNP==1 & tsv$flagN==1 | tsv$flagSNP==1 & tsv$flagAmbiguous==1] <- 0

tsv$ID_SNP <- 0
tsv$ID_SNP[tsv$flagSNP==1] <- paste(tsv$refseq[tsv$flagSNP==1], tsv$cns[tsv$flagSNP==1], sep = "->")


#load json file for raw reads and rpm
# 
# json <- fromJSON(file = "stats.json")

tsv$total_reads <- json$total_reads
tsv$rpm <- tsv$reads/(tsv$total_reads/1000000)

tsv$n_missing = length(tsv$cns[tsv$cns=="N" | tsv$cns=="-"])


tsv$coverage = (nrow(tsv)-tsv$n_missing)/nrow(tsv)

#reorder into something more logical
tsv <- dplyr::select(tsv, seq_name, total_reads, coverage, n_missing, position, reads, rpm, refseq, cns, flagN, flagAmbiguous, flagSNP, ID_SNP)
#then, save the whole thing to eventually convert to readmaps
write_tsv(tsv, paste0(seqname,"_all.tsv"))

#eventually will combine to get the following

#tsv.sum = ddply(tsv, .(seq_name, total_reads, coverage, n_missing), summarise, avg_depth = mean(reads), totN=sum(flagN), totAmbiguous=sum(flagAmbiguous), totSNP=sum(flagSNP))

