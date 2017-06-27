# virus_genomes

We foster the openness, integrity, and reproducibility of scientific research.


## How to use this repository?

This repository hosts, various scripts and tools to collect and process (virus) genomes. Feel free to adapt the scripts and tools, but remember to cite their authors!

To look at our scripts, **browse** through this repository. If you want to use some of the scripts, you will need to **clone** this repository. If you want to use our scripts for our own research, **fork** this repository and **cite** the authors.


## Installation

You will need [git](https://git-scm.com/) and [aria2](https://aria2.github.io/) to be installed.

```
apt-get install git aria2 --no-install-recommends
git clone https://github.com/pseudogene/virus_genomes.git
cd virus_genomes
```


## Usage and examples

`import_genomes.pl` - An up-to-date (May 2017) assembly extractor. Provide an "Entrez query" as you would do while using the [NCBI assembly search box](https://www.ncbi.nlm.nih.gov/assembly/?term=drosophila%5BOrganism%5D) and the script will the list of command necessaire to download all genomes (Fasta format)

```
Usage: import_genomes.pl --query <Entrez search string>

--query <string>
    Provide an Entrez search string as used in search field of the NCBI assembly database.
    e.g. --query "(Vertebrata[Organism]) NOT Tetrapoda[Organism]"
--exclude <string>    Exclude a species or genome (can be used multiple time). [default none]
    e.g. --exclude \"Oreochromis niloticus\"
--out <filename>
    Prive a file where to save specices desctiption. [default none]
--all
    If species is represented multiple time same all assemblies rather than the RefSeq one.
--map
    Create map files for makeblastdb using the taxonid field.
--remap
    Create map files for makeblastdb but ignore the taxonid field.
--verbose
    Become very chatty.
```

```
# All viruses (and genome map "-m")
./import_genomes.pl --query "txid10239[Organism:exp]" -m -v > downloading_script.sh

# All fish genomes (all vertebrate excluding the tetrapods)
./import_genomes.pl --query "(Vertebrata[Organism]) NOT Tetrapoda[Organism] AND (latest[filter] AND all[filter] NOT anomalous[filter])" -v > downloading_script.sh

# All Pseudogymnoascus spp genomes (include all "-a" genome if there are more than one per species; create a index "-out" file will the assembly details)
./import_genomes.pl -a --query "txid78156[Organism:exp]" -out 'pseudogymnoascus.index' -v > downloading_script.sh
```


## Issues

If you have any problems with or questions about the scripts, please contact us through a [GitHub issue](https://github.com/pseudogene/virus_genomes/issues).


## Contributing

You are invited to contribute new features, fixes, or updates, large or small; we are always thrilled to receive pull requests, and do our best to process them as fast as we can.


## License and distribution


This code is distributed under the [GNU GPL license v3](https://www.gnu.org/licenses/gpl-3.0.html). The documentation, raw data and work are licensed under a [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).​
