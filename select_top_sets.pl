#!/usr/bin/env perl
use Bio::SeqIO;
use Array::Heap;

use strict;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use Getopt::Long;
use Pod::Usage;

=pod

=head1 NAME

select_top_sets.pl - select the top n genes in a FASTA file by coverage

=head1 SYNOPSIS

    perl select_top_sets.pl --transcripts TRANSCRIPTS --top TOP --pattern REGEX

Provided a path to a FASTA file, a number of top genes n to select, and,
optionally, a regular expression for parsing FASTA sequence headers, this script
outputs the top n genes of the file by coverage.


If a regular expression is provided, the capture groups are interpreted, in
order, as the coverage, gene ID, and isoform ID, but only the first two are
needed for the program to function.

=head1 DESCRIPTION

When assembling a transcriptome from RNA-seq reads, the assembler program may
compute a "coverage" value for each assembled transcript. Intuitively, the
coverage quantifies how much input data contributed to the construction of the
assembled sequence. Some assemblers, such as B<SPAdes>, put the coverage value
for a sequence in the sequence's FASTA header line.

In the example below, the coverage of the sequence is 89.957082. The gene ID is
13242, and the isoform ID is 5.

    >NODE_66210_length_748_cov_89.957082_g13242_i5
    CAAAAACTGTTACTGCTGTCTGGTAGGGATAGAGAACCATGTCACATATCCCACATAACT
    ATTACAGTCTCAATCTTCTGTTACACGAGCAGGCAGAAGTTTACATGGTTCCTGGAGACA
    ...

Some assemblers may also generate more than one transcript "isoform" per gene.
In such cases, the isoforms of a gene may have different coverage values.

The purpose of this script is to select the top I<genes> by coverage. This
script considers the coverage of a gene to be the I<maximum> coverage among its
isoforms. (This definition is somewhat arbitrary. We could alternatively
consider the coverage of a gene to be the average or minimum coverage among its
isoforms.)

The script writes to the standard output all isoforms of the top n genes by
coveerage. The parameter n is specified by providing the B<--top> option to the
script.

This script makes two passes over the input FASTA file. The first pass
identifies the top genes by k-mer coverage. The second step writes the isoforms
of those genes in FASTA format.

=head2 Sequence header regex

In order to parse a transcript's coverage and gene ID from the FASTA sequence
header, this script needs a regular expression whose capture groups correspond,
in order, to those values.

By default, this script uses a regex designed for use with assemblies produced
by B<SPAdes> 3.15.5:

    ^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)

Additional capture groups beyond the first two are ignored.

=head1 OPTIONS

=item B<--transcripts>=I<fasta_file>

Path to the FASTA file for which the top genes should be selected.

=item B<--top>=I<top_n>

How many top genes to select.

=item B<--pattern>=I<regex>

Regular expression for parsing coverage and gene ID from FASTA sequence headers.
The first capture group is interpreted as the coverage, and the second capture
group is interpreted as the gene ID. (Default:
^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+))

=head1 DIAGNOSTICS

This script may produce the following fatal errors:

=item No path provided for transcripts file.

No value for the B<--transcripts> option was detected. Make sure your command
is correct.

=item Could not parse sequence header %s

One or more sequence headers of the input FASTA file could not be parsed using
the (provided) regular expression. Check that your regular expression is correct
and that all FASTA sequence headers follow the format you expect.

=head1 EXAMPLES

Select the top 10000 genes from I<example.fasta>.

    perl select_top_sets.pl --transcripts=example.fasta --top=10000

If your FASTA header lines look like this:

    >cov10.0_gene1

then, you could run B<select_top_sets.pl> like this.

    perl --transcripts=example.fasta \
         '--pattern=cov([0-9]+(?:\.[0-9]+))_gene([0-9]+)'

=head1 BUGS

Currently, there is no way to specify a regex for sequence headers in which the
gene ID comes before the coverage. For example, this script could not parse the
following sequence header:

    >gene1_cov10.0

=cut

my $TOP;
my $FILENAME;
my $PATTERN;
my $HELP;

GetOptions("transcripts=s" => \$FILENAME,
	   "top=i" => \$TOP,
	   "pattern=s" => \$PATTERN,
	   "help|?" => \$HELP) or pod2usage(2);

if ($HELP) {
    pod2usage(1);
}

if (!defined($PATTERN)) {
    $PATTERN = "^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)";
}

$FILENAME or die("No path provided for transcripts file.");

my $FH;
open($FH, "<", $FILENAME);

my $seq_in = Bio::SeqIO->new(-format => "fasta", -fh => $FH);
my $seq_out = Bio::SeqIO->new(-format => "fasta", -fh => \*STDOUT);

my @gene_heap;
my %highest_coverage;

print STDERR "Reading sequences.\n";

while (my $seq = $seq_in->next_seq()) {
    if (($seq->id) =~ m/$PATTERN/) {
	#push(@gene_heap,  [-$1 => $seq->id]);
	if (!(exists $highest_coverage{$2})) {
	    $highest_coverage{$2} = $1
	}
	else {
	    $highest_coverage{$2} =
		$highest_coverage{$2} < $1 ? $1 : $highest_coverage{$2};
	}
    }
    else {
	die "Could not parse sequence header " . $seq->id . ".";
    }
}

while (my ($gene, $cov) = each %highest_coverage) {
    push(@gene_heap, [-$cov => $gene]);
}


print STDERR "Selecting isoforms.\n";

my %selected_genes = ();

make_heap(@gene_heap);

my $top_count = 0;

while ((defined (my $top = pop_heap(@gene_heap))) && ($top_count++ < $TOP)) {
    $selected_genes{(@{$top}[1])} = undef;
}

# for my $value (values %gene_heaps) {
#     make_heap(@{$value});
#     my $top = 0;
#     while ((defined (my $top = pop_heap(@{$value}))) && ($top++ < $TOP)) {
# 	$selected_seqs{(@{$top}[1])} = undef;
#     }
# }

seek($FH, 0, 0);

print STDERR "Writing sequences.\n";

while (my $seq = $seq_in->next_seq()) {
    if (($seq->id) =~ m/$PATTERN/) {
	#push(@gene_heap,  [-$1 => $seq->id]);
	if (exists $selected_genes{$2}) {
	    $seq_out->write_seq($seq);
	}
    }
    else {
	die "Could not parse sequence header " . $seq->id . ".";
    }
}
