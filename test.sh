#!/usr/bin/env bash

# export HOMIE_LOG_LOGGER="rsyslog"
export HOMIE_LOG_LOGLEVEL="debug"
# export HOMIE_LOG_LOGPATTERN="%message (%source)"
# export HOMIE_LOG_RFC="rfc5424"
# export HOMIE_LOG_MAXSIZE="8000"
# export HOMIE_LOG_HOSTNAME="synology.local"
# export HOMIE_LOG_PORT="8514"
# export HOMIE_LOG_PROTOCOL="tcp"
# export HOMIE_LOG_IDENT="homiemillheat"


# LUA_PATH="./src/?/init.lua;./src/?.lua;$LUA_PATH"
# lua bin/homie-zipato.lua

docker run -it --rm \
    -e HOMIE_LOG_LOGGER \
    -e HOMIE_LOG_LOGLEVEL \
    -e HOMIE_LOG_LOGPATTERN \
    -e HOMIE_LOG_RFC \
    -e HOMIE_LOG_MAXSIZE \
    -e HOMIE_LOG_HOSTNAME \
    -e HOMIE_LOG_PORT \
    -e HOMIE_LOG_PROTOCOL \
    -e HOMIE_LOG_IDENT \
    tieske/homie-zipato:dev
