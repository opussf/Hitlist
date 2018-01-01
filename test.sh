#!/bin/sh
targetDir="/Applications/World of Warcraft/Interface/AddOns/Hitlist"
files="Hitlist.lua Hitlist.toc Hitlist.xml"

for f in $files 
do
diff "$targetDir/"$f $f
cp -v $f "$targetDir"
done

