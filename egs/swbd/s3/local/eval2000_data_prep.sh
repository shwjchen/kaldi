#!/bin/bash
#

# To be run from one directory above this script.

# The input is two directory names (possibly the same) ontaining the 
# 2000 Hub5 english evaluation test set and transcripts, which are
# respectively:
#  LDC2002S09  LDC2002T43
# e.g. see
#http://www.ldc.upenn.edu/Catalog/catalogEntry.jsp?catalogId=LDC2002S09
#http://www.ldc.upenn.edu/Catalog/CatalogEntry.jsp?catalogId=LDC2002T43
#
# Example usage:
# local/eval2000_data_prep.sh /mnt/matylda2/data/HUB5_2000/ /mnt/matylda2/data/HUB5_2000/
# If you just copied the CDs directly, both directories might end with "hub5e_00".
#  [note: I'm not sure about this though, I didn't see the original CD's].
# The first directory ($sdir) contains the speech data, and the directory
#  $sdir/english/ 
# should exist.
# The second directory ($tdir) contains the transcripts, and the directory
#  $tdir/2000_hub5_eng_eval_tr
# should exist; in particular we need the file
# $tdir/2000_hub5_eng_eval_tr/reference/hub5e00.english.000405.stm
# [just change this script if you don't have this type of structure in
#  the way you unpacked it].

if [ $# -ne 2 ]; then
  echo "Usage: local/eval2000_data_prep.sh <speech-dir> <transcription-dir>"
  echo e.g. local/eval2000_data_prep.sh /mnt/matylda2/data/HUB5_2000/ /mnt/matylda2/data/HUB5_2000/
  echo See comments in the script for more details
  exit 1
fi
sdir=$1
tdir=$2
[ ! -d $sdir/english ] && echo Expecting directory $sdir/english to be present \
   && exit 1;
[ ! -d $tdir/2000_hub5_eng_eval_tr ] && echo Expecting directory $tdir/2000_hub5_eng_eval_tr to be present \
   && exit 1;

dir=data/local/eval2000
mkdir -p $dir

for x in $sdir/english/*.sph; do echo $x; done > $dir/sph.flist
awk '{name = $0; gsub(".sph$","",name); gsub(".*/","",name); print(name " " $0)}' $dir/sph.flist > $dir/sph_sides.scp

sph2pipe=`cd ../../..; echo $PWD/tools/sph2pipe_v2.5/sph2pipe`
[ ! -f $sph2pipe ] && echo "Could not find the sph2pipe program at $sph2pipe" && exit 1;

cat $dir/sph_sides.scp | awk -v sph2pipe=$sph2pipe '{printf("%s-A %s -f wav -p -c 1 %s |\n", $1, sph2pipe, $2); 
    printf("%s-B %s -f wav -p -c 2 %s |\n", $1, sph2pipe, $2);}' | \
   sort > $dir/wav_sides.scp

#cat  /mnt/matylda2/data/HUB5_2000/2000_hub5_eng_eval_tr/reference/english/*.txt | \
#  awk '/<contraction/{next;} /</{print;}'| head

# Get segments file...
#segments file format is: utt-id side-id start-time end-time, e.g.:
#sw02001-A_000098-001156 sw02001-A 0.98 11.56
pem=$sdir/english/hub5e_00.pem
[ ! -f $pem ] && echo "No such file $pem" && exit 1;
# pem file has lines like: 
#en_4156 A unknown_speaker 301.85 302.48
grep -v ';;' $pem | awk '{spk=$1"-"$2; utt=sprintf("%s_%06d-%06d",spk,$4*100,$5*100); print utt,spk,$4,$5;}' \
 | sort  > $dir/segments

# sgm file has lines like:
#en_4156 A en_4156_A 357.64 359.64 <O,en,F,en-F>  HE IS A POLICE OFFICER 
grep -v ';;' $tdir/2000_hub5_eng_eval_tr/reference/hub5e00.english.000405.stm | \
  awk '{spk=$1"-"$2; utt=sprintf("%s_%06d-%06d",spk,$4*100,$5*100); printf utt;
       for(n=7;n<=NF;n++) printf " " $n; print ""; }' | sort > $dir/text.all

# We'll use the stm file for sclite scoring.  There seem to be various errors
# in the stm file that upset hubscr.pl, and we fix them here.
cat $tdir/2000_hub5_eng_eval_tr/reference/hub5e00.english.000405.stm | \
  sed 's:((:(:'  | sed 's:<B_ASIDE>::g' | sed 's:<E_ASIDE>::g' >  $dir/stm
cp $tdir/2000_hub5_eng_eval_tr/reference/en20000405_hub5.glm  $dir/glm


# next line uses command substitution
# Just checking that the segments are the same in pem vs. stm.
! cmp <(awk '{print $1}' $dir/text.all) <(awk '{print $1}' $dir/segments) && \
   echo "Segments from pem file and stm file do not match." && exit 1;

grep -v IGNORE_TIME_SEGMENT_ $dir/text.all > $dir/text
   

        
# create an utt2spk file that assumes each conversation side is
# a separate speaker.
cat $dir/segments | awk '{print $1,$2;}' > $dir/utt2spk  
scripts/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt

dest=data/eval2000
mkdir -p $dest
for x in wav_sides.scp segments text utt2spk spk2utt stm glm; do
  cp $dir/$x $dest/$x
done


echo Data preparation and formatting completed for Eval 2000
echo "(but not MFCC extraction)"

