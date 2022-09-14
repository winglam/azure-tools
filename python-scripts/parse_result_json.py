# Outputs for all result file in a directory what tests are NO and OD
# Usage: for f in $( find ~/idflakies-result/ -type d -name "results" ); do dir=$(echo $f | rev | cut -d'/' -f2- | rev );  python3 parse_result_json.py $dir > idf-result.csv; done
# for f in $( find ~/idflakies-result/ -name idf-result.csv  ); do dir=$(echo $f | cut -d'/' -f5- | rev | cut -d'/' -f2- | rev); line=$(head -2 /logs/results/idflakies/test4/$dir/slurm.out | tail -1); head=$(echo $line | cut -d, -f-3); mod=$(echo $line | cut -d, -f6); for g in $(grep ,OD, $f | cut -d, -f1 ); do class=$(echo $g | rev | cut -d'.' -f2- | rev); name=$(echo $g | rev | cut -d'.' -f1 | rev); echo $head,$class\#$name,,$mod ; done done > all-idflakies-od.csv

import json
import os
import sys

def formatname(t):
    k = t.rfind(".")
    new_string = t[:k] + "#" + t[k+1:]
    return new_string

def output_file(testname, intended, intendedR, order):
    with open(str.format("{}-{}-{}.txt", testname, order, intendedR), 'w') as the_file:
        for t in intended:
            the_file.write(str.format("{}\n", formatname(t)))
        the_file.write(str.format("{}\n", formatname(testname)))

def init_list(listt, test):
    if (test not in listt.keys()):
        listt[test] = list()
        
def main(jsondir):
    passt = dict()
    failt = dict()
    skipt = dict()
    suboToO = dict()
    for jsonfile in os.listdir(jsondir):
        jsonfull = os.path.join(jsondir,jsonfile)
        if not os.path.isfile(jsonfull):
            continue;
        with open(jsonfull) as f:
            data = json.load(f)
            for test in data['results']:
                if test not in data['testOrder']: # skipped tests sometimes do not show in test order
                    continue
                tindex = data['testOrder'].index(test)
                hashv = hash(','.join(data['testOrder'][0:tindex]))
                init_list(suboToO, hashv)
                suboToO[hashv].append(jsonfull)
                if data['results'][test]['result'] == "PASS":
                    init_list(passt,test)
                    passt[test].append(hashv)
                elif data['results'][test]['result'] == "SKIPPED":
                    init_list(skipt,test)
                    skipt[test].append(hashv)
                else:
                    init_list(failt,test)
                    failt[test].append(hashv)
    #print(passt)
    # print(failt)
    # print(skipt)

    tests = set.union(set(passt.keys()), set(failt.keys()), set(skipt.keys()))
    print (str.format("test,od_type,num_pass,num_fail,num_skip,pass_order,fail_order"))
    for test in tests:
        if test in passt and  test in failt:
            passo = set(passt[test])
            failo = set(failt[test])
            inters= list(passo.intersection(failo))

            if len(inters) != 0:
                ttype = "NO"
                passOrder = ';'.join(suboToO[inters[0]])
                failOrder =  "see_pass_order"
            else:
                ttype = "OD"
                passOrder = ';'.join(suboToO[passt[test][0]])
                failOrder = ';'.join(suboToO[failt[test][0]])

            skipc = len(skipt.get(test, set()))
            print (str.format("{},{},{},{},{},{},{}", test, ttype, len(passt[test]), len(failt[test]), skipc, passOrder, failOrder))

if __name__ == '__main__':
    main(sys.argv[1])
