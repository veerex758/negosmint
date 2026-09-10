#!/bin/bash
cp -r /storage/emulated/0/NegosMint/. /home/negosmint/
cd /home/negosmint
git add .
git commit -m "Update NegosMint"
git push
