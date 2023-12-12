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
local hass_config = {} -- HASS auto-discovery config indexed by topic
local hass_subscriptions = {} -- HASS subscriptions; handler func indexed by topic

local MQTT_URI = "mqtt://synology:1883"
local DOMAIN = "homie"
local HOMIE_DEVICE_ID = "zipabox-homie"


local zipabox_client -- mqtt client, forward declaration, will be created later

local homie_device = {
  uri = MQTT_URI,
  domain = DOMAIN,
  broker_state = false,  -- not recovering state from broker
  id = HOMIE_DEVICE_ID,
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
    -- HASS stuff
    local device_config = {
      unique_id = "zipato:"..id,
      name = id,
      state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/power",
      command_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/power/set",
      payload_on = "true",
      payload_off = "false",
      state_on = "true",
      state_off = "false",
      qos = 1,
      retain = false,
    }
    local config_topic = "homeassistant/switch/"..HOMIE_DEVICE_ID.."/"..id.."/config"
    hass_config[config_topic] = json.encode(device_config)



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
      -- HASS stuff
      local device_config = {
        unique_id = "zipato:"..id..":consumption",
        name = id..":consumption",
        device_class = "power",
        state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/current-consumption",
        unit_of_measurement = "W",
        suggested_display_precision = 0,
        qos = 1,
      }
      local config_topic = "homeassistant/sensor/"..HOMIE_DEVICE_ID.."/"..id..":consumption/config"
      hass_config[config_topic] = json.encode(device_config)
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
    -- HASS stuff
    local device_config = {
      unique_id = "zipato:"..id..":motion",
      name = id..":motion",
      device_class = "motion",
      payload_on = "true",
      payload_off = "false",
      state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/motion",
      qos = 1,
    }
    local config_topic = "homeassistant/binary_sensor/"..HOMIE_DEVICE_ID.."/"..id..":motion/config"
    hass_config[config_topic] = json.encode(device_config)


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
    -- HASS stuff
    local device_config = {
      unique_id = "zipato:"..id..":humidity",
      name = id..":humidity",
      device_class = "humidity",
      state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/humidity",
      unit_of_measurement = "%",
      suggested_display_precision = 0,
      qos = 1,
    }
    local config_topic = "homeassistant/sensor/"..HOMIE_DEVICE_ID.."/"..id..":humidity/config"
    hass_config[config_topic] = json.encode(device_config)


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
    local device_config = {
      unique_id = "zipato:"..id..":luminance",
      name = id..":luminance",
      device_class = "luminance",
      state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/luminance",
      unit_of_measurement = "lx",
      suggested_display_precision = 0,
      qos = 1,
    }
    local config_topic = "homeassistant/sensor/"..HOMIE_DEVICE_ID.."/"..id..":luminance/config"
    hass_config[config_topic] = json.encode(device_config)


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
    local device_config = {
      unique_id = "zipato:"..id..":temperature",
      name = id..":temperature",
      device_class = "temperature",
      state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/temperature",
      unit_of_measurement = "°C",
      suggested_display_precision = 0,
      qos = 1,
    }
    local config_topic = "homeassistant/sensor/"..HOMIE_DEVICE_ID.."/"..id..":temperature/config"
    hass_config[config_topic] = json.encode(device_config)



  elseif device.level then                                              -- a dimmer
    local uuid = device.level
    local command_topic = device_data.templates.set_cmd:format(uuid)
    local last_value = 100 -- last value set to level, so we can restore on power-on
    node.properties.level = {
      name = "level",
      datatype = "integer",
      settable = true,
      retained = true,
      default = 0,
      unit = "%",
      format = "0:100",
      set = function(self, value, remote)
        if value ~= 0 then last_value = value end
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
    -- HASS stuff
    local config_topic = "homeassistant/light/"..HOMIE_DEVICE_ID.."/"..id.."/config"
    local set_topic = "homeassistant/light/"..HOMIE_DEVICE_ID.."/"..id.."/set"
    local device_config = {
      unique_id = "zipato:"..id,
      name = id,
      brightness_state_topic = DOMAIN .. "/" .. HOMIE_DEVICE_ID .. "/" .. id .. "/level",
      brightness_scale = 100,
      brightness_command_topic = set_topic,
      command_topic = set_topic,
      on_command_type = "brightness",
      payload_on = "true",
      payload_off = "false",
      state_on = "true",
      state_off = "false",
      qos = 1,
      retain = false,
    }
    hass_config[config_topic] = json.encode(device_config)
    hass_subscriptions[set_topic] = function(msg)
      local level = tonumber((msg.payload or {}).brightness)
      if not level then
        local state = (msg.payload or {}).state
        level = state and last_value or 0
      end
      if level then
        homie_device.nodes[id].properties.level:rset(tostring(level)) -- remote set
      else
        log:warn("device '%s' received bad level value '%s' from HASS set-topic", id, msg.payload)
      end
    end


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
    -- TODO: implement HASS stuff

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
    -- TODO: implement HASS stuff



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




--- we export the devices not just to Homie, but also to the HASS format.
-- This is understood by Home Assistant (HASS), Domoticz and others.
local hass_client do
  local first_connect = true

  hass_client = mqtt_client.create {
    uri = MQTT_URI,
    id = "hass-exporter",
    clean = "first",
    keep_alive = 60,
    reconnect = 30,
    version = mqtt_client.v311,
  }
  hass_client:on {
    connect = function(pck, self)
      if pck.rc ~= 0 then
        return -- connection failed
      end
      -- succesfully connected
      if not first_connect then
        log:info("hass-exporter re-connected to MQTT broker")
        return
      end
      first_connect = false
      log:info("hass-exporter connected to MQTT broker")

      -- subscribe to all topics
      local ok, err = mqtt_utils.subscribe_topics(hass_client, hass_subscriptions, false, 60)
      if not ok then
        log:fatal("failed to subscribe to HASS set-topics: %s", err)
        os.exit(1)
      end

      -- Announce all devices
      local ok, err = mqtt_utils.publish_topics(hass_client, hass_config, 60)
      if not ok then
        log:fatal("failed to publish HASS config announcements: %s", err)
        os.exit(1)
      end
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

      local handler = hass_subscriptions[msg.topic]
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
  require("mqtt.loop").add(hass_client)
end)
