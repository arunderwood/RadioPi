#!/bin/bash

#
# This script uses and RTL-SDR stick to decode packet radio on the frequency of your choosing
#

if [ -z "${1}" ]; then
    echo "You must specify a frequency for decoding"
    exit
fi

rtl_fm -f $1M -s 22050 -p 58 - | multimon-ng -a AFSK1200 -a FSK9600 -t raw -

