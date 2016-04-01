#!/bin/sh

# Set up a port forward

ssh -R 30003:localhost:30003 -N -f -C -p 1022 radio@ec2-54-166-123-101.compute-1.amazonaws.com
