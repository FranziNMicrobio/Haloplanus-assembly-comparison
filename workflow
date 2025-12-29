# Haloplanus genome assembly comparison

#Define database path for checkm2
DATABASE_PATH="PATHTODATABASE/checkm2_20240904.squashfs"
#Define the paths required or add to script below
#For adapter removal from illumina sequences, trimmomatic needs a path to the adapter sequences, here = PATHTOADAPTERFOLDER
#A path for the working directory containing the sequencing files is also required, here = PWDTOWORKINGDIRECTORY
#Path to the container directory = PWDTOCONTAINER

# For simplicity, the names of the sequencing files were renamed as follows
# Nanopore reads were renamed to nanoporesequences.fastq.gz
# Illumina forward reads were renamed to illuminasequences_1.fastq.gz
# Illumina reverse reads were renamed to illuminasequences_2.fastq.gz

#For this workflow the following software was installed as singularity containers:
#porechop v0.2.4 (Oxford Nanopore adaptar removal)
#flye v2.9.6 (Oxford Nanopore assembly)
#medaka v2.1.0 (Oxford Nanopore assembly polishing)
#quast v5.2.0 (assembly QC 1)
#checkm2 v1.1.0 (assembly QC 2)
#spades v3.15.5 (Illumina and hybrid approach assembly)

#The following software was installed as a module:
#trimmomatic v0.39

########---Long read approach using Oxford Nanopore technology---########

# Removing adapter sequences using porechop
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/porechop-0.2.4 porechop -i nanoporesequences.fastq.gz -o /workdir/porechop.fastq.gz

# Quality trimming omitted as the assembly was hindered by quality trimming

# Assembling nanopore long reads reads using flye
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/flye_2.9.6 flye -t 14 --nano-raw /workdir/porechop.fastq.gz --out-dir flye_out -g 3m

# Polishing using medaka
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/medaka_2.1.0 medaka_consensus -i /workdir/porechop.fastq.gz -d /workdir/flye_out/assembly.fasta -o /workdir/flye_out/medaka_out -t 8 

# Assessing assembly quality using quast
# The --min-contig 0 flag is important because otherwise contigs below 500 bases aren't used for the stats and the the quality might be overestimated.
# Running quast with and without this flag will directly get the number of contigs < 500 bases
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/quast-5.2.0 quast.py /workdir/flye_out/medaka_out/consensus.fasta --min-contig 0 -o /workdir/flye_out/medaka_out/quast_out_mincontig0 -t 4
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/quast-5.2.0 quast.py /workdir/flye_out/medaka_out/consensus.fasta -o /workdir/flye_out/medaka_out/quast_out -t 4

# Assessing assembly quality using checkm2 to calculate coding density, estimate completeness and contamination although contamination has to be interpreted with caution since the DNA came from an isolate and because Haloarchaea are polyploid (Zerulla and Soppa 2014)

singularity exec --bind "${DATABASE_PATH}:/db:image-src=/" --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTOCONTAINER/checkm2_1.1.0 checkm2 predict --threads 6 --input /workdir/flye_out/medaka_out/consensus.fasta --output-directory /workdir/flye_out/medaka_out/checkm2 --database_path /db/uniref100.KO.1.dmnd -x fasta


########---Short read aproach Illumina sequencing---########

# Removing adapters and quality trimming using trimmomatic, which was not installed as a containers

module load apps/binapps/trimmomatic/0.39

#
trimmomatic PE illuminasequences_1.fastq.gz illuminasequences_2.fastq.gz illuminasequences_1_trimmed.fastq.gz illuminasequences_1_untrimmed.fastq.gz illuminasequences_2_trimmed.fastq.gz illuminasequences_2_untrimmed.fastq.gz ILLUMINACLIP:/PATHTOADAPTERFOLDER/TruSeq3-PE.fa:2:30:1 SLIDINGWINDOW:4:15

# Assembling illumina short reads using spades

singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/spades-3.15.5.sif spades.py -t 10 -1 /workdir/illuminasequences_1_trimmed.fastq.gz -2 /workdir/illuminasequences_2_trimmed.fastq.gz --isolate -o illumina_spades_out
Quast:

# Assessing assembly quality using quast
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/quast-5.2.0.sif quast.py contigs.fasta --min-contig 0  -o quast_out_mincontig0 -t 6
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/quast-5.2.0.sif quast.py contigs.fasta -o quast_out -t 6

# Assessing assembly quality using checkm2 to calculate coding density, estimate completeness and contamination
singularity exec --bind "${DATABASE_PATH}:/db:image-src=/" --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/checkm2_1.1.0--pyh7e72e81_1 checkm2 predict --threads 6 --input /workdir/illumina_spades_out/contigs.fasta --output-directory /workdir/illumina_spades_out/checkm2 --database_path /db/uniref100.KO.1.dmnd -x fasta


########---Hybrid approach---########

# Hybrid assembly using illumina short reads for contig assembly and nanopore long reads to bridge contigs (Antipov et al. 2016, hybridSPAdes: an algorithm for hybrid assembly of short and long reads)

singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/spades-3.15.5.sif spades.py -t 18 -1 /workdir/illuminasequences_1_trimmed.fastq.gz -2 /workdir/illuminasequences_2_trimmed.fastq.gz --nanopore porechop.fastq.gz -o hybrid_spades_out

# Assessing assembly quality using quast
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/quast-5.2.0 quast.py /workdir/hybrid_spades_out/contigs.fasta --min-contig 0 -o /workdir/hybrid_spades_out/quast_out_mincontig0 -t 6
singularity exec --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/quast-5.2.0 quast.py /workdir/hybrid_spades_out/contigs.fasta -o /workdir/hybrid_spades_out/quast_out -t 6

# Assessing assembly quality using checkm2 to calculate coding density, estimate completeness and contamination
singularity exec --bind "${DATABASE_PATH}:/db:image-src=/" --bind /PWDTOWORKINGDIRECTORY:/workdir /PWDTPCONTAINER/checkm2_1.1.0 checkm2 predict --threads 6 --input /workdir/hybrid_spades_out/contigs.fasta --output-directory /workdir/hybrid_spades_out/checkm2 --database_path /db/uniref100.KO.1.dmnd -x fasta
