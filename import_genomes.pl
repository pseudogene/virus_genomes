#!/usr/bin/perl
# $Revision: 0.6 $
# $Date: 2017/04/27 $
# $Id: import_genomes.pl $
# $Desc: NCBI to Genome_index $ $
use strict;
use warnings;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request;
use LWP::Protocol::https;
use XML::Simple;

#----------------------------------------
our $VERSION = 0.6;
BEGIN { $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0 }

#----------------------------------------
sub _iteration
{
    my ($iteration, $outstring, $remap, $map, $verbose) = @_;
    my ($species, $cmd, $ftp, $accession);
    print {*STDERR} $iteration->{'Organism'}, '... ' if ($verbose);

    #    <AssemblyAccession>GCF_000002035.5</AssemblyAccession>
    #    <AssemblyName>GRCz10</AssemblyName>
    #    <Organism>Danio rerio (zebrafish)</Organism>
    #    <SpeciesTaxid>7955</SpeciesTaxid>
    #    <SpeciesName>Danio rerio</SpeciesName>
    #    <FtpPath_RefSeq>ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/002/087/205/GCF_002087205.1_ViralProj382351</FtpPath_RefSeq>
    #    <FtpPath_GenBank>ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/002/003/185/GCA_002003185.1_ASM200318v1</FtpPath_GenBank>
    if    (defined $iteration->{'FtpPath_RefSeq'}  && $iteration->{'FtpPath_RefSeq'} =~ m/^ftp:\/\/ftp\.ncbi\.nlm\.nih\.gov\/genomes\/(.*)$/g)  { $ftp = $1; }
    elsif (defined $iteration->{'FtpPath_GenBank'} && $iteration->{'FtpPath_GenBank'} =~ m/^ftp:\/\/ftp\.ncbi\.nlm\.nih\.gov\/genomes\/(.*)$/g) { $ftp = $1; }
    if (defined $iteration->{'AssemblyName'} && $iteration->{'AssemblyAccession'} && $iteration->{'Organism'} && $iteration->{'SpeciesTaxid'} && $iteration->{'SpeciesName'} && defined $ftp)
    {
        print {*STDERR} "done\n" if ($verbose);
        my $AssemblyName = $iteration->{'AssemblyName'};
        my $organism;
        $AssemblyName =~ tr/ /_/;
        $AssemblyName =~ tr/\+/_/;
        $organism  = $1 if ($iteration->{'Organism'} =~ m/\((.*)\)/);
        $species   = $iteration->{'SpeciesName'};
        $accession = $iteration->{'AssemblyAccession'};
        $cmd       = '#' . $iteration->{'Organism'} . "\n";
        $cmd .=
            'echo -e "'
          . $iteration->{'AssemblyAccession'} . '\t'
          . $iteration->{'SpeciesName'} . '\t'
          . $iteration->{'SpeciesTaxid'} . '\t'
          . $iteration->{'Organism'} . '\t<i>'
          . $iteration->{'SpeciesName'} . '</i>'
          . (defined $organism ? ' (' . $organism . q{)} : q{})
          . '\tGenome\tnucl\t'
          . $AssemblyName . '\t'
          . ($remap ? ++$remap : q{})
          . '" >> ${GENOMES}/'
          . $outstring . "\n"
          if (defined $outstring);
        $cmd .=
            'aria2c -s 5 -t 90 --retry-wait=10 -m 10 -c -q ${URL}/'
          . $ftp . q{/}
          . $iteration->{'AssemblyAccession'} . q{_}
          . $AssemblyName
          . '_genomic.fna.gz ${URL2}/'
          . $ftp . q{/}
          . $iteration->{'AssemblyAccession'} . q{_}
          . $AssemblyName
          . '_genomic.fna.gz' . "\n";
        $cmd .= 'gunzip -c ' . $iteration->{'AssemblyAccession'} . q{_} . $AssemblyName . '_genomic.fna.gz >${GENOMES}/' . $iteration->{'AssemblyAccession'} . '.fasta' . "\n";
        $cmd .= 'grep -e \'>\' ${GENOMES}/' . $iteration->{'AssemblyAccession'} . '.fasta | cut -f1 --delimiter=" " | cut -f2 -d">" | awk \'{print $0"\t"' . $remap . '}\' > ${GENOMES}/' . $iteration->{'AssemblyAccession'} . '.map' . "\n" if ($remap);
        $cmd .=
            'grep -e \'>\' ${GENOMES}/'
          . $iteration->{'AssemblyAccession'}
          . '.fasta | cut -f1 --delimiter=" " | cut -f2 -d">" | awk \'{print $0"\t"'
          . $iteration->{'SpeciesTaxid'}
          . '}\' > ${GENOMES}/'
          . $iteration->{'AssemblyAccession'} . '.map' . "\n"
          if ($map);
        $cmd .= 'rm -f ' . $iteration->{'AssemblyAccession'} . q{_} . $AssemblyName . '_genomic.fna.gz' . "\n";
    }
    else { print {*STDERR} "skip\n" if ($verbose); }
    return ($species, $cmd, $accession, $remap);
}
my ($verbose, $all, $map, $remap, $keep, $outstring, $xmlfile, $query) = (0, 0, 0, 0, 0);
my @ignore;
GetOptions('xml|i|input:s' => \$xmlfile, 'q|query:s' => \$query, 'e|exclude:s' => \@ignore, 'o|out:s' => \$outstring, 'k|keep' => \$keep, 'a|all!' => \$all, 'r|remap!' => \$remap, 'm|map!' => \$map, 'v|verbose!' => \$verbose);
if (!defined $xmlfile && !defined $query)
{
    print {*STDOUT}
      "Usage:  $0 --query <Entrez search string>\n\n--query <string>\n    Provide an Entrez search string as used in search field of the NCBI assembly database.\n    e.g. --query \"(Vertebrata[Organism]) NOT Tetrapoda[Organism]\"\n--exclude <string>\n    Exclude a species or genome (can be used multiple time). [default none]\n    e.g. --exclude \"Oreochromis niloticus\"\n--out <filename>\n    Prive a file where to save specices desctiption. [default none]\n--all\n    If species is represented multiple time same all assemblies rather than the RefSeq one.\n--map\n    Create map files for makeblastdb using the taxonid field.\n--remap\n    Create map files for makeblastdb but ignore the taxonid field.\n--verbose\n    Become very chatty.\n\n";
    exit(1);
}
if (!defined $xmlfile && defined $query)
{
    my @ret;
    my $url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi';
    my $ua  = new LWP::UserAgent;
    $ua->agent("esummary/1.0 " . $ua->agent);
    my $req = new HTTP::Request POST => $url;
    $req->content_type('application/x-www-form-urlencoded');
    $req->content('db=assembly&usehistory=y&term=' . $query);
    my $raw = $ua->request($req);

    if (defined $raw && defined $raw->content)
    {
        my $count = $1 if ($raw->content =~ m/<Count>(\d+)<\/Count>/);
        my $web   = $1 if ($raw->content =~ m/<WebEnv>([^<]+)<\/WebEnv>/);
        my $key   = $1 if ($raw->content =~ m/<QueryKey>(\d+)<\/QueryKey>/);
        if (defined $web && defined $key)
        {
            $url = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi';
            $req = new HTTP::Request POST => $url;
            $req->content_type('application/x-www-form-urlencoded');
            $req->content('db=assembly&rettype=xml&retmode=text&query_key=' . $key . '&WebEnv=' . $web);
            $raw = $ua->request($req);
            if (defined $raw && defined $raw->content && open(my $out, q{>}, 'output.xml'))
            {
                print {$out} $raw->content, "\n";
                close $out;
                $xmlfile = 'output.xml';
            }
        }
    }
}
else { $keep = 1 }
if (defined $xmlfile && -r $xmlfile)
{
    my %species;
    my $xml = XML::Simple->new;
    my $data = eval { $xml->XMLin($xmlfile) };
    if ($@) { print {*STDERR} "XML Error: Make sure the XML file has been generated by esummary or started with\n           <eSummaryResult><DocumentSummarySet>..</eSummaryResult></DocumentSummarySet>\n$@\n\n"; }
    else
    {
        if (ref($data->{'DocumentSummarySet'}->{'DocumentSummary'}) eq 'ARRAY')
        {
            foreach my $iteration (@{$data->{'DocumentSummarySet'}->{'DocumentSummary'}})
            {
                my @tmp = _iteration($iteration, $outstring, $remap, $map, $verbose);
                if (defined $tmp[0]) { $species{$tmp[0]}{$tmp[2]} = $tmp[1]; $remap = $tmp[3]; }
            }
        }
        else { _iteration($data->{'DocumentSummarySet'}->{'DocumentSummary'}, $outstring, $remap, $map, $verbose); }
        unlink($xmlfile) if ($keep == 0);
    }
    if (%species)
    {
        foreach my $item (sort keys %species)
        {
            my $skip = 0;
            foreach my $exclude (@ignore)
            {
                if (lc $exclude eq lc $item) { $skip = 1; last; }
            }
            if (!$skip)
            {
                if (scalar keys %{$species{$item}} > 1)
                {
                    print {*STDERR} 'WARNING: Species \'', $item, '\' was sequenced ', (scalar keys %{$species{$item}}), ' times', "\n" if ($verbose);
                    print {*STDOUT} '#WARNING: Species \'', $item, '\' was sequenced ', (scalar keys %{$species{$item}}), ' times', "\n";
                    my $refseq;
                    foreach my $key (keys %{$species{$item}})
                    {
                        $refseq = $key if (!defined $refseq || $key =~ /^GCF/);
                        print {*STDOUT} $species{$item}{$key}, "\n" if ($all);
                    }
                    print {*STDOUT} $species{$item}{$refseq}, "\n" if (!$all && defined $refseq);
                }
                else { print {*STDOUT} $species{$item}{(keys %{$species{$item}})[0]}, "\n"; }
            }
        }
        if ($verbose)
        {
            print {*STDERR} '# ', scalar keys %species, ' genome', (keys %species > 1 ? q{s} : q{}), "\n";
            foreach my $item (sort keys %species)
            {
                my $skip = 0;
                foreach my $exclude (@ignore)
                {
                    if (lc $exclude eq lc $item) { $skip = 1; last; }
                }
                print {*STDERR} $item, "\n" if (!$skip);
            }
        }
    }
}

#./import_genomes.pl --query "(Vertebrata[Organism]) NOT Tetrapoda[Organism] AND (latest[filter] AND all[filter] NOT anomalous[filter])" -v > imported.sh
#./import_genomes.pl -a --query "txid78156[Organism:exp]" -out 'ascomyctes.index' -v > download.sh
#./import_genomes.pl -r -a --query "txid78156[Organism:exp]" -out 'ascomyctes.index' -v > download_remap.sh
#./import_genomes.pl --xml assembly_fishes.xml -e "Gadus morhua" -e "Oreochromis niloticus" -e "Dicentrarchus labrax" -e "Oncorhynchus mykiss" -v > imported.sh
