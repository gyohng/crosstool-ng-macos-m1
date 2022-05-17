#!/bin/sh

set -e

# Despite some utilities provided, you'll still need
# to install some things via brew

# In order to actually build anything using ct-ng
# you'll have to use a target volume that is case-sensitive
# (create a case-sensitive image via Disk Utility and mount it)

realpath() {
    path=`eval echo "$1"`
    folder=$(dirname "$path")
    echo $(cd "$folder"; pwd)/$(basename "$path"); 
}

MYDIR=`dirname "$0"`
MYDIR=`realpath "$MYDIR"`


MENULIBPATH=`echo /opt/homebrew/Cellar/ncurses/6.*/lib`
export SED="$MYDIR/darwin-m1-utils/sed"
export LIBTOOL="$MYDIR/darwin-m1-utils/libtool"
export LIBTOOLIZE="$MYDIR/darwin-m1-utils/libtoolize"
export OBJCOPY="$MYDIR/darwin-m1-utils/objcopy"
export OBJDUMP="$MYDIR/darwin-m1-utils/objdump"
export READELF="$MYDIR/darwin-m1-utils/redelf"
export MENU_LIBS="-L$MENULIBPATH -lmenu"
export PANEL_LIBS="-L$MENULIBPATH -lpanel"
export BASH_SHELL="$MYDIR/darwin-m1-utils/bash"

export PATH="$MYDIR/darwin-m1-utils:$PATH"

if [ ! -f ./configure ]; then
    ./bootstrap

    # disable strict enforcement of GNU Awk
    $SED -i 's,\^GNU Awk\s*,,g' ./configure
fi

if [ ! -f ./Makefile ]; then
    ./configure --enable-local --with-ncurses
fi

gmake -j
