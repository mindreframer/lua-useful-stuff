#! /bin/bash

find . -name "luac.out" -exec rm -rv {} \;

/Applications/love.app/Contents/MacOS/love ./loveapp