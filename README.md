# select\_top\_genes

This is the Git repository for `select_top_genes`, a small utility that selects
the top genes from an assembled transcriptome according to their coverage. This
utility is used in a couple of my projects, so it has been separated into its
own repository.

## Requirements

This utility has been tested with the following dependencies:

* Perl 5.36.0
* Bash 5.2.15
* GNU Parallel 20221122
* Perl libraries
  * Bio::SeqIO

Other configurations likely work as well but are untested.

## Basic usage

This software is designed to work on transcriptomes assembled from RNA-seq
data. Each sequence in the assembled transcriptome (i.e., each transcript)
belongs to a single gene, but each gene may have multiple transcripts, called
"isoforms" of that gene. Additionally, every transcript is assumed to be
associated with a "coverage" value that quantifies how much of the input RNA-seq
data contributed to the assembly of the transcript. This software assumes that
the coverage and gene ID are present in the FASTA sequence header for each
transcript.

The main script is `select_top_sets.pl`. (In the name of that script, "sets"
refers to "isotig sets," which we understand as synonymous with "genes" in this
context.) `select_top_sets_all.sh` facilitates selecting the top genes for
multiple transcriptomes in parallel, and `count_genes.pl` is a related utility
that counts the number of genes in a transcriptome.

The `select_top_sets.pl` selects the top $n$ genes of an assembly according to
their ($k$-mer) coverage. We define (somewhat arbitrarily) the coverage of a
gene to be the *maximum* coverage among the gene's isoforms.

For a transcriptome assembled with a recent version of SPAdes, it is enough to
provide `select_top_sets.pl` with a path to the assembly and the number of top
genes that should be selected.

```bash
perl select_top_sets.pl --transcripts=TRANSCRIPTS --top=TOP
```

In the above example, `TRANSCRIPTS` should be replaced with a path to the
transcripts FASTA file produced by SPAdes, and `TOP` should be replaced with the
number of top genes to select.

`select_top_sets.pl` writes to standard output, so the output will need to
redirected if you want to write to a file.

`select_top_sets.pl` assumes that sequence header lines look like the one below.

```
>NODE_66210_length_748_cov_89.957082_g13242_i5
CAAAAACTGTTACTGCTGTCTGGTAGGGATAGAGAACCATGTCACATATCCCACATAACT
ATTACAGTCTCAATCTTCTGTTACACGAGCAGGCAGAAGTTTACATGGTTCCTGGAGACA
```

This is the default format for sequence headers in SPAdes 3.15.5. In the above
line, `89.957082` is the transcript's ($k$-mer) coverage. 13242 is the gene ID,
and 5 is the isoform ID. We can parse this sequence header using a regular
expression like `^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)`, which is the
default regex for `select_top_sets.pl`.

If the sequence header lines are different from those produced by SPAdes 3.15.5,
you may need to specify a different pattern for parsing the FASTA sequence
headers using the `--pattern` option. For `select_top_sets.pl`, the pattern must
have at least two capture groups. The first group captures the coverage, a
floating-point number, and the second group captures the gene ID.

For example, if the sequence header lines look like `>cov15.5gene1`, then the
regular expression `cov([0-9]+(?:\.[0-9]+))gene([0-9]+)` would be appropriate.

## Command-line usage for included scripts

### count_genes.pl

As its name suggests, this utility counts the number of genes in a FASTA file
containing an assembled transcriptome. If all genes have exactly one isoform,
the count of genes is simply the number of sequences in the file, but some
assemblers (e.g., SPAdes) may produce multiple "isoforms" per gene, making
counting the number of genes slightly more difficult.

Like [`select_top_genes.pl`](#select-top-genespl), this script accepts a path to
a FASTA file containing the transcripts and optionally accepts a Perl regular
expression for parsing sequence headers. Requirements for the regular expression
are slightly different from those of `select_top_genes.pl`&mdash;for
`count_genes.pl`, at least two capture groups are still needed, but only the
second capture group, assumed to be the gene ID, is used.

Unlike [`select_top_genes.pl`], `count_genes.pl` can read its input
transcriptome from standard input because only one pass through the file is
needed to count the number of genes.

#### Options

| Option name                           | Description                                                               | Default                                           | Required |
|---------------------------------------|---------------------------------------------------------------------------|---------------------------------------------------|----------|
| `--help`                              | Display a help message and quit.                                          |                                                   | No       |
| [`--pattern`](#pattern-count-genespl) | Perl regular expression for parsing gene IDs from FASTA sequence headers. | `^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)` | No       |
| `--transcripts`                       | Path to assembed transcriptome FASTA file for which to count genes.       |                                                   | No       |

##### pattern (`count_genes.pl`)

The `pattern` option should be a Perl regular expression for parsing the gene ID
from FASTA sequence header lines in the provided assembled transcriptome.

Two capture groups are needed, but only the second capture group is used. The
second capture group is interpreted as the gene ID. The first capture group may
capture anything, including any empty string, but the default value for this
option uses the first group to capture coverage. (This is convenient since it
allows `count_genes.pl` and `select_top_genes.pl` to use the same regex.)

### select\_top\_sets\_all.sh

This script selects the top $n$ genes from multiple input transcriptomes in
parallel. The script uses [`select_top_genes.pl`](#select-top-genespl) and GNU
Parallel, and like the former script, it accepts a regular expression for
extracting a transcript's coverage and gene ID from its FASTA sequence header.

Instead of accepting multiple transcript FASTA files, this script accepts
multiple directory names. It is assumed that the transcript FASTA files to be
processed all have the same filename but are located in different
directories. (This is a reasonable assumption for transcriptomes assembled using
SPAdes and makes writing a command slightly easier. This design also makes the
program less flexible, and it is likely the program will be changed in the
future to a list of paths to transcript files instead.) Since SPAdes names the
assembly `transcripts.fasta`, this is the default filename that
`select_top_sets_all.sh` expects.

Since `select_top_sets_all.sh` operates on multiple inputs, it does not use
standard output for writing the top genes. Instead, the script requires that an
output directory be specified as an option to the program. An input file located
at `path/to/data1/transcripts.fasta` will be output to a file named
`data1_top.fasta` in the output directory.

#### Positional arguments

| Argument name | Description                                                                                               |
|---------------|-----------------------------------------------------------------------------------------------------------|
| `DIR ...`     | Each argument is a directory containing a transcripts FASTA file (named `transcripts.fasta`, by default). |

#### Options

| Short name                       | Long name       | Description                                                                    | Default                                           | Required |
|----------------------------------|-----------------|--------------------------------------------------------------------------------|---------------------------------------------------|----------|
| `-h`                             | `--help`        | Print a help message and exit.                                                 |                                                   | No       |
| `-j`                             | `--jobs`        | Number of parallel jobs to run.                                                | `threads - 1`                                     | No       |
| `-o`                             | `--out-dir`     | Output directory in which to store top genes for each input.                   | `$PWD`                                            | No       |
| [`-p`](#pattern-select-top-sets) | `--pattern`     | Perl regular expression for extracting gene IDs from transcript FASTA headers. | `^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)` | No       |
| `-n`                             | `--top-n`       | Number of top genes to select by coverage for each input transcripts file.     | 10000                                             | No       |
| `-t`                             | `--transcripts` | Filename of transcripts file found in each directory.                          |                                                   | No       |

### select\_top\_sets.pl

This is the "main" script in this repository. The script selects the top genes
by ($k$-mer) coverage in the provided transcripts FASTA file and writes them to
the standard output.

`select_top_sets.pl` takes the coverage of a gene to be the maximum coverage
among the gene's isoforms. For example, suppose gene 10 has two isoforms. If
gene 10 isoform 0 has coverage 10.0, and gene 10 isoform 1 has coverage 10.5,
then the coverage of gene 10 is 10.5.

The script assumes that the FASTA sequence header for each transcript indicates
both the transcript's coverage and the transcript's gene ID. (It also currently
assumes that these two pieces of information are provided *in that order*, but
this may be fixed later.) `select_top_sets.pl` accepts a
[--pattern](#pattern-select-top-setspl) option that specifies a regular expression
for parsing the FASTA sequence headers. By default, the regular expression
`^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)` is used.


#### Options

| Option name                               | Description                                                                             | Default                                           | Required |
|-------------------------------------------|-----------------------------------------------------------------------------------------|---------------------------------------------------|----------|
| `--help`                                  | Display a help message and quit.                                                        |                                                   | No       |
| [`--pattern`](#pattern-select-top-setspl) | Perl regular expression for parsing coverages and gene IDs from FASTA sequence headers. | `^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)` | No       |
| `--transcripts`                           | Path to assembed transcriptome FASTA file for which to select top genes.                |                                                   | Yes      |
| `--top`                                   | Number of top genes to select.                                                          |                                                   | Yes      |

##### pattern (`select_top_sets.pl`)

The `pattern` option should be a Perl regular expression that can be used to
extract the coverage and gene ID from a FASTA sequence header in the input
transcriptome file.

The `pattern` must have at least two capture groups. The first capture group
represents the coverage, which is assumed to be a floating-point number. The
second capture group represents the gene ID, which may be any string.

Any pattern that works with this script should be compatible with
[`count_genes.pl`](#count-genespl) as well, but `count_genes.pl` has relaxed
requirements for the pattern.
