use Bio::SeqIO;

use strict;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use Getopt::Long;

my $FILENAME;
my $PATTERN;

GetOptions("transcripts=s" => \$FILENAME,
	   "pattern=s" => \$PATTERN);

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
