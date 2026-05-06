#!/bin/bash
set -e

mkdir -p /data/.paperclip/instances/default

paperclipai onboard --yes
paperclipai run