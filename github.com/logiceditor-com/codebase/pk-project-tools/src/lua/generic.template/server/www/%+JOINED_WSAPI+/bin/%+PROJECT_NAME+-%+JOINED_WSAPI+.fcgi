#! /bin/bash

set -e

ROCK=#{PROJECT_NAME}.#{JOINED_WSAPI}
PATH_TO_GENERATED=$(luarocks show --rock-dir ${ROCK})/www/#{JOINED_WSAPI}/generated

# TODO: ?! Make sure this returns a meaningful value, suitable for a filename.
#       Better make a rock per cluster machine (like cluster-config),
#       and get the name from it.
MACHINE_NODE_NAME=$(hostname)

exec pk-lua-interpreter -lluarocks.require -e "package.path=package.path..';${PATH_TO_GENERATED}/?.lua'; require('${ROCK}.run').loop('${MACHINE_NODE_NAME}')"
