from bs4 import BeautifulSoup
import os
import sys

def output_xml_results(xml_file):
    with open(xml_file[1]) as fp:
        y=BeautifulSoup(fp, features="xml")
        for f in y.findAll("plugin"):
            ai = f.find("artifactId", recursive=False)
            v = f.find("version", recursive=False)
            if ai == None or ai.string != "maven-surefire-plugin" or v == None:
                continue

            vers = v.string
            s = vers.split(".")
            if (not s[0].isdigit()) or (not s[1].isdigit()):
                print str.format("Unknown maven surefire version {}.", vers)
                continue
            minvers = s[1]
            if len(s[1]) == 1:
                minvers = str.format("0{}", s[1])
            mmvers = float(str.format("{}.{}", s[0], minvers))

            newvers = "2.8"
            newverscomp = 2.08
            if mmvers < newverscomp:
                print str.format("Detected maven surefire version {}. Changing to {}.", vers, newvers)
                vers.replace_with(newvers)
                with open(xml_file[1], 'wb') as f:
                    f.write(y.prettify())

if __name__ == '__main__':
    output_xml_results(sys.argv)
