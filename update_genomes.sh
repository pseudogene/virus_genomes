#!/bin/bash
##
## UPDATE GENOME_SEQUENCES
##
export URL=ftp://ftp.ncbi.nlm.nih.gov/genomes
export URL2=http://mirrors.vbi.vt.edu/mirrors/ftp.ncbi.nih.gov/genomes

export GENOMES=$(pwd)/genome_sequences

echo ">Update genome sequences sequences"
rm -rf "${GENOMES}"
mkdir -p "${GENOMES}"

./import_genomes.pl --query "txid10239[Organism:exp]" -m > download.sh

bash download.sh

echo "  * Done"
