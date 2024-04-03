#!/bin/sh

help_mes="
hw2.sh -i INPUT -o OUTPUT [-c csv|tsv] [-j]

Available Options:

-i: Input file to be decoded
-o: Output directory
-c csv|tsv: Output files.[ct]sv
-j: Output info.json
"

## Read options ##
while getopts i:o:c:j op; do
	#echo "${OPTIND}-th arg"
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
		if [ $c != "csv" -a $c != "tsv" ]; then
			echo "Invalid -c argument"
			echo "$help_mes"
			exit 1
		fi
		;;
	*)
		echo "$help_mes"
		exit 1
		;;
	esac
done

if [ -z $i ]; then
	echo "Please provide -i"
	echo "$help_mes"
	exit 1
fi

if [ -z $o ]; then
	echo "Please provide -o"
	echo "$help_mes"
	exit 1
fi

if [ ! -e $i ]; then
	echo "Can't find file $i"
	exit 1
fi

## Read Options End ##

## Program ##


if [ ! -d $o ]; then
	mkdir $o
fi

if [ $c = "csv" ]; then
	cout="$o/files.$c"
	echo "filename,size,md5,sha1" > $cout
elif [ $c = "tsv" ]; then
	cout="$o/files.$c"
	echo -e "filename\tsize\tmd5\tsha1" > $cout
fi

j=0
in="dc.tmp"
if [ -e $in ]; then rm $in; fi
cat $i > $in

while [ ! `yq eval .files[$j].data $in` = 'null' ]; do
	text=`yq eval .files[$j].data $in | base64 -d`
	if [ `yq eval ".files[$j].type" $in` = 'hw2' ]; then
		echo "$text" | sed -e "1,4d" >> $in
	else
		file_name=`yq eval .files[$j].name $in`	
		md5=`yq eval ".files[$j].hash.md5" $in`
		sha=`yq eval ".files[$j].hash.sha-1" $in`
		out="$o/$file_name"

		if [ -e $out ]; then
			rm $out
		fi
		echo "$text" >> $out
		size=`wc $out | tr -s '[:blank:]' | cut -d ' ' -f 4`

		if [ $c = "csv" ]; then
			echo "$file_name,$size,$md5,$sha" >> $cout
		elif [ $c = "tsv" ]; then
			echo -e "$file_name\t$size\t$md5\t$sha" >> $cout
		fi
		
	fi
	j=$(( $j+1 ))
done
rm $in

if [ ! -z $j ]; then
	name=`yq eval .name $i`
	author=`yq eval .author $i`
	date=$(date --date=@$(yq eval .date $i) --iso-8601=seconds)
	jout="$o/info.json"
	jin="j.tmp"
	echo "name: $name" > $jin
	echo "author: $author" >> $jin
	echo "date: $date" >> $jin
	yq eval -j $jin > $jout
	rm $jin
fi

## Program End ##
