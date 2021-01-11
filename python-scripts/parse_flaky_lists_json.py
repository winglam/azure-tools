# Outputs for each flaky test listed in a flaky-lists.json, the intended and revealed order
# Usage: python parse_flaky_lists_json.py tuscan-84-flaky-list-json/c2mon.c2mon-d80687b=cern.c2mon.server.elasticsearch.tag.config.TagConfigDocumentIndexerTests.reindexTagConfigDocuments_output.json

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

def main(jsonfile):
    with open(jsonfile) as f:
        data = json.load(f)

    dts = data['dts']
    print ("Parsing %s. Contains %d tests." % (jsonfile, len(dts)))

    for dt in dts:
        output_file(dt['name'], dt['intended']['order'], dt['intended']['result'], "intended")
        output_file(dt['name'], dt['revealed']['order'], dt['revealed']['result'], "revealed")

if __name__ == '__main__':
    main(sys.argv[1])
