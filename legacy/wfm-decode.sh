#!/bin/bash

#
# Start decoding FM broadcast radio on the frequency specified.  Make the stream availible on port 8080
#


if [ -z "${1}" ]; then
    echo "You must specify a frequency for decoding"
    exit
fi

rtl_fm -f $1M -M fm -s 170k -A fast -r 32k -l 0 -E deemp -E dc | sox -traw -r32k -es -b16 -c1 -V1 - -tmp3 - | socat -u - TCP-LISTEN:8080

