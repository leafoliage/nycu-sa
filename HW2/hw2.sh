#!/bin/sh

help_mes="hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json
"

## Read options ##
while getopts :i:o:c:j op; do
    case $op in
    j)
        j=1
        ;;
    i)
        i=$OPTARG
        ;;
    o)
        o=$OPTARG
        ;;
    c)
        c=$OPTARG
        if [ "$c" != "csv" ] && [ "$c" != "tsv" ]; then
            >&2 echo "$help_mes"
            exit 1
        fi
        ;;
    *)
        echo "$help_mes" >&2 
        exit 1
        ;;
    esac
done

if [ -z "$i" ]; then
    >&2 echo "$help_mes"
    exit 1
fi

if [ -z "$o" ]; then
    >&2 echo "$help_mes"
    exit 1
fi

if [ ! -e "$i" ]; then
    >&2 echo "$help_mes"
    exit 1
fi

## Read Options End ##

## Program ##

invalid=0

if [ ! -d "$o" ]; then
    mkdir "$o"
fi

if [ "$c" = "csv" ]; then
    cout="$o/files.$c"
    echo "filename,size,md5,sha1" > "$cout"
elif [ "$c" = "tsv" ]; then
    cout="$o/files.$c"
    printf "filename\tsize\tmd5\tsha1\n" > "$cout"
fi

yml() {
    yq "$1" "$2" | sed 's/\"//g'
    #echo "$2" | yq "$1" | sed 's/\"//g'
}

md() {
    echo "$1" | md5sum
}

sha() {
    echo "$1" | sha1sum
}

proc() {

while [ -n "$*" ]; do

    k=0
    in="$1"

    while [ ! "$(yml .files[$k].data "$in")" = 'null' ]; do
        text=$(yml .files[$k].data "$in" | base64 -d)
        type=$(yml .files[$k].type "$in")
        file_name=$(yml .files[$k].name "$in") 
        md5=$(yml .files[$k].hash.md5 "$in")
        hash_sha='"sha-1"'
        sha=$(yml ".files[$k].hash.$hash_sha" "$in")
        out="$o/$file_name"

        if [ -e "$out" ]; then
            rm "$out"
        fi
        mkdir -p "$(dirname "$out")" && touch "$out"
        echo "$text" >> "$out"

        size=$(wc "$out" | tr -s '[:blank:]' | cut -d ' ' -f 4)

        if [ "$c" = "csv" ]; then
            echo "$file_name,$size,$md5,$sha" >> "$cout"
        elif [ "$c" = "tsv" ]; then
            printf "%s\t%s\t%s\t%s\n" "$file_name" "$size" "$md5" "$sha" >> "$cout"
        fi

        if [ ! "$(md "$text")" = "$md5" ] || [ ! "$(sha "$text")" = "$sha" ]; then
            invalid=$(( invalid+1))
        fi

        if [ "$type" = 'hw2' ] && [ -z "$c" ] && [ -z "$j" ]; then
            set -- "$@" "$out"
        fi
        k=$(( k+1 ))
    done

    shift 1

done

}

proc "$i"

if [ -n "$j" ]; then
    name=$(yq .name "$i")
    author=$(yq .author "$i")
    date=$(date -r "$(yq .date "$i")" -Iseconds)
    jout="$o/info.json"
    jin="j.tmp"
    echo "name: $name" > $jin
    echo "author: $author" >> $jin
    echo "date: $date" >> $jin
    yq . $jin > "$jout"
    rm "$jin"
fi

if [ ! $invalid -eq 0 ]; then
    return $invalid
fi

## Program End ##
