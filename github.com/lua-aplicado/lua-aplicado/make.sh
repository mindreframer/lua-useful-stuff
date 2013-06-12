#! /bin/bash

set -e

echo "----> Creating list-exports"
etc/list-exports/list-exports list_all

echo "----> Generating rockspecs"
lua etc/rockspec/generate.lua scm-1 > rockspec/lua-aplicado-scm-1.rockspec

echo "----> Remove a rock"
sudo luarocks remove --force lua-aplicado || true
echo "----> Making rocks"
sudo luarocks make rockspec/lua-aplicado-scm-1.rockspec

case "$1" in
  --no-restart) ;; # Do nothing
  *)
    echo "----> Restarting multiwatch and LJ2"
    sudo killall multiwatch || true ; sudo killall luajit2 || true
  ;;
esac

echo "----> OK"
