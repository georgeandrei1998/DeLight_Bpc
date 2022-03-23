#!/bin/bash
# Adapted from https://github.com/facebookresearch/MIXER/blob/master/prepareData.sh

echo 'Cloning Moses github repository (for tokenization scripts)...'
git clone https://github.com/moses-smt/mosesdecoder.git ../../mosesdecoder/

echo 'Cloning Subword NMT repository (for BPE pre-processing)...'
git clone https://github.com/rsennrich/subword-nmt.git ../../subword_nmt/

SCRIPTS="/home/bmusat/Desktop/george/delight-master/mosesdecoder/scripts"
WMT_SCRIPTS="/home/bmusat/Desktop/george/delight-master/wmt16-scripts/"
REPLACE_UNICODE_PUNCT=$SCRIPTS/tokenizer/replace-unicode-punctuation.perl
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
LWR_CASE=$SCRIPTS/tokenizer/lowercase.perl
NORM_PUNC=$SCRIPTS/tokenizer/normalize-punctuation.perl
NORMALIZE_ROMANIAN=$WMT_SCRIPTS/preprocess/normalise-romanian.py
REMOVE_DIACRITICS=$WMT_SCRIPTS/preprocess/remove-diacritics.py
REM_NON_PRINT_CHAR=$SCRIPTS/tokenizer/remove-non-printing-char.perl
BPEROOT="/home/bmusat/Desktop/george/delight-master/subword_nmt/subword_nmt"
BPE_TOKENS=40000

URLS=(
    "http://data.statmt.org/wmt16/translation-task/training-parallel-ep-v8.tgz"
    "http://opus.lingfil.uu.se/download.php?f=SETIMES2/en-ro.txt.zip"
    "http://data.statmt.org/wmt16/translation-task/dev.tgz"
    "http://data.statmt.org/wmt16/translation-task/test.tgz"
)
FILES=(
    "training-parallel-ep-v8.tgz"
    "download.php?f=SETIMES2%2Fen-ro.txt.zip"
    "dev.tgz"
    "test.tgz"
)
CORPORA=(
#    "training-parallel-ep-v8/europarl-v8.ro-en"
    "clear_europarl-v8.ro-en"
#    "fast-only-ro-europarl-v8.ro-en"
#    "dict-good-clean-europarl-v8.ro-en"
    "SETIMES.en-ro"
#    "new_found_datasets/7train_good"
#    "new_found_datasets/RO-STS.mix"
#    "new_found_datasets/train.lit"
#    "new_found_datasets/setimes_lexacctrain"
#    "ted_talks_dataset_paragraphs"
#    "ted_talks_dataset"
#    "ted_talks_dataset_diff_nr_lines"
    "RO-STS.train"
    "setimes_lexacctrain"
    "Tatoeba.en-ro"
    "train.lit"
    "WMT-News.en-ro"
    "clear_TED2020.en-ro"
    "clear_TED2013.en-ro"
)

## This will make the dataset compatible to the one used in "Convolutional Sequence to Sequence Learning"
## https://arxiv.org/abs/1705.03122
#URLS[2]="http://statmt.org/wmt14/training-parallel-nc-v9.tgz"
#FILES[2]="training-parallel-nc-v9.tgz"
#CORPORA[2]="training/news-commentary-v9.de-en"
OUTDIR="/home/bmusat/Desktop/george/delight-master/wmt16_en_ro"


if [ ! -d "$SCRIPTS" ]; then
    echo "Please set SCRIPTS variable correctly to point to Moses scripts."
    exit
fi

src=en
tgt=ro
lang=en-ro
prep=$OUTDIR
tmp=$prep/tmp
orig=$prep/orig
dev=dev/newsdev2016
test=test/newstest2016

mkdir -p $orig $tmp $prep

cd $orig

for ((i=0;i<${#URLS[@]};++i)); do
    file=${FILES[i]}
    if [ -f $file ]; then
        echo "$file already exists, skipping download"
    else
        url=${URLS[i]}
        wget "$url"
        if [ -f $file ]; then
            echo "$url successfully downloaded."
        else
            echo "$url not successfully downloaded."
            exit -1
        fi
        if [ ${file: -4} == ".tgz" ]; then
            tar zxvf $file
        elif [ ${file: -4} == ".tar" ]; then
            tar xvf $file
        fi
    fi
done
cd ..

echo "pre-processing train data..."
for l in $src $tgt; do
    rm $tmp/train.tags.$lang.tok.$l
    for f in "${CORPORA[@]}"; do
        cat $orig/$f.$l | \
#            perl $REPLACE_UNICODE_PUNCT | \
            perl $LWR_CASE $l | \
            perl $NORM_PUNC $l | \
#            ../wmt16-scripts/preprocess/normalise-romanian.py | \
#            ../wmt16-scripts/preprocess/remove-diacritics.py | \
            perl $REM_NON_PRINT_CHAR | \
            perl $TOKENIZER -threads 8 -a -l $l >> $tmp/train.tags.$lang.tok.$l
    done
done

echo "pre-processing valid data..."
for l in $src $tgt; do
    if [ "$l" == "$src" ]; then
        t="src"
    else
        t="ref"
    fi
    grep '<seg id' $orig/dev/newsdev2016-enro-$t.$l.sgm | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
#    ../wmt16-scripts/preprocess/normalise-romanian.py | \
#    ../wmt16-scripts/preprocess/remove-diacritics.py | \
    perl $LWR_CASE $l | \
    perl $TOKENIZER -threads 8 -a -l $l > $tmp/valid.$l
    echo ""
done

echo "pre-processing test data..."
for l in $src $tgt; do
    if [ "$l" == "$src" ]; then
        t="src"
    else
        t="ref"
    fi
    grep '<seg id' $orig/test/newstest2016-enro-$t.$l.sgm | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" | \
#    ../wmt16-scripts/preprocess/normalise-romanian.py | \
#    ../wmt16-scripts/preprocess/remove-diacritics.py | \
    perl $LWR_CASE $l | \
    perl $TOKENIZER -threads 8 -a -l $l > $tmp/test.$l
    echo ""
done

echo "splitting train and valid..."
for l in $src $tgt; do
#    awk '{if (NR%100 == 0)  print $0; }' $tmp/train.tags.$lang.tok.$l > $tmp/valid.$l
    awk '{if (NR%100 == 0)  print $0; }' $tmp/train.tags.$lang.tok.$l > $tmp/train.$l
    awk '{if (NR%100 != 0)  print $0; }' $tmp/train.tags.$lang.tok.$l > $tmp/train.$l
done

TRAIN=$tmp/train.ro-en
BPE_CODE=$prep/code
rm -f $TRAIN
for l in $src $tgt; do
    cat $tmp/train.$l >> $TRAIN
done

echo "learn_bpe.py on ${TRAIN}..."
python $BPEROOT/learn_bpe.py -s $BPE_TOKENS < $TRAIN > $BPE_CODE

for L in $src $tgt; do
    for f in train.$L valid.$L test.$L; do
        echo "apply_bpe.py to ${f}..."
        python $BPEROOT/apply_bpe.py -c $BPE_CODE < $tmp/$f > $tmp/bpe.$f
    done
done

perl $CLEAN -ratio 1.5 $tmp/bpe.train $src $tgt $prep/train 1 250
perl $CLEAN -ratio 1.5 $tmp/bpe.valid $src $tgt $prep/valid 1 250

for L in $src $tgt; do
    cp $tmp/bpe.valid.$L $prep/valid.$L
done
for L in $src $tgt; do
    cp $tmp/bpe.test.$L $prep/test.$L
done