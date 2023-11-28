#!/usr/bin/env lua

-- This is a simple script to discover all devices on a Zipato Zipabox

package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

require "logging"
local copas = require "copas"
require("logging.rsyslog").copas() -- ensure copas, if rsyslog is used
local logger = assert(require("logging.envconfig").set_default_logger("HOMIE_LOG"))
logger:setLevel("INFO")


copas(function()
  local Bridge = require "homie-zipato1.discover"

  local mybox = Bridge.new {
    zipato_base = "zipato/zipabox-0107B6200D01C356",
    mqtt_uri = "mqtt://synology:1883",
    zipato_id = "zipato-bridge-listener",
  }

  assert(mybox:start())
end)
