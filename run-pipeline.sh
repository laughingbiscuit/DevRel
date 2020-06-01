#!/bin/sh

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and 
# limitations under the License.

set -e
set -x

REPORT_FAIL=
DIR="${1:-$PWD}"

rm -rf ./generated
mkdir -p ./generated/demos
mkdir -p ./generated/labs
mkdir -p ./generated/tools

echo "Running under "$DIR

echo "Checking license headers"
../tools/go/bin/addlicense -check $DIR || REPORT_FAIL=$REPORT_FAIL"LIC "

echo "Java linting"
JAVA_FILES=`find $DIR -type f -name "*.java"`
[ -z "$JAVA_FILES" ] || java -jar ../tools/java/google-java-format-1.8-all-deps.jar --dry-run --set-exit-if-changed $JAVA_FILES || REPORT_FAIL=$REPORT_FAIL"JAVA "

npm i --silent

echo "Starting markdown linting"
npx remark $DIR -f || REPORT_FAIL=$REPORT_FAIL"MD "

echo "JS linting"
APIGEE_JS_FILES=`find $DIR -type f -wholename "*resources/jsc/*.js"`
[ -z "$APIGEE_JS_FILES" ] || npx -q eslint -c .eslintrc-jsc.yml $APIGEE_JS_FILES || REPORT_FAIL=$REPORT_FAIL"JS "

NODE_JS_FILES=`find . -type f -wholename "*.js" | grep -v "resources/jsc" | grep -v "node_modules"`
[ -z "$NODE_JS_FILES" ] || npx -q eslint -c .eslintrc.yml $NODE_JS_FILES || REPORT_FAIL=$REPORT_FAIL"NODE "

if test -f "$DIR/pipeline.sh"; then
  # we are running under a single solution
  (cd $DIR && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
else
  # we are running for the entire devrel
  for D in `ls $DIR/demos`
  do
    echo "Running pipeline on /demos/"$D
    (cd ./demos/$D && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
    cp -r ./demos/$D/generated/docs ./generated/demos/$D || true
  done

  for D in `ls $DIR/labs`
  do
    echo "Running pipeline on /labs/"$D
    (cd ./labs/$D && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
    cp -r ./labs/$D/generated/docs ./generated/labs/$D || true
  done

  for D in `ls $DIR/tools`
  do
    echo "Running pipeline on /tools/"$D
    (cd ./tools/$D && ./pipeline.sh) || REPORT_FAIL=$REPORT_FAIL$D" "
    cp -r ./tools/$D/generated/docs ./generated/tools/$D || true
  done
fi

echo "Failures="$REPORT_FAIL

[ -z "$REPORT_FAIL" ] || exit 1
