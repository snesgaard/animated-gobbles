#!/bin/bash

dir=(gobbles)

compile() {
  path=$1
  i=$path.lua
  s=$path.png
  ims=$(ls $path/*.png)
  python ../../utilities/texatlas.py $ims -i $i -s $s
}

for i in "${dir[@]}"
do
  compile $i
done
