use Bio::SeqIO;
use Array::Heap;

use strict;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use Getopt::Long;

my $TOP;
my $FILENAME;
my $PATTERN;

GetOptions("transcripts=s" => \$FILENAME,
	   "top=i" => \$TOP,
	   "pattern=s" => \$PATTERN);

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
	    $highest_coverage{$2} = $highest_coverage{$2} < $1 ? $1 : $highest_coverage{$2}
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
