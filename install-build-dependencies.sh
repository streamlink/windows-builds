#!/usr/bin/env bash
set -e

[[ "${CI}" ]] || exit 1

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  nsis \
  imagemagick \
  inkscape

python -m pip install -U pip
python -m pip install -U --upgrade-strategy=eager -r requirements.txt
