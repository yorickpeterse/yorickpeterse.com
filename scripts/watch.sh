#!/usr/bin/env bash

# Perform the initial build.
make -s build

./build/release/main watch &
http_pid=$!

trap 'kill ${http_pid}; exit' INT

while inotifywait --recursive \
    --event modify \
    --event create \
    --event delete \
    --event move \
    -qq \
    --exclude '^\.\/(build|public)' \
    .
do
    make -s build
done

wait "${http_pid}"
