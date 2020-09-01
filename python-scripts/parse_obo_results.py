
import json
import os
import sys
from shutil import copy2
import operator

import re
pattern = re.compile("^round([0-9]+)+.json$")
runpattern = re.compile("^([a-z]|[-]|[0-9])+$")

def split_line(line) :
    result = line.split(",")
    return (result[0],result[1],result[2],result[3],result[4])

def add_to_dict(dicta, v, val):
    if v in dicta.keys(): 
        result = dicta[v]
    else: 
        result = []
    if val != "":
        result.append(val)
    dicta[v] = result

# io.dropwizard.logging.DefaultLoggingFactoryTest.hasADefaultLevel,pass,1.753,20,./dropwizard-logging/target/surefire-reports/TEST-io.dropwizard.logging.DefaultLoggingFactoryTest.xml
# io.dropwizard.logging.DefaultLoggingFactoryPrintErrorMessagesTest.testLogbackStatusPrinterPrintStreamIsRestoredToSystemOut,pass,0,20,./dropwizard-logging/target/surefire-reports/TEST-io.dropwizard.logging.DefaultLoggingFactoryPrintErrorMessagesTest.xml
def read_file(filepath):
    dicta = {}
    with open(filepath) as fp:
        for cnt, line in enumerate(fp):
            if line.strip() == "":
                continue
            try: 
                test, result, time, run_num, xfile = split_line(line.strip())
                if result != "pass" and result != "failure" and result != "error":
                    continue

                # The following if checks are added because these test classes can fail during initialization.
                # When that happens the test name reported by surefire gets lost so we need to custom map them back to our expected tests
                if test == "org.jboss.as.test.integration.web.sharedsession.SharedSessionTestCase.":
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.sharedsession.SharedSessionTestCase.testSharedSessionsOneEar", (result,time,run_num,xfile))
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.sharedsession.SharedSessionTestCase.testSharedSessionsDoNotInterleave", (result,time,run_num,xfile))
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.sharedsession.SharedSessionTestCase.testNotSharedSessions", (slug, sha, mod, result,time,run_num))
                elif test == "org.jboss.as.test.integration.web.jsp.taglib.external.ExternalTagLibTestCase.":
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.jsp.taglib.external.ExternalTagLibTestCase.testExternalAndInternalTagLib", (result,time,run_num,xfile))
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.jsp.taglib.external.ExternalTagLibTestCase.testExternalTagLibOnly", (result,time,run_num,xfile))
                elif test == "org.jboss.as.test.integration.web.annotationsmodule.WebModuleDeploymentTestCase.":
                    add_to_dict(dicta, "org.jboss.as.test.integration.web.annotationsmodule.WebModuleDeploymentTestCase.testSimpleBeanInjected", (result,time,run_num,xfile))
                elif test == "org.springframework.boot.logging.logback.LogbackLoggingSystemTests.initializationError":
                    add_to_dict(dicta, "org.springframework.boot.logging.logback.LogbackLoggingSystemTests.bridgeHandlerLifecycle", (result,time,run_num,xfile))
                    add_to_dict(dicta, "org.springframework.boot.logging.logback.LogbackLoggingSystemTests.loggingLevelIsPropagatedToJul", (result,time,run_num,xfile))
                    add_to_dict(dicta, "org.springframework.boot.logging.logback.LogbackLoggingSystemTests.loggingThatUsesJulIsCaptured", (result,time,run_num,xfile))
                elif test == "org.apache.hadoop.hbase.regionserver.TestSyncTimeRangeTracker.org.apache.hadoop.hbase.regionserver.TestSyncTimeRangeTracker":
                    add_to_dict(dicta, "org.apache.hadoop.hbase.regionserver.TestSyncTimeRangeTracker.testConcurrentIncludeTimestampCorrectness", (result,time,run_num,xfile))
                elif test == "org.apache.hadoop.hbase.snapshot.TestMobRestoreSnapshotHelper.org.apache.hadoop.hbase.snapshot.TestMobRestoreSnapshotHelper":
                    add_to_dict(dicta, "org.apache.hadoop.hbase.snapshot.TestMobRestoreSnapshotHelper.testRestore", (result,time,run_num,xfile))
                elif " " not in test:
                    add_to_dict(dicta, test, (result,time,run_num,xfile))
            except IndexError:
                print str.format("Malformed:{},{}", filepath, line)

    return dicta

def summarize_test_results(roundpath):
    all_dict = read_file(roundpath[1])
    v_name = roundpath[2]
    p_name = roundpath[3]

    dlen = len(all_dict.keys())
    if v_name not in all_dict.keys() and p_name not in all_dict.keys():
        print str.format("{},{},{},{},{},{},{},{},{},{},{},{}", v_name, "MVP", "", "", "", "", p_name, "", "", "", "", dlen)
    elif p_name not in all_dict.keys():
        vresult, vtime, vrun_num, vfile = all_dict[v_name][0]
        print str.format("{},{},{},{},{},{},{},{},{},{},{},{}", v_name, "MP", vresult, vtime, vrun_num, vfile, p_name, "", "", "", "", dlen)
    elif v_name not in all_dict.keys():
        presult, ptime, prun_num, pfile = all_dict[p_name][0]
        print str.format("{},{},{},{},{},{},{},{},{},{},{},{}", v_name, "MV", "", "", "", "", p_name, presult, ptime, prun_num, pfile, dlen)
    else:
        presult, ptime, prun_num, pfile = all_dict[p_name][0]
        vresult, vtime, vrun_num, vfile = all_dict[v_name][0]
        key=""
        if presult != "pass" and vresult == "pass":
            key = "PF_VP"
        elif presult == "pass" and vresult == "pass":
            key = "PP_VP"
        elif presult == "pass" and vresult != "pass":
            key = "PP_VF"
        else:
            key = "PF_VF"
        print str.format("{},{},{},{},{},{},{},{},{},{},{},{}", v_name, key, vresult, vtime, vrun_num, vfile, p_name, presult, ptime, prun_num, pfile, dlen)

if __name__ == '__main__':
    summarize_test_results(sys.argv)
