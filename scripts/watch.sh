#!/usr/bin/env bash

# Perform the initial build.
make build

python -m http.server -d public &
python_pid=$!

trap 'kill ${python_pid}; exit' INT

while inotifywait --recursive \
    --event modify \
    --event create \
    --event delete \
    --event move \
    -qq \
    --exclude '^\.\/(build|public)' \
    .
do
    make build
done

wait "${python_pid}"
