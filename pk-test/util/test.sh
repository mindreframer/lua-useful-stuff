#!/bin/bash

set -e

green='\033[32m'
red='\033[31m'
restore='\033[0m'

# TODO: Test this on OS X
function cleanup() {
  # Catch and kill all child processes

  # Uncomment for useful debug info
  # echo -e "\nCLEANUP (my pid $$)"
  #ps f -o pid,pgid,comm # OS X Doesn't support f

  #echo "AAA (mypid $$)"
  #ps -o pid,pgid
  #echo "BBB"
  #ps -o pid,pgid | grep $$\$
  #echo "CCC"
  #ps -o pid,pgid | grep $$\$ | grep -v "^[ ]*$$"

  FORKPIDS=( $(ps -o pid,pgid | grep $$\$ | grep -v "^[ ]*$$" | awk '{ print $1; }') )

  # Bash concatenation magic
  SAVE_IFS=$IFS
  IFS=","
  FORKPIDS_LIST="${FORKPIDS[*]}"
  IFS=$SAVE_IFS

  # Filter out already-dead ps, two greps and awk
  FORKPIDS_ALIVE=( $(ps -o pid -p "${FORKPIDS_LIST}" | tail -n+2) ) # tail is to skip header portably

  # Bash concatenation magic
  SAVE_IFS=$IFS
  IFS=","
  FORKPIDS_ALIVE_LIST="${FORKPIDS_ALIVE[*]}"
  IFS=$SAVE_IFS

  FORKPIDS_ALIVE_STR="${FORKPIDS_ALIVE[@]}"
  if [ ! -z "${FORKPIDS_ALIVE_STR}" ]; then
    echo -e "\n${red}ERROR: UNDEAD FORKS FOUND:${restore}\n"
    ps -p "${FORKPIDS_ALIVE_LIST}"

    echo -e "\nKilling undead forks..."

    # Give them a last chance
    kill -INT "${FORKPIDS_ALIVE[@]}" || ( echo -e "${red}FAILED TO KILL -INT UNDEAD FORKS${restore}" )

    echo "Sleeping before checking again..."
    sleep 1

    FORKPIDS_STILL_ALIVE=$(ps -o pid -p "${FORKPIDS_ALIVE_LIST}" | tail -n+2) # tail is to skip header portably

    if [ ! -z "${FORKPIDS_STILL_ALIVE}" ]; then
      echo -e "${red}Killing survived undead forks with -9${restore}"
      echo "PIDs: ${FORKPIDS_STILL_ALIVE}"
      kill -9 $FORKPIDS_STILL_ALIVE || ( echo -e "${red}FAILED TO KILL -9 UNDEAD FORKS${restore}" )
      echo -e "\nDone"
    else
      echo -e "\nAll undead forks were killed"
    fi
  fi
}

function die() {
  cleanup
  exit 1
}

trap die SIGINT
trap die SIGHUP
trap die SIGTERM
trap die SIGQUIT
trap die ERR
trap cleanup EXIT

# TODO: Remove luarocks dependency?
#LUA="lua -lluarocks.require"
LUA="luajit2 -lluarocks.require"

TESTFILE=test.lua
# TESTFILE=../../etc/fork.lua # Uncomment to test undead fork protection

${LUA} ${TESTFILE} $@ && ( echo -e "${green}OK${restore}" ) || ( echo -e "${red}FAIL${restore}"; die )

# Uncomment for better debugging
#${LUA} ${TESTFILE} $@ && ( echo -e "${green}OK${restore}" ) || ( echo -e "${red}FAIL${restore}" )
#${LUA} ${TESTFILE} $@ && ( echo -e "${green}OK${restore}" ) || ( echo -e "${red}FAIL${restore}" )
#${LUA} ${TESTFILE} $@ && ( echo -e "${green}OK${restore}" ) || ( echo -e "${red}FAIL${restore}" )
