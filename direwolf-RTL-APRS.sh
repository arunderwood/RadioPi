#!/bin/bash

rtl_fm -f 144.39M -s 44100 -p 58 - | direwolf -n 1 -r 44100 -b 16 -c /home/pi/configs/direwolf-rtl.conf -
