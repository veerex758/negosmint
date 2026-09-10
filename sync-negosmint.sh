#!/bin/bash
find /storage/emulated/0/NegosMint -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'sync-negosmint.sh' -exec cp -r {} /home/negosmint/ \;
cd /home/negosmint
git add .
git diff --cached --quiet && echo "No changes to commit." && exit 0
git commit -m "Update NegosMint"
git push
