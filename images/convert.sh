#!/bin/bash
for i in *.svg
do
convert $i -monitor -scale 16x16 -colors 128 -strip \
  $(echo $i | sed -e 's/svg/xpm/g')
done