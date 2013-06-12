# Install Toribio.

First, install [nixio](https://github.com/Neopallium/nixio):

    # git clone https://github.com/Neopallium/nixio.git
    # cd nixio
    # make
    # sudo make install

If you are on OpenWRT, nixio is already installed. You can also crosscompile nixio, for example `make HOST_CC="gcc -m32" CROSS=arm-linux-gnueabi-` to crosscompile for ARM.

Then, download the latest version of [Toribio](https://github.com/xopxe/Toribio). You can either get the [tarball](https://github.com/xopxe/Toribio/tarball/master) , or use git:

    # git clone git://github.com/xopxe/Toribio.git
    # cd Toribio
    # git submodule init
    # git submodule update

Finally, to use the filedev device-loader make sure you have the inotifywait program installed (on Ubuntu, do a `sudo apt-get install inotify-tools`).
