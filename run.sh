#!/bin/bash


stage=2

# important !!! should change to your own path
src_aishell=
src_kws=

data_aishell=data
data_kws=data/kws
data_train=$data_kws/train
data_test=$data_kws/test
data_local_dict=data/local/dict
data_url=www.openslr.org/resources/33
kws_url=www.openslr.org/resources/85

if [ $stage -le -2 ]; then
	# download hi_mia and aishell
	echo "stage -2 download and prepare kaldi type"
	cd src
    mkdir -p $data_kws

	do_train_aishell1=true
	if [ $do_train_aishell1 ];then
		echo "do train aishell1"
		local/download_and_untar.sh $src_aishell $data_url data_aishell || exit 1;
		local/download_and_untar.sh $src_aishell $data_url resource_aishell || exit 1;
	fi
	# local/kws_download_and_untar.sh $src_kws $kws_url dev.tar.gz || exit 1;
	local/kws_download_and_untar.sh $src_kws $kws_url test.tar.gz || exit 1;
	local/kws_download_and_untar.sh $src_kws $kws_url train.tar.gz || exit 1;
	# You should write your own path to this script
	local/prepare_kws.sh ${src_kws} || exit 1;
	local/aishell_data_prep.sh $src_aishell/data_aishell/wav $src_aishell/data_aishell/transcript
	cd ..
fi

if [ $stage -le -1 ];then
	cd src
	echo "stage -1 prepare for alignment"
	# kws_word="你 好 米 雅"
	for i in train dev test;do
		# awk '{print $1,"'$kws_word'"}' $data_kws/$i/wav.scp > $data_kws/$i/text
		awk '{print $1,"你 好 米 雅"}' $data_kws/$i/wav.scp > $data_kws/$i/text
		# paste -d " " < awk '{print $1}' $data_kws/$i/wav.scp < echo $kws_word > $data_kws/$i/text 
	done
	# for i in utt2spk spk2utt feats.scp cmvn.scp text wav.scp;do
	for i in utt2spk spk2utt text wav.scp;do
		cat $data_kws/train/$i $data_kws/test/$i $data_kws/dev/$i > $data_kws/$i
	done

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

if [ $stage -le 0 ];then
	echo "stage 0 copy kws data to PVTC for nnet3 to align"
	cd src
	# rm -r data/PVTC
	cp -r data/kws/train data/PVTC
	cp data/train/wav.scp data/PVTC/neg_wav.scp
	cd ..
fi

if [ $stage -le 1 ];then
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


# if [ $stage -le 1 ];then
# 	local/prepare_all.sh /PATH/official_PVTC/train /PATH/official_PVTC/train_xiaole_time_point /PATH/official_PVTC/dev /PATH/TESTSET/task1 /PATH/TESTSET/task2 || exit 1
# fi

if [ $stage -le 2 ];then
	echo "stage 2 alignment and train"
	#If the first parameter is set as false, we will provide the trained model for testing.
	local/run_kws.sh false || exit 1
fi


if [ $stage -le 4 ];then
	# 如果没有kaldi环境,这里无法执行
	cd src
	echo "stage 4 get hour of dev and test audios"
	utils/data/get_utt2dur.sh --nj 10 data/merge/dev
	utils/data/get_utt2dur.sh --nj 10 data/merge/test
	cd ..
fi


## 后面的内容与Himia项目无关

# if [ $stage -le 3 ];then
# # 6 parameters in this sh. The first `list_pretrain` needs to be created by yourself based on your pre-training data. More details can be found in ./SV_README.md
# # If you set the first `list_pretrain` to None, the pre-trained model we provided will be downloaded and used in next steps.
# # The second and third parameters should be the path of PVTC train and dev data.
# # The fourth and fifth parameters should be the path of MUSAN(SLR17) and RIRs(SLR28) noise. 
# # If the sixth parameter `whether_finetune` set as None, the finetuned model we provided will also be downloaded instead of fine-tuning on the pre-trained model.
# 	local/run_sv.sh None /PATH/official_PVTC/train /PATH/official_PVTC/dev \
#      /PATH/musan/ /PATH/RIRS_NOISES/simulated_rirs/ None || exit 1
# fi

# if [ $stage -le 4 ];then
# 	local/show_results.sh /PATH/official_PVTC/dev || exit 1
# fi

exit 0;

