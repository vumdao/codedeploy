#!/bin/bash

echo -e "Validating new flyway scripts are in-order, not duplicated, and in the right location..."
for NEW in $(git diff --name-only --diff-filter=ACR origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME $CI_COMMIT_SHA -- src/main/sql_scripts)
do
  DIR=$(dirname $NEW)
  FILE=$(basename $NEW)

  if [[ "$DIR" == *repeatable_script/integration* ]]
  then
      echo -e "\e[31mERROR\e[0m: Must not include scripts from 'repeatable_script/integration' in merge" >&2
      ! break
  fi

  if [[ "$FILE" == R* ]]
  then
    continue
  fi

  if [[ "$FILE" == V* ]]
  then
    NEWER=$(ls $DIR/V* | grep -A 1 $FILE | tail -n 1 | grep -v $FILE || true)
    if [ ! -z "$NEWER" ]
    then
      echo -e "\e[31mERROR\e[0m: There are newer flyway scripts after $NEW (out-of-order)" >&2
      echo -e "\e[31mERROR\e[0m: Newer file: $NEWER" >&2
      ! break
    fi
  fi

  BASE=$(echo $FILE | awk -F'__' '{print $1}')
  SAME=$(ls $DIR/${BASE}__* | wc -l)
  if [ "$SAME" -gt 1 ]
  then
    echo -e "\e[31mERROR\e[0m: There is already a flyway script with the same base $BASE" >&2
    echo -e "\e[31mERROR\e[0m: Duplicate file: $DIR/$FILE" >&2
    ! break
  fi

  VERSION=${BASE%_*}
  VERSION=${VERSION:1}
  VERSION_PATH=${VERSION//_/\/}
  if [[ "$DIR" != *$VERSION_PATH ]]
  then
    echo -e "\e[31mERROR\e[0m: The flyway script $FILE is in the wrong directory $DIR" >&2
    echo -e "\e[31mERROR\e[0m: Expected location: $VERSION_PATH" >&2
    ! break
  fi

done
STATUS=$?
echo -e "DONE"
exit $STATUS