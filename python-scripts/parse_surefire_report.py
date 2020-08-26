from bs4 import BeautifulSoup
import os
import sys

def output_xml_results(xml_file):
    with open(xml_file[1]) as fp:
        y=BeautifulSoup(fp, features="xml")
        # print str(y)
        for f in y.testsuite.findAll("testcase"):
            s = "unknown"
            if f.find('failure'):
                s = "failure"
            elif f.find('error'):
                s = "error"
            else:
                s = "pass"
            if f["classname"] == f["name"] and len(xml_file) == 4:
                t = xml_file[3]
            else:
                t = str.format("{}.{}", f["classname"], f["name"])
            print str.format("{},{},{},{},{}", t, s, f["time"], xml_file[2], xml_file[1])

if __name__ == '__main__':
    output_xml_results(sys.argv)
