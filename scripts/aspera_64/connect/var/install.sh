#!/bin/sh

DEBUG=1

if [ "_$1" = "_-q" ]; then
    DEBUG=0
fi

say()
{
    if [ $DEBUG -eq 1 ]; then echo $1; fi
}

INSTALL_DIR=$1

echo "Deploying Aspera Connect ($INSTALL_DIR) for the current user only."

# Create asperaconnect.path file
mkdir -p ~/.aspera/connect/etc 2>/dev/null || echo "Unable to create .aspera directory in $HOME. Aspera Connect will not work" 
echo $INSTALL_DIR/bin > $INSTALL_DIR/etc/asperaconnect.path

# Deploy mozilla plug-in
mkdir -p ~/.mozilla/plugins
cp $INSTALL_DIR/lib/libnpasperaweb.so ~/.mozilla/plugins

echo "Restart firefox manually to load the Aspera Connect plug-in"

echo
echo "Install complete."
