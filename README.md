# SC2-genome-curation

This site hosts the scripts needed to curate SARS-CoV-2 consensus genomes produced in part with our Institut Pasteur of Madagascar collaboration. Consensus genomes are produced from a Nexflow pipeline on [IDseq.net](IDseq.net) after upload of raw .fastq files from Next Generation Sequencing. The scripts stored here can be run on the resulting IDseq output, manually curated, then uploaded to GISAID.org.

Step-by-step instructions for genome curation on a new sequencing project are as follows:

1. Download all "metadata" folders for new genomes in IDseq, unzip, and store one parent folder. Each genome's metadata folder must currently be downloaded individually, though the IDseq team is working to amend this.

2. Move the following files into the parent folder (all files are stored in this github repo, with a blank example of the meta_df.csv file):

copy-scripts.R
sequence-pipeline.R
MN908947.3.fa
merge-meta-plot.R
loop-COVID-seq.txt
meta_df.csv
make-manual-cns.R

The "meta_df.csv" folder should include the appropriately structured metadata with both CZB-ID and IPM-ID for each sample processed.

3. Run the processing script with the line:

    sh -e loop-COVID-seq.txt 

4. Take the output file "seq_check_manual.csv" and manually check the Ns and ambiguities in [Geneious](geneious.com). Once completed, generate an edited tsv file with the manually edited consensus genome in one column. Do this individually for all the newly sequenced folders in your dataset and store the manually edited file in the same folder as "SEQNAME_all_manual.tsv".

5.Then, pull the manually edited tsvs from all folders into the parent folder, using this script:

mkdir manual-tsv
cd manual-tsv
cp /path_to_folder/*_outputs/*_manual.tsv .

6. Then concatenate all tsv files with:

cat *tsv > all_manual.tsv
mkdir consensus-manual

7. Then  run R script to generate new manual consensus files and store in above folder, along with a  final mutation and ambiguities summary file.

Rscript make-manual-cns.R

8. Concatenate all the manually-edited genomes and upload to check genome integrity on [Nextclade](https://clades.nextstrain.org/). Decide what to submit to GISAID.


