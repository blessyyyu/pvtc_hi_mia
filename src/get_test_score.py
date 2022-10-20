from utils.save_utils import read_pickle
import sys
import argparse

# python src/get_test_score.py --pickle_name outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task1.pkl --txt_name outputs_pkls/Baseline-words_fbank8040_LSTMAvg_task1.score

parser = argparse.ArgumentParser(description = "SpeakerNet");
parser.add_argument('--pickle_name',type=str,default='phones_outputs_pkls/Baseline-phones_fbank8020_LSTMAvg_task1.pkl',dest='pkl_name',help='Saving pickle file name')
parser.add_argument('--txt_name',type=str,default='phones_outputs_pkls/Baseline-phones_fbank8020_LSTMAvg_task1.score',dest='txt_name',help='Saving txt file name')
# parser.add_argument('--threshold',type=float,default=0.01,dest='th',help='Threshold')
args = parser.parse_args();


pkl_name = args.pkl_name
dist_name = args.txt_name
# th = args.th   
raw_pkl = read_pickle(pkl_name)
count = 0
sum_item = 0
f1 = open(dist_name,"w")

y = raw_pkl["y"]
scores = raw_pkl["scores"]
keys = raw_pkl["keys"]
times = raw_pkl["time"]

items = zip(y, scores, keys,times)
items = sorted(items, key=lambda i:i[1], reverse=True)
for index, item in enumerate(items):
    f1.writelines(item[2] + " " + str(item[1]) + " " + str(item[3]) + "\n")


# for index,utt in enumerate(raw_pkl["keys"]):
#     scores = raw_pkl["scores"][index]
#     # if scores > th:
#     #     judge = "trigger"
#     # else:
#     #     judge = "non-trigger"
#     f1.writelines(utt + " " + str(scores) + " " + str(raw_pkl["time"][index]) + "\n")
f1.close()

