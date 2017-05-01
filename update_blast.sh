#!/bin/bash
##
## UPDATE BLAST_DATABASES
##
GENOMES=$(pwd)/genome_sequences
BLAST=$(pwd)/blast_databases

HERE=$(pwd)

echo ">Update blast databases"
rm -rf "${BLAST}"
mkdir -p "${BLAST}"

cd "${BLAST}"

cat ${GENOMES}/*.fasta > "${GENOMES}/Viruses.fa"
sed -i -e 's/>/>lcl\|/g' "${GENOMES}/Viruses.fa"
cat ${GENOMES}/*.map > "${GENOMES}/Viruses.maps"
sed -i -e 's/^/lcl\|/g' "${GENOMES}/Viruses.maps"
rm -f ${GENOMES}/*.map
#rm -f ${GENOMES}/*.fasta
makeblastdb -dbtype nucl -title "Viruses" -in "${GENOMES}/Viruses.fa" -parse_seqids -hash_index -out "Viruses_db" -taxid_map "${GENOMES}/Viruses.maps"
gzip -9 "${GENOMES}/Viruses.fa"
gzip -9 "${GENOMES}/Viruses.maps"

cd "${HERE}"

echo "  * Done"
