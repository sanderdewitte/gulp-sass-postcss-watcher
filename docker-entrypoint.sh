#!/usr/bin/env bash

set -e

WATCH=0
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        watch)
            WATCH=1
            shift
            ;;
        -s|--src)
            SOURCE="$2"
            shift
            shift
            ;;
        -d|--dest)
            DESTINATION="$2"
            shift
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [ $WATCH ]; then
    cd $WORK_DIR
    npm link gulp && npm link gulp-util
    gulp watch --src $SOURCE --dest $DESTINATION
fi
