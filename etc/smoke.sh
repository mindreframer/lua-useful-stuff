#!/bin/bash

# Script to smoke-check benchmarks for errors

if [ -z "$1" ]; then
  echo "Usage: $0 <benchmarks>" >&2
  exit 1
fi

LUA="$(which luajit2)"
if [ -z "${LUA}" ]; then
  LUA="$(which luajit)"

  if [ -z "${LUA}" ]; then
    LUA="$(which lua)"

    if [ -z "${LUA}" ]; then
      echo "Error: luajit2, luajit and lua executables not found" >&2
      exit 1
    fi
  fi
fi

LUAC=luac

SYNTAX="${LUAC} -p"
GLOBALS="${LUAC} -o /dev/null -l"
BENCH="${LUA} bench.lua"

NUM_ITER=1
GLOBALS_TO_CACHE=`${LUA} -e 'for k in pairs(_G) do print(k) end'`

errors=""

for bench_file in $@; do
  echo "--> Checking file '${bench_file}'"

  ${SYNTAX} ${bench_file} || {
      echo "--> FAIL (syntax check)"
      errors="${errors}\n* ${bench_file}: syntax error"
      continue
    }

  # TODO: Suppress grep errors and check ${GLOBALS} error code
  bytecode_dump=`${GLOBALS} ${bench_file}` || {
      echo "--> FAIL (bytecode dump)"
      errors="${errors}\n* ${bench_file}: failed to dump bytecode"
      continue
    }

  setglobals=`echo "${bytecode_dump}" | grep SETGLOBAL`
  if [ ! -z "${setglobals}" ]; then
    echo "${setglobals}" >&2
    echo "--> FAIL (setglobal)"
    errors="${errors}\n* ${bench_file}: changes _G"
    continue
  fi

  getglobals=`echo "${bytecode_dump}" | grep GETGLOBAL`
  if [ ! -z "${getglobals}" ]; then
    # TODO: Probably the limit is too restrictive.
    #       At least allow user to "declare" some globals.
    illegal_globals=`echo "${getglobals}" | grep -v -F "${GLOBALS_TO_CACHE}"`
    if [ ! -z "${illegal_globals}" ]; then
      echo "${illegal_globals}" >&2
      echo "--> FAIL (illegal_globals)"
      errors="${errors}\n* ${bench_file}: reads undeclared globals"
      continue
    fi

    # Allowing user to access "legal" globals only in the main chunk.
    # You have to cache globals to do a proper benchmark.
    # TODO: What about global variable access benchmarks?
    uncached_globals=`echo "${bytecode_dump}" | awk 'NR==1, /^function/ { next } { print }' | grep GETGLOBAL`
    if [ ! -z "${uncached_globals}" ]; then
      echo "${uncached_globals}" >&2
      echo "--> FAIL (uncached_globals)"
      errors="${errors}\n* ${bench_file}: globals not cached in main chunk"
      continue
    fi
  fi

  methods=`${BENCH} ${bench_file} | grep '^\* ' | awk '{ print $2; }'` || {
      echo "--> FAIL (methods list exec)"
      errors="${errors}\n* ${bench_file}: methods list error or list empty"
      continue
    }

  if [ -z "${methods}" ]; then
    echo "--> FAIL (methods list)"
    errors="${errors}\n* ${bench_file}: methods list error or list empty"
    continue
  fi

  have_bad_methods=0
  for method in ${methods}; do
    echo "----> Checking method '${method}'"

    ${BENCH} ${bench_file} ${method} ${NUM_ITER} || {
        echo "----> FAIL (method run)"
        errors="${errors}\n* ${bench_file}: ${method}: method failed"
        have_bad_methods=1
        continue
      }

    echo "----> OK"
  done

  if [ $have_bad_methods == 1 ]; then
    echo "--> FAIL (method run)"
    #errors="${errors}\n* ${bench_file}: has faulty methods"
    continue
  fi

  echo "--> OK"
done

if [ ! -z "${errors}" ]; then
  echo -e "\nSmoke tests failed (see details above):" >&2
  echo -e "${errors}" >&2
  exit 2
else
  echo -e "\nAll smoke tests passed!"
fi
