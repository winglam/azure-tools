# Archaeology Stuff

## archaeology-maven-extension
This is the maven extension that I'm using to configure projects to use our version of surefire

## listIDFlakiesTestsAndSHAs.php
This file takes `all-flaky-idf-sha.csv` and `idf_sha_all-polluter-cleaner.csv` as input and outputs to console a list of all of the unique test names that IDF found as flaky participants, along with the IDF SHA. Save to `id_flakies_tests.csv` to go on to generateFirstLastPairs.php

## test-history-tracer
This project has a single class, `fun.jvm.archaeology.TestHistoryCrawler`, which takes in the file `id_flakies_tests.csv`, and generates files in the `testHistory` directory, one per test

## testHistory files
These files (one per test) have the format (NumberOfCommitsSinceOrigin,SHA,testNameInThisSHA). The test name follows file renames, but does not follow method renames.

## generateFirstLastPairs.php
This file takes as input all of the `testHistory` files, `all-flaky-idf-sha.csv` and `idf_sha_all-polluter-cleaner.csv` in order to find the first N SHAs that have both pairs of tests involved (victim/polluter or brittle/state-setter), and organize them into jobs to run on my cluster. A job is a SHA with a list of test pairs.
