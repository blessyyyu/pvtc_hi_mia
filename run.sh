#!/bin/bash


stage=2
stop_stage=2
# important !!! should change to your own path
src_aishell=/sda/yushaoqing/aishell
src_kws=/sda/yushaoqing/hi_mia

data_aishell=data
data_kws=data/kws


data_url=www.openslr.org/resources/33
kws_url=www.openslr.org/resources/85

if [ $stage -le -2 ] && [ $stop_stage -ge -2 ]; then
	# download hi_mia and aishell
	echo "stage -2 download and prepare kaldi type"
	cd src
    mkdir -p $data_kws

	# do_train_aishell1=true
	# if [ $do_train_aishell1 ];then
	# 	echo "do train aishell1"
	# 	local/download_and_untar.sh $src_aishell $data_url data_aishell || exit 1;
	# 	local/download_and_untar.sh $src_aishell $data_url resource_aishell || exit 1;
	# fi
	# local/kws_download_and_untar.sh $src_kws $kws_url dev.tar.gz || exit 1;
	# local/kws_download_and_untar.sh $src_kws $kws_url test.tar.gz || exit 1;
	# local/kws_download_and_untar.sh $src_kws $kws_url train.tar.gz || exit 1;
	
	# You should write your own path to this script
	local/prepare_kws.sh ${src_kws} || exit 1;
	local/aishell_data_prep.sh $src_aishell/data_aishell/wav $src_aishell/data_aishell/transcript
	cd ..
fi


if [ ${stage} -le -1 ] && [ ${stop_stage} -ge -1 ];then
	cd src
	echo "stage -1 prepare for alignment"
	# kws_word="你 好 米 雅"
	for i in train dev test;do
		awk '{print $1,"你 好 米 雅"}' $data_kws/$i/wav.scp > $data_kws/$i/text
	done
	for i in utt2spk spk2utt text wav.scp;do
		cat $data_kws/train/$i $data_kws/test/$i $data_kws/dev/$i > $data_kws/$i
	done
	
	# merge
	mkdir -p data/merge
	for i in train dev test;do
		mkdir -p data/merge/$i
		# for j in utt2spk spk2utt feats.scp cmvn.scp wav.scp;do
		for j in utt2spk spk2utt wav.scp;do
			cat $data_aishell/$i/$j $data_kws/$i/$j > data/merge/$i/$j
		done
		# utils/combine_data.sh data/merge/$i $data_aishell/$i $data_kws/$i
		awk '{print $1,"<GBG>"}' $data_aishell/$i/text > $data_aishell/$i/text.neg
		cat $data_aishell/$i/text.neg $data_kws/$i/text > data/merge/$i/text
		utils/fix_data_dir.sh data/merge/$i || exit 1;
	done

	awk '{print $1, 0}' $data_aishell/test/wav.scp > data/merge/negative
	awk '{print $1, 1}' $data_kws/test/wav.scp > data/merge/positive

	cat data/merge/negative data/merge/positive | sort > data/merge/label
	rm data/merge/negative
	rm data/merge/positive
	cd ..
fi



if [ $stage -le 0 ] && [ $stop_stage -ge 0 ];then
	echo "stage 0 copy kws data to PVTC for nnet3 to align"
	cd src
	# PVTC可不可以删掉？
	# rm -r data/PVTC
	cp -r data/kws/train data/PVTC
	cp data/train/wav.scp data/PVTC/neg_wav.scp
	cd ..
fi


if [ $stage -le 1 ] && [ $stop_stage -ge 1 ];then
	cd src
	echo "stage 1 prepare test dir"

	# prepare utt2label for test
	for i in train dev test;do
		awk '{print $1,"positive"}' $data_kws/$i/wav.scp > $data_kws/$i/utt2label
		awk '{print $1,"negative"}' data/$i/wav.scp > data/$i/utt2label
	done

	# combine utt2label from aishell and hi-mia
	mkdir -p data/merge
	for i in train dev test;do
		mkdir -p data/merge/$i
		# for j in utt2spk spk2utt feats.scp cmvn.scp wav.scp;do
		for j in utt2label;do
			cat $data_aishell/$i/$j $data_kws/$i/$j > data/merge/$i/$j
		done
		# prepare utt2wav for test
		cp data/merge/$i/wav.scp data/merge/$i/utt2wav
		# prepare label2int for test
		cat <<EOF > data/merge/$i/label2int
positive 1
negative 0
EOF
	done
	cd ..
fi



if [ $stage -le 2 ] && [ $stop_stage -ge 2 ];then
	echo "stage 2 alignment and train"
	#If the first parameter is set as false, we will provide the trained model for testing.
	local/run_kws.sh false || exit 1
fi


if [ $stage -le 3 ] && [ $stop_stage -ge 3 ];then
	# 如果没有kaldi环境,这里无法执行
	cd src
	echo "stage 3 get hour of dev and test audios"
	utils/data/get_utt2dur.sh --nj 10 data/merge/dev
	utils/data/get_utt2dur.sh --nj 10 data/merge/test
	cd ..
fi


exit 0;


