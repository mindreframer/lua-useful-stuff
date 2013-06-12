#! /bin/bash
set -e

APIS=(
--[[BLOCK_START:API_NAME]]
    "#{API_NAME}"
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
    "#{JOINED_WSAPI}"
--[[BLOCK_END:JOINED_WSAPI]]
  )

CLUSTERS=(
--[[BLOCK_START:CLUSTER_NAME]]
    "#{CLUSTER_NAME}"
--[[BLOCK_END:CLUSTER_NAME]]
)

SERVICES=(
--[[BLOCK_START:SERVICE_NAME]]
    "#{SERVICE_NAME}"
--[[BLOCK_END:SERVICE_NAME]]
  )

CLUSTER="${1}"

API="${2}"

ROOT="${BASH_SOURCE[0]}";
if([ -h "${ROOT}" ]) then
  while([ -h "${ROOT}" ]) do ROOT=`readlink "${ROOT}"`; done
fi
ROOT=$(cd `dirname "${ROOT}"` && cd .. && pwd) # Up one level

rm -r ${HOME}/projects/#{PROJECT_NAME}/server/.git/hooks
ln -s ../etc/git/hooks ${HOME}/projects/#{PROJECT_NAME}/server/.git/hooks
rm -r ${HOME}/projects/#{PROJECT_NAME}/deployment/.git/hooks
ln -s ../etc/git/hooks ${HOME}/projects/#{PROJECT_NAME}/deployment/.git/hooks

if [ "${CLUSTER}" = "--help" ]; then
  echo "Usage: ${0} <cluster> [<api>]" >&2
  exit 1
fi

if [ -z "${CLUSTER}" ]; then
  echo "Usage: ${0} <cluster> [<api>]" >&2
  exit 1
fi

if [ -z "${CLUSTER}" ]; then
  echo "------> MAKE ALL BEGIN..."
else
  echo "------> MAKE ALL FOR ${CLUSTER} BEGIN..."
fi

echo "------> REBUILD #{PROJECT_LIBDIR} BEGIN..."
cd #{PROJECT_LIBDIR} && ./make.sh
cd ..
echo "------> REBUILD #{PROJECT_LIBDIR} END"

for cluster in ${CLUSTERS[@]} ; do
  if [ "${cluster}" = "${CLUSTERS}" ]
  then
    echo "------> REBUILD STUFF FOR ${CLUSTER} BEGIN..."
    sudo luarocks make cluster/${CLUSTER}/internal-config/rockspec/#{PROJECT_NAME}.cluster-config.${CLUSTER}-scm-1.rockspec
    sudo luarocks make cluster/${CLUSTER}/internal-config/rockspec/#{PROJECT_NAME}.internal-config.${CLUSTER}-scm-1.rockspec
    sudo luarocks make cluster/${CLUSTER}/internal-config/rockspec/#{PROJECT_NAME}.internal-config-deploy.${CLUSTER}-scm-1.rockspec
    echo "------> REBUILD STUFF FOR ${CLUSTER} END."

    for api in ${APIS[@]} ; do
      if [ -z "${API}" -o "${api}" == "${API}" ]
      then
        echo "------> GENERATE AND INSTALL ${api} BEGIN..."
        ./bin/apigen ${api} update_handlers
#        ./bin/apigen ${api} generate_documents
        sudo luarocks make www/${api}/rockspec/#{PROJECT_NAME}.${api}-scm-1.rockspec
        sudo luarocks make cluster/${CLUSTER}/localhost/rockspec/#{PROJECT_NAME}.nginx.${api}.${CLUSTER}.localhost-scm-1.rockspec
        sudo luarocks make cluster/${CLUSTER}/rockspec/#{PROJECT_NAME}.shellenv.${api}.${CLUSTER}-scm-1.rockspec
        echo "------> GENERATE AND INSTALL ${api} END."
      fi
    done
    for service in ${SERVICES[@]} ; do
      if [ -z "${API}" -o "${service}" == "${API}" ]
      then
        echo "------> INSTALL ${service} BEGIN..."
        sudo luarocks make cluster/${CLUSTER}/rockspec/#{PROJECT_NAME}.shellenv.${service}.${CLUSTER}-scm-1.rockspec
        echo "------> INSTALL ${service} END."
      fi
    done
  fi
done

echo "------> INSTALL SERVICES..."
for service in ${SERVICES[@]} ; do
  if [ -z "${API}" -o "${service}" == "${API}" ]
  then
    echo "------> INSTALL ${service} BEGIN..."
    sudo luarocks make services/${service}/rockspec/#{PROJECT_NAME}-${service}-scm-1.rockspec
    echo "------> INSTALL ${service} END."
  fi
done

echo "------> RESTARTING SERVICES..."
sudo killall -9 multiwatch ; sudo killall -9 luajit2
echo "------> DONE."
