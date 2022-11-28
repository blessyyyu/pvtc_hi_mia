#!/bin/bash

stage=1

echo "local/run_kws.sh"

whether_train=True

if [ $whether_train ];then
# align words time index
if [ $stage -le 1 ];then
	echo "kws stage 1"
	cd ./src
	echo $PWD
	./align_nnet3_word.sh || exit 1
	cd ../
fi

# prepare keywords train set
if [ $stage -le 2 ];then
	echo "kws stage 2"
	mkdir -p data
	cd ./src
	echo $PWD
	python prepare_keyword_feats.py --ctm_file exp/nnet3_PVTC/ctm --wavfile_path data/PVTC_nopitch/wav.scp --save_dir ../data/train_feat/positive || exit 1
	cd ../
fi

# preapre negtive set
if [ $stage -le 3 ];then
	echo "kws stage 3"
	cd ./src
	python prepare_negative_feats.py --wavfile_path data/PVTC/neg_wav.scp --dest_path ../data/train_feat/negative || exit 1
	cd ../
fi


if [ $stage -le 4 ];then
	# python src/prepare_index.py --pos_feat_dir data/train_feat/positive --neg_feat_dir data/train_feat/negative --dest_dir index_words || exit 1
	python src/prepare_index_new.py --pos_feat_dir data/train_feat/positive --neg_feat_dir data/train_feat/negative --dest_dir index_words || exit 1
fi

if [ $stage -le 5 ];then
	python src/train_words_baseline.py --seed 40 --mode train --task_name Baseline-words --model_class lstm_models --model_name LSTMAvg --index_dir index_words --batch_size 128 --num_epoch 100 --lr 0.01 || exit 1
fi

output_model=outputs/train_Baseline-words_fbank8040_LSTMAvg/models/model_100

else

output_model=src/trained_kws_model

fi


if [ $stage -le 6 ];then
	python src/vad_evalu_task_gpu_n.py --test_model $output_model  --pickle_name outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task1.pkl --mode src/data/merge/dev --model_class lstm_models --model_name LSTMAvg --word_num 3 --step_size 3 --conf_size 150 --vad_mode 3 --vad_max_length 130 --vad_max_activate 0.9 || exit 1
	python src/vad_evalu_task_gpu_n.py  --test_model $output_model --pickle_name outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task2.pkl --mode src/data/merge/test --model_class lstm_models --model_name LSTMAvg --word_num 3 --step_size 3 --conf_size 150 --vad_mode 3 --vad_max_length 130 --vad_max_activate 0.9 || exit 1

fi

if [ $stage -le 7 ];then
	mkdir -p outputs_txts
	python src/get_th.py --total_hours 25.5601 --plt_name wake_dev.jpg --pkl_names outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task1.pkl --threshold_for_num_false_alarm_per_hour 1.0
	python src/get_th.py --total_hours 65.3483 --plt_name wake_test.jpg --pkl_names outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task2.pkl --threshold_for_num_false_alarm_per_hour 1.0
fi

echo "local/run_kws.sh succeeded";