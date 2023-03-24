#!/usr/bin/env bash
DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
function select_top_sets {
    perl "$DIR/select_top_sets.pl" --top="$top_n" --pattern="$pattern" --transcripts="$1/$transcript_fn" > "$out_dir/$(basename "$1")_top.fasta"
}
# DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# source optionsh.sh
# declare -A MYARGS
# parse_args $0 MYARGS "$@"
# parse_result=$?
# if [ $parse_result -ne 0 ]; then
#     if [ $parse_result -eq 101 ]; then
# 	exit 0
#     else
# 	exit $parse_result
#     fi
# fi
declare -a dirlist
transcript_fn="transcripts.fasta"
out_dir="$PWD"
top_n=10000
pattern="^.*cov_([0-9]+(?:\.[0-9]+))_g([0-9]+)_i([0-9]+)"
jobs="$(($(nproc)-1))"
while [ "$#" -gt 0 ]; do
    case "$1" in
	"-t" | "--transcripts")
	   shift;
	   transcript_fn="$1";
	   ;;
	"-n" | "--top-n")
	    shift;
	    top_n="$1"
	    ;;
	"-o" | "--out-dir")
	    shift;
	    out_dir="$1"
	    ;;
	"-p" | "--pattern")
	    shift;
	    pattern="$1"
	    ;;
	"-j" | "--jobs")
	    shift;
	    jobs="$1"
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
mkdir -p "$out_dir"
export transcript_fn
export out_dir
export top_n
export pattern
export DIR
export -f select_top_sets
parallel "-j$jobs" select_top_sets ::: "${dirlist[@]}"
