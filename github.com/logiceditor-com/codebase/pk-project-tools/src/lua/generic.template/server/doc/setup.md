Generic setup instructions for developer machine
================================================

Prerequisites: Ubuntu / Debian
Preferred flavor: Ubuntu Lucid 11.04 Server x86_64

Notes on server machine installation
------------------------------------

Manual server installs should be pretty much the same.

Do not install on server anything marked as "tests only"
or "developer machine only" unless you know what you're doing.

Algorythm below must be processed once, after that one must use

    bin/make.sh <your-cluster-name>

or

    bin/deploy-rocks deploy_from_code <your-cluster-name>  2>&1 \
      | tee ~/deploy.<your-cluster-name>."$(date '+%y.%m.%d_%T')".log

commands.

APT-packages
------------

1. Generic

1.1.1 Enable iphonestudio repository

    wget -q http://ubuntu.iphonestudio.ru/key.asc -O- | sudo apt-key add -

    echo "deb http://ubuntu.iphonestudio.ru unstable main" \
      | sudo tee -a /etc/apt/sources.list.d/ubuntu.iphonestudio.ru.list

Check if iphonestudio repository is really enabled.

    apt-cache policy | grep iphonestudio

'ubuntu.iphonestudio.ru' must be listed in the output. If it isn't, repeat
commands above.

    sudo apt-get update
    sudo apt-get upgrade

1.1.2 Enable developer iphonestudio repository (developer machine only).

    echo "deb http://ubuntu-dev.iphonestudio.ru unstable main" \
      | sudo tee -a /etc/apt/sources.list.d/ubuntu-dev.iphonestudio.ru.list

Check if developer iphonestudio repository is really enabled.

    apt-cache policy | grep iphonestudio

'ubuntu-dev.iphonestudio.ru' must be listed in the output. If it isn't, repeat
commands above.

    sudo apt-get update
    sudo apt-get upgrade

1.2. Install packages

    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install    \
        build-essential     \
        libreadline-dev     \
        liblua5.1-dev       \
        lua5.1              \
        libfcgi-dev         \
        spawn-fcgi          \
        unzip               \
        zip                 \
        uuid-dev            \
        runit               \
        ntp                 \
        bc                  \
        libzmq-dev          \
        luajit              \
        luarocks            \
        luarocks-dev        \
        multiwatch          \
        redis-server        \
        libev-dev           \
        libgeoip-dev        \
        libexpat-dev        \
        libcurl4-gnutls-dev \
        nginx               \
        libmysqlclient16    \
        libssl-dev          \
        openssh-server

Development machine only (documentation generation):

    sudo apt-get install    \
        pandoc
        texlive-latex-recommended \
        texlive-lang-cyrillic \
        texlive-latex-extra \

Other useful apt packages:

libwww-perl allows using GET, POST in shell

    sudo apt-get install \
        libwww-perl \
        iotop \
        dstat \
        htop

1.2.1 Ensure that you have the latest version of luarocks

    luarocks --version

Expected output:

    luarocks 2.0.7.1
    LuaRocks main command-line interface

1.2.2 Ensure that luarocks is installed in /usr/bin/luarocks

    which luarocks

Expected output:

    /usr/bin/luarocks

2. Ensure that machine is in Europe/Moscow timezone.

    sudo dpkg-reconfigure tzdata

3. Install modern git (unless provided by distribution)

Git:

    sudo apt-get install python-software-properties
    sudo add-apt-repository ppa:git-core/ppa
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install git-core git-doc

4. Setup git config

This is single package, that does not belong to iphonestudio repository,
because official git repository has new versions very often and it is reasonable
to have them ASAP.

    git config --global user.name "Your Name"
    git config --global user.email "yourname@example.com"

Additional recommended settings:

    git config --global rerere.enabled true
    git config --global color.diff auto
    git config --global color.interactive auto
    git config --global color.status auto

5. Ensure that the sudo is passwordless for your user

    sudo visudo

Add this string, using your user name
    user_name ALL=(ALL) NOPASSWD: ALL

or change group admin to NOPASSWD: ALL, if you are in that group
    %admin ALL=(ALL) NOPASSWD: ALL
--[[BLOCK_START:MYSQL_BASES]]

6. Install MySQL (developer machine only).

    sudo apt-get install mysql-server

Set the root password to 12345
--[[BLOCK_END:MYSQL_BASES]]

Minimal software versions
-------------------------

Ensure that you have at least:

* libev-dev 3.9+
* redis-server 2.2.14+
* multiwatch 1.0.0+
* luajit 2 beta 8+

Hosts
-----

Developer machine only

Add this to /etc/hosts (developer machine only!):

    #{IP_ADDRESS}1 #{PROJECT_NAME}-internal-config
    #{IP_ADDRESS}2 #{PROJECT_NAME}-internal-config-deploy
--[[BLOCK_START:API_NAME]]
    #{IP_ADDRESS}#{API_NAME_IP} #{PROJECT_NAME}-#{URLIFY(API_NAME)}
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
    #{IP_ADDRESS}#{JOINED_WSAPI_IP} #{PROJECT_NAME}-#{URLIFY(JOINED_WSAPI)}
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:STATIC_NAME]]
    #{IP_ADDRESS}#{STATIC_NAME_IP} #{PROJECT_NAME}-#{STATIC_NAME}-static
--[[BLOCK_END:STATIC_NAME]]

Also add aliases to localhost (developer machine only!):

--[[BLOCK_START:REDIS_BASE_HOST]]
    127.0.0.1 #{REDIS_BASE_HOST}
--[[BLOCK_END:REDIS_BASE_HOST]]

--[[BLOCK_START:MYSQL_BASES]]

DB initialization
-----------------

1. Set MySQL root password to 12345

    sudo /usr/bin/mysql_secure_installation

2. Create main databases

    mysql -uroot -p <<< '
    create database `#{PROJECT_NAME}`;
    '

3. Create main and deploy user (not necessary at developer machine, but necessary at test machine)

    mysql -uroot -p <<< 'CREATE USER "#{PROJECT_NAME}-main"@"localhost" IDENTIFIED BY "some_pass";'
    mysql -uroot -p <<< 'CREATE USER "#{PROJECT_NAME}-depl"@"localhost" IDENTIFIED BY "some_pass";'

4. Initialize databases - MUST BE DONE AFTER PROJECT HAS BEEN DEPLOYED FIRST TIME

    cd ~/projects/#{PROJECT_NAME}/server/backoffice/database/bin
    ./#{PROJECT_NAME}-backoffice-initialize-db
--[[BLOCK_END:MYSQL_BASES]]

Install project
---------------

1. Clone server code Git to ${HOME}/projects/#{PROJECT_NAME}

    mkdir -p ${HOME}/projects/#{PROJECT_NAME}
    cd ${HOME}/projects/#{PROJECT_NAME}
    git clone gitolite@git.iphonestudio.ru:/#{PROJECT_NAME}/server
    git clone gitolite@git.iphonestudio.ru:/#{PROJECT_NAME}/deployment
    mkdir -p ${HOME}/projects/#{PROJECT_NAME}/logs

2. Setup Git hooks

    rm -r ${HOME}/projects/#{PROJECT_NAME}/server/.git/hooks
    ln -s ../etc/git/hooks ${HOME}/projects/#{PROJECT_NAME}/server/.git/hooks
    rm -r ${HOME}/projects/#{PROJECT_NAME}/deployment/.git/hooks
    ln -s ../etc/git/hooks ${HOME}/projects/#{PROJECT_NAME}/deployment/.git/hooks

3. Install lua-nucleo

    luarocks list lua-nucleo

If nothing found:

    cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/lua-nucleo
    sudo luarocks make rockspec/lua-nucleo-scm-1.rockspec

4. Install foreign rocks

Location of foreign rocks repository is to be used often in this step, so you
might wan to save it to variable

    FRR=${HOME}/projects/#{PROJECT_NAME}/server/lib/pk-foreign-rocks/rocks

WARNING! Always remove all installed rocks before installation!
         See list of installed rocks with

            luarocks list

         (When transforming these instructions to .deb packages,
         remove a rock being installed with --force.)

If you have rocks installed check what you miss from list. Compare

    luarocks search --source --all --only-from=${FRR} \
      | grep '^\S' | tail -n +5

and

    luarocks list | grep '^\S' | tail -n +3

by using command

    sudo luarocks install ${ROCK_NAME} --only-from=${FRR}

ON CLEAN MACHINE ONLY:

    luarocks search --source --all --only-from=${FRR} \
      | grep -v '^\s' | tail -n +5 \
      | xargs -l1  sudo luarocks install --only-from=${FRR}

5. Install libs

5.1 lua-aplicado

    luarocks list lua-aplicado

If nothing found:

    cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/lua-aplicado
    sudo luarocks make rockspec/lua-aplicado-scm-1.rockspec \
      --only-from=${FRR}

5.2 pk-core

    luarocks list pk-core

If nothing found:

    cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/pk-core
    sudo luarocks make rockspec/pk-core-engine-1.rockspec \
      --only-from=${FRR}

5.3 pk-engine

    luarocks list pk-engine

If nothing found:

    cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/pk-engine/
    sudo luarocks make rockspec/pk-engine-engine-1.rockspec \
      --only-from=${FRR}

5.4 pk-tools

    luarocks list pk-tools

If nothing found:

  $ (cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/pk-tools && lua -e 'for _, R in
    ipairs(loadfile("rockspec/pk-rocks-manifest.lua")().ROCKS) do
    print(R[1]) end' | xargs -l1 -I% sudo luarocks make %
    --only-from=../pk-foreign-rocks/rocks)

5.5 pk-test (development machine only)

    luarocks list pk-test

If nothing found:

    cd ${HOME}/projects/#{PROJECT_NAME}/server/lib/pk-test/
    sudo luarocks make rockspec/pk-test-scm-1.rockspec \
      --only-from=${FRR}

Deploying to developer machine
------------------------------

1. Figure out a cluster name for your machine.

Most likely it is localhost-<your-initials>. But ask AG.

2. Put .pub key to authorized_keys.

This command copies content of your personal .pub key to
~/.ssh/authorized_keys file:

    $ ssh-copy-id localhost

3. Check if deploy-rocks would work

This command should not crash:

    cd ${HOME}/projects/#{PROJECT_NAME}/server
    bin/deploy-rocks deploy_from_code <your-cluster-name> --dry-run

If it does not print anything, you're missing deploy-rocks rock.

4. Deploy:

    bin/deploy-rocks deploy_from_code <your-cluster-name>  2>&1 \
      | tee ~/deploy.<your-cluster-name>."$(date '+%y.%m.%d_%T')".log

YOU DONE.

Does it work?
-------------
--[[BLOCK_START:API_NAME]]

sudo su - www-data -c '/usr/bin/env \
    "PATH_INFO=/sys/info.xml" \
    "PK_CONFIG_HOST=#{PROJECT_NAME}-internal-config" "PK_CONFIG_PORT=80" \
    #{PROJECT_NAME}-#{API_NAME}.fcgi'
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]

sudo su - www-data -c '/usr/bin/env \
    "PATH_INFO=/sys/info.xml" \
    "PK_CONFIG_HOST=#{PROJECT_NAME}-internal-config" "PK_CONFIG_PORT=80" \
    #{PROJECT_NAME}-#{JOINED_WSAPI}.fcgi'
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:API_NAME]]

    GET http://#{PROJECT_NAME}-#{API_NAME}
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]

    GET http://#{PROJECT_NAME}-#{JOINED_WSAPI}
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:STATIC_NAME]]
    GET http://#{PROJECT_NAME}-#{STATIC_NAME}-static
--[[BLOCK_END:STATIC_NAME]]
#{DOES_IT_WORK}

Other useful commands
---------------------

1. Update subtrees (lib directory)

Never commit any changes for anything located in /server/lib/.
If you need to make any changes in /server/lib project - ask AG.

    cd ~/projects/server/
    bin/update-subtrees update

2. Update api handlers
--[[BLOCK_START:API_NAME]]

    bin/apigen #{API_NAME} update_handlers
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]

    bin/apigen #{JOINED_WSAPI} update_handlers
--[[BLOCK_END:JOINED_WSAPI]]

3. Generate api documentation
--[[BLOCK_START:API_NAME]]

    bin/apigen #{API_NAME} generate_documents
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]

    bin/apigen #{JOINED_WSAPI} generate_documents
--[[BLOCK_END:JOINED_WSAPI]]
