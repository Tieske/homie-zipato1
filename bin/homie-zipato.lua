#!/usr/bin/env lua

--- CLI script to bridge between a fixed set of Zipato devices and Homie.
-- The devices are hardcoded in the `devices.lua` file.
-- @script homie-zipato.lua

require "logging"
local copas = require "copas"
require("logging.rsyslog").copas() -- ensure copas, if rsyslog is used
local log = assert(require("logging.envconfig").set_default_logger("HOMIE_LOG"))

local mqtt_client = require "mqtt.client"
local mqtt_utils = require "homie.utils"
local json = require("cjson.safe").new()
--local pretty = require("pl.pretty").write

local device_data = require "homie-zipato1.devices"
local subscriptions = {} -- handler function indexed by topic
local requests = {} -- request-value indexed by topic

local MQTT_URI = "mqtt://synology:1883"


local zipabox_client -- mqtt client, forward declaration, will be created later

local homie_device = {
  uri = MQTT_URI,
  domain = "homie",
  broker_state = false,  -- not recovering state from broker
  id = "zipabox-homie",
  homie = "4.0.0",
  extensions = "",
  name = "Zipato Zipabox",
  nodes = {}
}
for id, device in pairs(device_data.devices) do
  local node = {
    name = id,
    type = device.type,
    properties = {}
  }
  homie_device.nodes[id] = node



  if device.state then                                                  -- a switch
    local uuid = device.state
    local command_topic = device_data.templates.set_cmd:format(uuid)
    node.properties.power = {
      name = "power",
      datatype = "boolean",
      settable = true,
      retained = true,
      default = false,
      set = function(self, value, remote)
        if remote then
          -- The value is set over the Homie protocol, so we need to send it to the Zipabox
          -- We will not update the Homie value, since an update from the Zipabox will follow
          -- and that will become the correct value on the Homie side eventually
          local ok, err = zipabox_client:publish {
            topic = command_topic,
            payload = tostring(value),
            qos = 1,
            retain = false,
          }
          if not ok then
            log:error("Error sending device '%s' command to Zipabox: %s", id, err)
          end

        else
          -- update came in from the Zipabox-listener, so we only need to update the Homie value
          return self:update(value)
        end
      end,
    }
    local handler = function(msg)
      local power = (msg.payload or {}).value
      if type(power) == "boolean" then
        homie_device.nodes[id].properties.power:set(power)
      else
        log:warn("device '%s' received bad power value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler
    requests[device_data.templates.get_cmd:format(uuid)] = "get"



    if device["current-consumption"] then                               -- a power meter as well
      local uuid = device["current-consumption"]
      node.properties["current-consumption"] =  {
        name = "consumption",
        datatype = "float",
        settable = false,
        retained = true,
        default = 0,
        unit = "watt",
      }
      local handler = function(msg)
        local consumption = tonumber((msg.payload or {}).value or "")
        if consumption then
          homie_device.nodes[id].properties["current-consumption"]:set(consumption)
        else
          log:warn("device '%s' received bad current-consumption value '%s' from Zipabox", id, msg.payload)
        end
        end
      subscriptions[device_data.templates.get_topic:format(uuid)] = handler
      subscriptions[device_data.templates.update_topic:format(uuid)] = handler
    end



  elseif device.motion then                                             -- a motion sensor
    local uuid = device.motion
    node.properties.motion =  {
      name = "motion",
      datatype = "boolean",
      settable = false,
      retained = true,
      default = false,
    }
    local handler = function(msg)
      local motion = (msg.payload or {}).value
      if type(motion) == "boolean" then
        homie_device.nodes[id].properties.motion:set(motion)
      else
        log:warn("device '%s' received bad motion value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler

    local uuid = device.humidity
    node.properties.humidity =  {
      name = "humidity",
      datatype = "float",
      settable = false,
      retained = true,
      default = 0,
      unit = "%",
    }
    local handler = function(msg)
      local humidity = tonumber((msg.payload or {}).value or "")
      if humidity then
        homie_device.nodes[id].properties.humidity:set(humidity)
      else
        log:warn("device '%s' received bad humidity value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler

    local uuid = device.luminance
    node.properties.luminance =  {
      name = "luminance",
      datatype = "float",
      settable = false,
      retained = true,
      default = 0,
      unit = "lx",
    }
    local handler = function(msg)
      local luminance = tonumber((msg.payload or {}).value or "")
      if luminance then
        homie_device.nodes[id].properties.luminance:set(luminance)
      else
        log:warn("device '%s' received bad luminance value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler

    local uuid = device.temperature
    node.properties.temperature =  {
      name = "temperature",
      datatype = "float",
      settable = false,
      retained = true,
      default = 0,
      unit = "°C",
    }
    local handler = function(msg)
      local temp = tonumber((msg.payload or {}).value or "")
      if temp then
        homie_device.nodes[id].properties.temperature:set(temp)
      else
        log:warn("device '%s' received bad temperature value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler



  elseif device.level then                                              -- a dimmer
    local uuid = device.level
    local command_topic = device_data.templates.set_cmd:format(uuid)
    node.properties.level = {
      name = "level",
      datatype = "integer",
      settable = true,
      retained = true,
      default = 0,
      unit = "%",
      format = "0:100",
      set = function(self, value, remote)
        if remote then
          -- The value is set over the Homie protocol, so we need to send it to the Zipabox
          -- We will not update the Homie value, since an update from the Zipabox will follow
          -- and that will become the correct value on the Homie side eventually
          local ok, err = zipabox_client:publish {
            topic = command_topic,
            payload = tostring(value),
            qos = 1,
            retain = false,
          }
          if not ok then
            log:error("Error sending device '%s' command to Zipabox: %s", id, err)
          end

        else
          -- update came in from the Zipabox-listener, so we only need to update the Homie value
          return self:update(value)
        end
      end,
    }
    local handler = function(msg)
      local level = tonumber((msg.payload or {}).value or "")
      if level then
        homie_device.nodes[id].properties.level:set(level)
      else
        log:warn("device '%s' received bad level value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler
    requests[device_data.templates.get_cmd:format(uuid)] = "get"



  elseif device.setpoint then                                           -- a thermostat
    local uuid = device.setpoint
    local command_topic = device_data.templates.set_cmd:format(uuid)
    node.properties.setpoint = {
      name = "setpoint",
      datatype = "integer",
      settable = true,
      retained = true,
      default = 19,
      unit = "°C",
      format = "0:30",
      set = function(self, value, remote)
        if remote then
          -- The value is set over the Homie protocol, so we need to send it to the Zipabox
          -- We will not update the Homie value, since an update from the Zipabox will follow
          -- and that will become the correct value on the Homie side eventually
          local ok, err = zipabox_client:publish {
            topic = command_topic,
            payload = tostring(value),
            qos = 1,
            retain = false,
          }
          if not ok then
            log:error("Error sending device '%s' command to Zipabox: %s", id, err)
          end

        else
          -- update came in from the Zipabox-listener, so we only need to update the Homie value
          return self:update(value)
        end
      end,
    }
    local handler = function(msg)
      local setp = tonumber((msg.payload or {}).value or "")
      if setp then
        homie_device.nodes[id].properties.setpoint:set(setp)
      else
        log:warn("device '%s' received bad setpoint value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler
    requests[device_data.templates.get_cmd:format(uuid)] = "get"

    local uuid = device.temperature
    node.properties.temperature =  {
      name = "temperature",
      datatype = "float",
      settable = false,
      retained = true,
      default = 0,
      unit = "°C",
    }
    local handler = function(msg)
      local temp = tonumber((msg.payload or {}).value or "")
      if temp then
        homie_device.nodes[id].properties.temperature:set(temp)
      else
        log:warn("device '%s' received bad temperature value '%s' from Zipabox", id, msg.payload)
      end
    end
    subscriptions[device_data.templates.get_topic:format(uuid)] = handler
    subscriptions[device_data.templates.update_topic:format(uuid)] = handler



  else
    -- unknown device
    log:error("unknown device: %s, %s", device.model, device.type)
  end
end




-- create the MQTT client to interact with the Zipabox

do
  local first_connect = true

  zipabox_client = mqtt_client.create {
    uri = MQTT_URI,
    id = "zipabox-listener",
    clean = "first",
    keep_alive = 60,
    reconnect = 30,
    version = mqtt_client.v311,
  }

  zipabox_client:on {
    connect = function(pck, self)
      if pck.rc ~= 0 then
        return -- connection failed
      end
      -- succesfully connected
      if not first_connect then
        log:info("Zipabox-listener re-connected to MQTT broker")
        return
      end
      first_connect = false
      log:info("Zipabox-listener connected to MQTT broker")

      -- subscribe to all topics
      local ok, err = mqtt_utils.subscribe_topics(zipabox_client, subscriptions, false, 60)
      if not ok then
        log:fatal("failed to subscribe to Zipabox-topics: %s", err)
        os.exit(1)
      end

      -- request all values
      local req_count = 0
      for topic, payload in pairs(requests) do
        req_count = req_count + 1
        repeat
          local ok, err = zipabox_client:publish {
            topic = topic,
            payload = payload,
            qos = 1,
            retain = false,
          }
          if not ok then
            log:error("Error sending request to Zipabox: %s, retrying in 5 seconds", err)
            copas.pause(5)
          end
        until ok
      end
      log:info("Zipabox-listener requested %d values", req_count)

    end,


    message = function(msg, self)
      -- handle received message
      self:acknowledge(msg)

      local payload = msg.payload
      if payload then
        local decoded = json.decode(payload)
        if decoded then -- only replace if decoding actually worked...
          msg.payload = decoded
        end
      end

      local handler = subscriptions[msg.topic]
      if handler then
        handler(msg)
      else
        log:warn("unknown MQTT message received: %s", msg.topic)
      end
    end,
  }
end



homie_device = assert(require("homie.device").new(homie_device))

copas(function()
  require("mqtt.loop").add(zipabox_client)
  copas.sleep(15)
  homie_device:start()
end)
