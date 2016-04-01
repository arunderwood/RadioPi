#!/bin/sh

#
# This rudimentary script will download the latest version of the RTL driver and build it.
#

cd /home/pi/software/rtl-sdr
git pull https://github.com/keenerd/rtl-sdr.git
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON
make
sudo make install
sudo ldconfig
