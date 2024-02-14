#!/usr/bin/env perl
use Bio::SeqIO;

use strict;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use Getopt::Long;
use Pod::Usage;

=pod

=head1 NAME

count_genes.pl - count the genes in a FASTA file

=head1 SYNOPSIS

    perl count_genes.pl --transcripts TRANSCRIPTS --pattern REGEX

This script accepts a path to the FASTA file containing the transcripts. If no
path is provided, the script will read from standard input.  Optionally, the
script also takes a Perl regex for parsing the sequence header lines.

If a regular expression is provided, the capture groups are interpreted, in
order, as the k-mer coverage, gene ID, and isoform ID, though only the second is
used.

=head1 DESCRIPTION

When assembling a transcriptome from RNA-seq data, some assemblers, such as
B<SPAdes>, will produce multiple transcripts per gene. Each transcript for a
gene is referred to as an isoform. In such cases, counting the number of genes
in the assembly is not as simple as counting the number of sequences in the
FASTA file.

The purpose of this script is to count genes in a FASTA file in which each gene
may have multiple isoforms.

=head2 Sequence header regex

One can distinguish which gene a transcript belongs to by inspecting the
transcript's FASTA sequence header. Hence, this program relies on a regular
expression to parse the sequence header and extract each transcript's gene ID.

The regular expression should have at least two capture groups. The second
capture group B<must> represent the gene ID, which does not necessarily need to
be an integer.

If no regular expression is provided to the script, it will use a default
regular expression that works with the sequence headers produced by B<SPAdes>
3.1.5. The regular expression is
C<^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)>.

=head1 OPTIONS

=item B<--transcripts>=I<fasta_file>

Path to the FASTA file containing genes to count.

=item B<--pattern>=I<regex>

Regular expression for parsing gene ID from FASTA sequence headers. The second
capture group is interpreted as the gene ID. (Default:
^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+))

=item B<--help>

Print a help message and exit.

=head1 DIAGNOSTICS

This script may produce the following fatal errors:

=item Could not parse sequence header %s

One or more sequence headers of the input FASTA file could not be parsed using
the (provided) regular expression. Check that your regular expression is correct
and that all FASTA sequence headers follow the format you expect.

=head1 EXAMPLES

Count the number of genes from a file I<example.fasta>.

    perl coount_genes.pl --transcripts=example.fasta

Another way.

    perl count_genes.pl < example.fasta

Read from a gzipped FASTA file, I<example.fa.gz>.

    zcat example.fa.gz | perl count_genes.pl

If your FASTA header lines look like this:

    >gene1_isoform0

then, you could run B<count_genes.pl> like this.

    perl --transcripts=example.fasta '--pattern=()gene([0-9]+))'    

=cut

my $FILENAME;
my $PATTERN;
my $HELP;

GetOptions("transcripts=s" => \$FILENAME,
	   "pattern=s" => \$PATTERN,
	   "help|?" => \$HELP) or pod2usage(2);
if ($HELP) {
    pod2usage(1);
}

if (!defined($PATTERN)) {
    $PATTERN = "^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)";
}

my $FH;

if (defined($FILENAME)) {
    open($FH, "<", $FILENAME);
}
else {
    $FH = \*STDIN;
}

my $seq_in = Bio::SeqIO->new(-format => "fasta", -fh => $FH);

my %gene_ids;

# print STDERR "Reading sequences.\n";

while (my $seq = $seq_in->next_seq()) {
    if (($seq->id) =~ m/$PATTERN/) {
	#push(@gene_heap,  [-$1 => $seq->id]);
	$gene_ids{$2} = undef;
    }
    else {
	die "Could not parse sequence header " . $seq->id . ".";
    }
}

print ((scalar keys %gene_ids) . "\n");
