#!/bin/bash
set -e
set -o errexit
set -o nounset

ROOT="${BASH_SOURCE[0]}";

if([ -h "${ROOT}" ]) then
  while([ -h "${ROOT}" ]) do ROOT=`readlink "${ROOT}"`; done
fi
ROOT=$(cd `dirname "${ROOT}"` && cd .. && pwd) # Up one level

PK_PROJECT_NAME=#{PROJECT_NAME}-lib
PK_PROJECT_PATH=${ROOT}/${PK_PROJECT_NAME}

echo "----> Generating all"

pushd "$ROOT" > /dev/null
rm -r ${PK_PROJECT_PATH}/generated/* || true

./bin/apigen #{PROJECT_LIBDIR} update_handlers

mkdir -p ${PK_PROJECT_PATH}/generated/#{PROJECT_NAME}-lib/verbatim/
cp -RP ${PK_PROJECT_PATH}/schema/verbatim/* ${PK_PROJECT_PATH}/generated/#{PROJECT_NAME}-lib/verbatim/

${PK_PROJECT_PATH}/rockspec/gen-rockspecs
cd ${ROOT} && sudo luarocks make ${PK_PROJECT_PATH}/rockspec/#{PROJECT_LIB_ROCK}-scm-1.rockspec
./bin/list-exports --config=./project-config/list-exports/#{PROJECT_LIBDIR}/config.lua --no-base-config --root="./" list_all
popd > /dev/null

echo "----> Restarting multiwatch and LJ2"
sudo killall multiwatch && sudo killall luajit2

echo "----> OK"
