#!/bin/bash

totalsize=0 
echo '========================'
for file in "$@";
do
  if [ ! -f $file ]; then
    echo File "$file" doesnt exists.;
    exit;
  fi;
  filesize=$(stat -c%s $file)
  totalsize=$(($totalsize+$filesize))
  printf '%-12s  %+8s\n' "$(basename $file)" "$(($filesize/1024)) KB";
done
echo '========================'
printf 'Total %+16s\n' "$(($totalsize/1024)) KB";
