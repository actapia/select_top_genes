#!/usr/bin/env bash
# This script selects the top n genes from multiple input FASTA files parallel
# using GNU Parallel and the select_top_sets.pl script.
#
# Although select_top_sets.pl requires a path to the input FASTA file, this
# script instead takes a list of paths to directories containing FASTA files,
# which are all assumed to have the same name. Since this behavior is less
# flexible, it may be changed in the future.
#
# For a discussion of what selecting the top genes (by coverage) means, please
# see the documentation in select_top_sets.pl.
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
function select_top_sets {
    # This function wraps select_top_sets.pl, using environment variables for
    # the --top and --pattern options, $top_n and $pattern, respectively. The
    # first and only parameter to this function is the path to the directory in
    # which the transcript file is located. The name of the transcript file is
    # also an environment variable, $transcript_fn.
    #
    # The function outputs the result to a file in the the output directory,
    # specified by the $out_dir environment variable. The name of this output
    # file is the name of the directory in which the input file is found (i.e.,
    # the first argument, $1) plus "_top.fasta". For example, if the input
    # directory $1 was ../data1, which contains ../data1/$transcript_fn, then
    # the output filename would be $out_dir/data1_top.fasta.
    perl "$DIR/select_top_sets.pl" --top="$top_n" --pattern="$pattern" --transcripts="$1/$transcript_fn" > "$out_dir/$(basename "$1")_top.fasta"
}
readonly transcripts_flag="--transcripts"
readonly top_n_flag="--top-n"
readonly out_dir_flag="--out-dir"
readonly pattern_flag="--pattern"
readonly jobs_flag="--jobs"
readonly help_flag="--help"
declare -A ARG_HELP
ARG_HELP["$transcripts_flag"]="Name of transcripts files."
ARG_HELP["$top_n_flag"]="Top n genes to select."
ARG_HELP["$out_dir_flag"]="Output directory in which to store top genes for transcripts."
ARG_HELP["$pattern_flag"]="Regular expression for getting coverage values."
ARG_HELP["$jobs_flag"]="Number of parallel jobs to use."
ARG_HELP["$help_flag"]="Print this help message and exit."
declare -A METAVAR
for flag in "$transcripts_flag" "$top_n_flag" "$out_dir_flag" "$pattern_flag" \
	    "$jobs_flag"; do
    mv="${flag//[^A-Za-z]/}"   
    METAVAR["$flag"]="${mv^^}"
done
declare -A ARG_SHORT
ARG_SHORT["$transcripts_flag"]="-t"
ARG_SHORT["$top_n_flag"]="-n"
ARG_SHORT["$out_dir_flag"]="-o"
ARG_SHORT["$pattern_flag"]="-p"
ARG_SHORT["$jobs_flag"]="-j"
ARG_SHORT["$help_flag"]="-h"
declare -A REQUIRED
# No arguments are required.
declare -a dirlist
transcript_fn="transcripts.fasta"
out_dir="$PWD"
top_n=10000
pattern="^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)"
jobs="$(($(nproc)-1))"
while [ "$#" -gt 0 ]; do
    case "$1" in
	"$transcripts_flag" | "${ARG_SHORT[$transcripts_flag]}")
	   shift;
	   transcript_fn="$1";
	  ;;
	"$top_n_flag" | "${ARG_SHORT[$top_n_flag]}")
	    shift;
	    top_n="$1"
	    ;;
	"$out_dir_flag" | "${ARG_SHORT[$out_dir_flag]}")
	    shift;
	    out_dir="$1"
	    ;;
	"$pattern_flag" | "${ARG_SHORT[$pattern_flag]}")
	    shift;
	    pattern="$1"
	    ;;
	"$jobs_flag" | "${ARG_SHORT[$jobs_flag]}")
	    shift;
	    jobs="$1"
	    ;;
	"$help_flag" | "${ARG_SHORT[$help_flag]}")
	    do_help=true
	    ;;
	*)
	    if ! [ -d "$1" ]; then
		>&2 echo "Directory $1 does not exist."
		exit 1
	    fi
	    dirlist+=("$1")
	    ;;
    esac
    shift
done
if [ "$do_help" = true ]; then
    # Print help.
    printf "Usage: $0 "
    longest=0
    for arg in "${!ARG_HELP[@]}"; do
	if [[ -v "ARG_SHORT[$arg]" ]]; then
	    arg_str="${ARG_SHORT[$arg]}"
	else	    
	    arg_str="$arg"
	fi
	if [[ -v "METAVAR[$arg]" ]]; then
	    arg_str="$arg_str ${METAVAR[$arg]}"
	fi
	if ! [[ -v "REQUIRED[$arg]" ]]; then
	    arg_str="[$arg_str]"
	fi
	printf "%s " "$arg_str"
	len="${#arg}"
	if [[ -v "ARG_SHORT[$arg]" ]]; then
	    len=$((len + "${#ARG_SHORT[$arg]}" + 2))
	fi
	if [ "$len" -gt "$longest" ]; then
	    longest="$len"
	fi
    done
    longest=$((longest+3))
    echo
    echo
    echo "positional arguments:"
    printf "  %-${longest}s" "DIR1 DIR2 ..."
    echo "Directories containing transcript FASTA files."
    echo
    echo "optional arguments:"
    for arg in "${!ARG_HELP[@]}"; do
	if ! [[ -v "REQUIRED[$arg]" ]]; then
	    arg_str="$arg"
	    if [[ -v "ARG_SHORT[$arg]" ]]; then
		arg_str="${ARG_SHORT[$arg]}, $arg_str"
	    fi
	    printf "  %-${longest}s" "$arg_str"
	    echo "${ARG_HELP[$arg]}"
	fi
    done
    exit 0
fi

mkdir -p "$out_dir"
export transcript_fn
export out_dir
export top_n
export pattern
export DIR
export -f select_top_sets
if which parallel; then
    parallel "-j$jobs" select_top_sets ::: "${dirlist[@]}"
else
    for f in "${dirlist[@]}"; do
	select_top_sets "$f"
    done
fi
