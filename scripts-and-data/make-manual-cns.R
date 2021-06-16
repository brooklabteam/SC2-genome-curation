rm(list=ls())

library(plyr)
library(dplyr)
library(Biostrings)
library(reshape2)

#load the compiled tsv
all.manual.tsv <- read.delim(file = "manual-tsv/all_manual.tsv", header = T)
head(all.manual.tsv)

#remove the headers embedded in concatenated form
all.manual.tsv = subset(all.manual.tsv, seq_name!="" & seq_name!="" & seq_name!="total_reads")

#and split by ID to generate consensus genomes and get the summary file for mutations, etc.
all.split <- dlply(all.manual.tsv, .(seq_name))


summarize.consensus <- function(dat1){
  
  dat1$position_num <- as.numeric(dat1$position)
  #first, replace cns_manual --- with N if in the first or last
  dat1$cns_manual[dat1$cns_manual=="-" & dat1$position_num<300  & !is.na(dat1$position_num)| dat1$cns_manual=="-" & dat1$position_num>29700 & !is.na(dat1$position_num)] <- "N"
  
  
  #and redo n_missing and coverage
  dat1$n_missing <-  length(dat1$cns_manual[dat1$cns_manual=="N"])
  dat1$coverage <- (29903-unique(dat1$n_missing))/29903
  
  #write manual column to  consensus genome fasta
  seq <- paste(dat1$cns_manual, collapse = "")
  names(seq) <- paste0("consensus_manual_edit_", unique(dat1$seq_name))
  dna <- DNAStringSet(seq)
  writeXStringSet(dna, paste0("manual-tsv/consensus-manual/",paste0(names(seq), ".fasta")))
  
  #and compare against the reference to make the final manual mutation flagger
  dat.new <- dplyr::select(dat1, seq_name, total_reads, coverage, n_missing, position, reads, rpm, refseq, cns_manual)
  
  dat.new$cns_manual <- as.character(dat.new$cns_manual)
  #now add a column flagging the mutations
  dat.new$flagN <- 0
  dat.new$flagN[dat.new$cns_manual=="N"] <- 1
  
  dat.new$flagAmbiguous <- 0
  dat.new$flagAmbiguous[dat.new$cns_manual=="M" |dat.new$cns_manual=="K" |dat.new$cns_manual=="R" |dat.new$cns_manual=="Y" | dat.new$cns_manual=="B" | dat.new$cns_manual=="D" |dat.new$cns_manual=="H" |dat.new$cns_manual=="V"| dat.new$cns_manual=="W"] <- 1
  
  
  #now identify mutations 
  dat.new$flagSNP <- 0
  dat.new$flagSNP[dat.new$cns_manual!=dat.new$refseq & dat.new$cns_manual!="-"] <- 1 
  dat.new$flagSNP[dat.new$flagSNP==1 & dat.new$flagN==1 | dat.new$flagSNP==1 & dat.new$flagAmbiguous==1] <- 0
  
  dat.new$ID_SNP <- 0
  dat.new$ID_SNP[dat.new$flagSNP==1] <- paste(dat.new$refseq[dat.new$flagSNP==1], dat.new$cns_manual[dat.new$flagSNP==1], sep = "->")
  #and also the ambiguities
  dat.new$ID_SNP[dat.new$flagAmbiguous==1] <- paste(dat.new$refseq[dat.new$flagAmbiguous==1], dat.new$cns_manual[dat.new$flagAmbiguous==1], sep = "->")
  
  #convert to numeric as needed
  dat.new$reads <- as.numeric(dat.new$reads)
  dat.new$coverage <- as.numeric(dat.new$coverage)
  dat.new$n_missing <- as.numeric(dat.new$n_missing)
  dat.sum = ddply(dat.new, .(seq_name, total_reads, coverage, n_missing), summarise, avg_depth = mean(reads), totN=sum(flagN), totAmbiguous=sum(flagAmbiguous), totSNP=sum(flagSNP))
  
  #and if it is an insertion, make sure to ID the location
  dat.new$position[dat.new$position=="insertion"] <- paste0("insertion-after-", (as.numeric(rownames(dat.new[dat.new$position[dat.new$position=="insertion"],])) -1))
  #and make a file that just highlights the SNPs and Ambiguities
  dat.snp <- dplyr::select(dat.new, seq_name, position, ID_SNP)
  dat.snp <- subset(dat.snp, ID_SNP!="0")
  
  return(list(dat.sum, dat.snp))
  
}


#and apply it, pulling the summary files
out.split <- lapply(all.split, summarize.consensus)

#now grab the summary files
out.sum <- sapply(out.split, "[", 1)
sum.dat <- data.table::rbindlist(out.sum)

#and load the metadata from previous run
seq.sum <- read.csv(file="sequence_summary.csv", header = T, stringsAsFactors = F)
seq.merge <- dplyr::select(seq.sum, ID_Viro, seq_name, Ct_Orf1, sample_collection_date)

sum.dat.merge <- merge(x=sum.dat, y=seq.merge, by="seq_name", all.x=TRUE)
#sort by date
sum.dat.merge$sample_collection_date <- as.Date(sum.dat.merge$sample_collection_date, format = "%m/%d/%y")

sum.dat.merge <- arrange(sum.dat.merge, sample_collection_date)
#and save 
write.csv(sum.dat.merge, file = "manual-tsv/consensus-manual/manual_consensus_summary.csv", row.names = FALSE)

#and the snp data
out.snp <- sapply(out.split, "[", 2)
snp.dat <- data.table::rbindlist(out.snp)

#and save 
write.csv(snp.dat, file = "manual-tsv/consensus-manual/manual_SNP_summary_vertical.csv", row.names = FALSE)

#and save a horizontal version like we had with vida
snp.dat.horizontal <- dcast(melt(snp.dat), position  ~ seq_name)
snp.dat.horizontal[is.na(snp.dat.horizontal)] <- 0
snp.dat.horizontal$position <- as.numeric(snp.dat.horizontal$position)
snp.dat.horizontal <- arrange(snp.dat.horizontal, position)

write.csv(snp.dat.horizontal, file = "manual-tsv/consensus-manual/manual_SNP_summary_horizontal.csv", row.names = FALSE)

