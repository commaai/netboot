#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

docker run --rm local/pixiecore -t -d quick ubuntu focal
