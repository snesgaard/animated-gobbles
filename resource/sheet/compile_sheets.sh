#!/bin/bash

dir=(gobbles)

compile() {
  path=$1
  i=$path.lua
  s=$path.png
  n=$path\_nmap.png
  ims=$(ls $path/*.png)
  python ../../utilities/texatlas.py $ims -i $i -s $s
  python ../../utilities/normalmap.py $s $n
}

for i in "${dir[@]}"
do
  compile $i
done
