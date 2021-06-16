rm(list=ls())

library(plyr)
library(dplyr)
library(ggplot2)
library(bedr)
library(GenomicRanges)

#running on command line so automatically sets wd to current folder

#load the compiled tsv file
compiled_tsv <- read.delim(file = "all_seq.tsv", header = T, stringsAsFactors = F)
#remove the header lines that are interspersed
compiled_tsv = subset(compiled_tsv, seq_name !="seq_name")

#attach metadata
meta.df <- read.csv(file="meta_df.csv", header = T, stringsAsFactors = F)
#remove any for which there is no sequencing info
meta.df <- meta.df[!is.na(meta.df$ID_IDSeq),]

#merge Ct and IP names
head(meta.df)
merge.dat <- dplyr::select(meta.df, ID_IDSeq, ID_Viro, sample_collection_date, Ct)
names(merge.dat)[1] <- "seq_name"
new.df <- merge(x=compiled_tsv, y = merge.dat, all.x=TRUE, by= "seq_name")


#now arrange by Ct and plot
new.df <- arrange(new.df, Ct, seq_name, position)


#plot rpm on a log10 scale
new.df$label <- paste0(paste0(paste0(paste0(paste0(paste0(paste0("Ct=",new.df$Ct), "\n"), "IPM-ID="), new.df$ID_Viro), "\n"), "CZB-ID="), new.df$seq_name)
new.df$rpm <- as.numeric(new.df$rpm)
new.df$position <- as.numeric(new.df$position)
#log scale
#and plot
p1 <- ggplot(data =new.df) + geom_line(aes(x=position, y= log10(rpm)), color="cornflowerblue") +
  facet_wrap(~label, ncol=4) + theme_bw() + ylab("log10(reads per million)") + xlab("genome position") +
  theme(panel.grid = element_blank(), strip.background = element_rect(fill="white"), 
        strip.text = element_text(face="bold")) +
  scale_y_continuous(breaks = c(0,1,2,3,4), labels = c("0", "10^1","10^2", "10^3", "10^4")) 
print(p1)

ggsave(file = "all-seq-rpm.png",
       units="mm",  
       width=80, 
       height=80, 
       scale=3, 
       dpi=300)

#and summarize across all genomes - first others to numeric
new.df$reads <- as.numeric(new.df$reads)
new.df$flagN <- as.numeric(new.df$flagN)
new.df$flagAmbiguous <- as.numeric(new.df$flagAmbiguous)
new.df$flagSNP <- as.numeric(new.df$flagSNP)
tsv.sum = ddply(new.df, .(ID_Viro, seq_name, total_reads, coverage, n_missing, Ct, sample_collection_date), summarise, avg_depth = mean(reads), totN=sum(flagN), totAmbiguous=sum(flagAmbiguous), totSNP=sum(flagSNP))

#and save as a csv file
write.csv(tsv.sum, file = "sequence_summary.csv", row.names=F)

#then, also write a summary that highlights where you need to go look manually in Geneious
tsv.view <- subset(new.df, flagN!=0 | flagAmbiguous!=0)
tsv.view <- dplyr::select(tsv.view, seq_name, ID_Viro, coverage, position, reads, rpm, refseq, cns, flagN, flagAmbiguous)

write.csv(tsv.view, file ="seq_check_manual.csv", row.names=F)

#now split and make bed file for annotation tracks to examine in Geneious
split.dat <- dlply(tsv.view, .(seq_name))

make.segment <- function(df){
  chromStart <- min(df$position)
  chromEnd <- max(df$position)
  chrom <- "chr"
  #if (unique(df$flagN)==1){
   # name <- "N"
  #}else if(unique(df$flagAmbiguous)==1){
   # name="Ambiguous"
  #}
  #make dataframe
  df.out <- cbind.data.frame(chrom, chromStart, chromEnd)#, name)
  return(df.out)
}
make.annot.track <- function(dat){
  dat <- arrange(dat, position)
  #add on an identifier to group 
  dat$diff <- c(diff(dat$position),diff(dat$position)[length(diff(dat$position))])
  #in some cases, you might get multiple interspersed strings of 1s  from different tracks
  
  dat$track <- with(rle(dat$diff), rep(seq_along(values), lengths))
  
  #now split by that identifier and make segment
  sub.split <- dlply(dat, .(track))
  
  #and make segment
  out.bed <- lapply(sub.split, make.segment)
  
  
  #and join
  bed.df <- data.table::rbindlist(out.bed)
  #and arrange
  bed.df <- as.data.frame(dplyr::arrange(bed.df, chromStart))
  
  
  
  #bed.df <- as.matrix(bed.df)
  colnames(bed.df) <- c("chr", "start", "end")
  
  #then, for bed, need to add one if same
  for(i in 1:length(bed.df$chr)){
    if(bed.df$start[i]==bed.df$end[i]){
      bed.df$start[i] <- bed.df$end[i] - 1
    }
  }
  #bed.df
  bed.save <- convert2bed(bed.df, check.chr = FALSE)
  
  #and save as a bed file particular to this sequence
  write.table(bed.save, file = paste0(unique(dat$seq_name),".bed"),quote=F, sep="\t", row.names = F, col.names = F)
  
}

#and create them

lapply(split.dat, make.annot.track)

#now, take the "seq_check_manual.csv" file and the .bed file to Geneious to 
#manually curate and edit the consensus.fa
#after manual curation, you can run another script to produce a master mutation file by comparing with the ref

