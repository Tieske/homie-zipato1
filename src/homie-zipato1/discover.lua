--- Zipato bridge class.
--
-- An instance represents a bridge for a Zipabox 1.
--
-- @copyright Copyright (c) 2023-2023 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local Bridge = {}
Bridge._VERSION = "0.0.1"
Bridge._COPYRIGHT = "Copyright (c) 2023-2023 Thijs Schreijer"
Bridge._DESCRIPTION = "Bridge between Homie and Zipabox1"
Bridge.__index = Bridge


local copas = require("copas") -- load first to have mqtt detect Copas as the loop
local mqtt = require "mqtt"
local log = require("logging").defaultLogger()
local Zipabox = require "homie-zipato1.zipato"
local json = require("cjson.safe").new()
local homie_utils = require("homie.utils")
local pl_path = require("pl.path")
local pl_utils = require("pl.utils")


local Network = {}
Network.__index = Network



local Device = {}
Device.__index = Device
function Device:_new_state(state)
  self.state = state
end



local Endpoint = {}
Endpoint.__index = Endpoint



local ClusterEndpoint = {}
ClusterEndpoint.__index = ClusterEndpoint



local Attribute = {}
Attribute.__index = Attribute
function Attribute:_new_value(value)
  if value == json.null then
    value = {} -- convert null to empty table, so they are indexable
  end
  self.value = value
end



function Bridge.new(opts)
  assert(opts ~= Bridge, "Don't call 'new' with colon notation")
  opts = opts or {}
  local self = {}
  self.zipato_base = assert(opts.zipato_base, "expected opts.zipato_base to be a base topic, eg: 'zipato/zipabox-0107B6200D01C356'")
  self.mqtt_uri = assert(opts.mqtt_uri, "expected opts.mqtt_uri to be a URI, eg: 'mqtt://user:pass@host:port'")
  self.zipato_id = opts.zipato_id or "zipato-bridge-listener" -- the name of the mqqt client listening to the zipato side of things
  self.config_path = opts.config_path or "./" -- path where to store the configuration discovered

  setmetatable(self, Bridge)

  self.zipabox = {} -- holds all data from MQTT structure of Zipabox
  self.zipabox_request_queue = copas.queue.new { -- queue for requests to Zipabox
    name = "zipabox_requests"
  }
  self.zipabox_request_queue:add_worker(function(data)
    repeat
      -- log:info("sending request to Zipabox: %s with: %s", self.zipato_base .. "/" .. data.topic, data.value)
      local ok, err = self.mqtt_zipato:publish {
        topic = self.zipato_base .. "/" .. data.topic,
        payload = data.value,
        qos = 1,
        retain = false,
      }
      if not ok then
        log:error("Error sending request to Zipabox: %s, retrying in 5 seconds", err)
        copas.pause(5)
      end
    until ok

    copas.pause(0.1) -- wait a bit before sending next request
  end)

  return self
end



-- Request via a single topic. The topics get added to a queue to not overload the Zipabox.
-- @tparam string topic the topic to post the request to
-- @tparam[opt="get"] string|table value the value to post, if a table will be json encoded.
function Bridge:zipato_request(topic, value)
  if value == nil then
    value = "get"
  end
  if type(value) == "table" then
    value = json.encode(value)
  else
    value = tostring(value)
  end
  self.zipabox_request_queue:push({ topic = topic, value = value })
end



local zipsub = { -- zipato subscription topics
  -- request: the topic to post on to request the info
  -- response: the topic to listen on for the response, with possible keys
  -- handler: function to handle the response
  -- start: function to call when first connected
  {
    -- MQTT connection status of the Zipabox
    request = nil,
    response = {
      topic = "conn_status",
    },
    handler = function(thisbridge, payload, fields, varags)
      log:info("Zipabox status changed: %s", payload)
      thisbridge.zipabox.conn_status = payload
    end,
  }, {
    -- Base info of Zipabox
    request = "request/box/info",
    response = {
      topic = "box/info",
    },
    start = function(thisbridge)
      log:info("Zipabox properties received")
      thisbridge:zipato_request("request/box/info")
    end,
    handler = function(thisbridge, payload, fields, varags)
      thisbridge.zipabox.info = payload
    end,
  }, {
    -- Messages from Zipabox
    request = nil,
    response = {
      topic = "box/messages",
    },
    handler = function(thisbridge, payload, fields, varags)
      log:info("Zipabox message received: %s", payload)
    end,
  }, {
    -- Retrieve list of networks
    request = "request/networks/list",
    response = {
      topic = "networks/list",
    },
    start = function(thisbridge)
      thisbridge:zipato_request("request/networks/list")
    end,
    handler = function(thisbridge, payload, fields, varags)
      log:info("Zipabox network-list received: %s networks", #payload)
      if not thisbridge.zipabox.networks then
        thisbridge.zipabox.networks = {}
      end

-- -- TODO: remove this, for now leave only IP network
-- for _, network in ipairs(payload) do
--   if network.name == "IP" then
--     payload = { network }
--     break
--   end
-- end


      thisbridge.zipabox.networks.list = payload
      thisbridge.networks_expected = #payload
      thisbridge.devices_expected = 0
      thisbridge.endpoints_expected = 0
      thisbridge.clusterendpoints_expected = 0
      thisbridge.attributes_expected = 0
      thisbridge.attribute_values_expected = 0
      thisbridge.networks_found = 0
      thisbridge.devices_found = 0
      thisbridge.endpoints_found = 0
      thisbridge.clusterendpoints_found = 0
      thisbridge.attributes_found = 0
      thisbridge.attribute_values_found = 0

      -- request info from each network individually
      for _, network in ipairs(payload) do
        thisbridge:zipato_request("request/networks/" .. network.uuid .. "/info")
      end
    end,
  }, {
    -- Retrieve info of a single network
    request = "request/networks/${UUID}/info",
    response = {
      topic = "networks/+/info",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      local name = payload.config.name
      log:info("Zipabox network '%s' received, %s devices", name, #payload.devices)
      -- print("title: ", require("pl.pretty").write(payload))
      if not thisbridge.zipabox.networks then
        thisbridge.zipabox.networks = {}
      end

      thisbridge.zipabox.networks[payload.uuid] = setmetatable(payload, Network)
      thisbridge.networks_found = thisbridge.networks_found + 1
      thisbridge.devices_expected = thisbridge.devices_expected + #payload.devices

      -- request info for each device on this network individually
      for _, device in ipairs(payload.devices) do
        thisbridge:zipato_request("request/devices/" .. device.uuid .. "/info")
      end
    end,
  }, {
    request = "request/devices/${UUID}/info",
    response = {
      topic = "devices/+/info",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      local name = payload.config.name
      log:info("Zipabox device '%s' (%s) received, %s endpoints ", name, payload.network.name, #payload.endpoints)
      -- print("title: ", require("pl.pretty").write(payload))
      if not thisbridge.zipabox.devices then
        thisbridge.zipabox.devices = {}
      end

      thisbridge.zipabox.devices[payload.uuid] = setmetatable(payload, Device)
      thisbridge.devices_found = thisbridge.devices_found + 1
      thisbridge.endpoints_expected = thisbridge.endpoints_expected + #payload.endpoints

      -- add state through method
      local state = payload.state
      payload.state = nil
      payload:_new_state(state)

      -- request info for each endpoint on this device individually
      for _, endpoint in ipairs(payload.endpoints) do
        thisbridge:zipato_request("request/endpoints/" .. endpoint.uuid .. "/info")
      end
    end,
  }, {
    request = nil,
    response = {
      topic = "devices/+/status", -- unsolicited updates on "devices/+/status"
      keys = { "uuid" },
    },
    -- the "/status" object should be stored in the "/info" object with key "state"
    handler = function(thisbridge, payload, fields, varags)
      local device_uuid = payload.device
      -- print("title: ", require("pl.pretty").write(payload))
      if not (thisbridge.zipabox.devices or {})[device_uuid] then
        --log:info("Zipabox undiscovered device '%s' received state update, ignoring", device_uuid)
        return -- device not discovered yet
      end
      local device = thisbridge.zipabox.devices[device_uuid]
      log:info("Zipabox device '%s' received state update", device.config.name)
      -- call handler with updated state
      device:_new_state(payload)
    end,
  }, {
    request = "request/endpoints/${UUID}/info",
    response = {
      topic = "endpoints/+/info",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      if not thisbridge.zipabox.endpoints then
        thisbridge.zipabox.endpoints = {}
      end

      -- print("endpoint config: ", require("pl.pretty").write(payload))
      thisbridge.zipabox.endpoints[payload.uuid] = setmetatable(payload, Endpoint)
      thisbridge.endpoints_found = thisbridge.endpoints_found + 1
      thisbridge.clusterendpoints_expected = thisbridge.clusterendpoints_expected + #payload.clusterEndpoints

      -- request info for each clusterEndpoint on this endpoint individually
      for _, clusterEndpoint in ipairs(payload.clusterEndpoints) do
        thisbridge:zipato_request("request/clusterEndpoints/" .. clusterEndpoint.uuid .. "/info")
      end
    end,
  }, {
    request = "request/clusterEndpoints/${UUID}/info",
    response = {
      topic = "clusterEndpoints/+/info",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      if not thisbridge.zipabox.clusterEndpoints then
        thisbridge.zipabox.clusterEndpoints = {}
      end

      thisbridge.zipabox.clusterEndpoints[payload.uuid] = setmetatable(payload, ClusterEndpoint)
      thisbridge.clusterendpoints_found = thisbridge.clusterendpoints_found + 1
      thisbridge.attributes_expected = thisbridge.attributes_expected + #payload.attributes
      thisbridge.attribute_values_expected = thisbridge.attribute_values_expected + #payload.attributes

      -- request info for each attribute on this clusterEndpoint individually
      for _, attribute in ipairs(payload.attributes) do
        thisbridge:zipato_request("request/attributes/" .. attribute.uuid .. "/info")
      end
    end,
  }, {
    request = "request/attributes/${UUID}/info",
    response = {
      topic = "attributes/+/info",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      if not thisbridge.zipabox.attributes then
        thisbridge.zipabox.attributes = {}
      end

      thisbridge.zipabox.attributes[payload.uuid] = setmetatable(payload, Attribute)
      thisbridge.attributes_found = thisbridge.attributes_found + 1

      -- print("attribute config: ", require("pl.pretty").write(payload))
      -- request values for this attribute
      thisbridge:zipato_request("request/attributes/" .. payload.uuid .. "/getValue")
    end,
  }, {
    request = nil, -- "request/attributes/${UUID}/getValue",
    response = {
      topic = "attributes/+/value", -- unsolicited updates on "attributes/+/value"
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      local attrib_uuid = fields.uuid -- in this case grab from the topic
      -- print("attribute uuid: ", attrib_uuid)
      -- print("attribute value: ", require("pl.pretty").write(payload))
      if not (thisbridge.zipabox.attributes or {})[attrib_uuid] then
        --log:info("Zipabox undiscovered attribute '%s' received value update, ignoring", attrib_uuid)
        return -- attribute not discovered yet
      end
      -- print("attribute value: ", require("pl.pretty").write(payload))
      thisbridge.zipabox.attributes[attrib_uuid]:_new_value(payload)
    end,
  }, {
    request = "request/attributes/${UUID}/getValue",
    response = {
      topic = "attributes/+/currentValue",
      keys = { "uuid" },
    },
    handler = function(thisbridge, payload, fields, varags)
      local attrib_uuid = fields.uuid -- in this case grab from the topic
      -- print("attribute uuid: ", attrib_uuid)
      -- print("attribute value: ", require("pl.pretty").write(payload))
      if not (thisbridge.zipabox.attributes or {})[attrib_uuid] then
        --log:info("Zipabox undiscovered attribute '%s' received value update, ignoring", attrib_uuid)
        return -- attribute not discovered yet
      end

      thisbridge.attribute_values_found = thisbridge.attribute_values_found + 1
      thisbridge.zipabox.attributes[attrib_uuid]:_new_value(payload)
    end,
  }
}


-- Handles callbacks for "connect" events
function Bridge:zipato_connect_handler(connack)
  if self.first_connect then
    self.first_connect = false
    log:info("MQTT connected")
    -- subscribe to all topics
    local sub_list = {
      self.zipato_base .. "/conn_status",
      self.zipato_base .. "/box/#",
      self.zipato_base .. "/networks/#",
      self.zipato_base .. "/devices/#",
      self.zipato_base .. "/endpoints/#",
      self.zipato_base .. "/clusterEndpoints/#",
      self.zipato_base .. "/attributes/#",
    }
    local ok, err = homie_utils.subscribe_topics(self.mqtt_zipato, sub_list, false, 30)
    if not ok then
      log:error("failed subscribing to Zipabox topics: %s", err)
      return
    end
    log:info("subscribed to Zipabox topics")

    for _, sub in ipairs(zipsub) do
      if sub.start then
        sub.start(self)
      end
    end

  else
    log:info("MQTT reconnected")
  end
end

-- Handles callbacks for "message" events
function Bridge:zipato_message_handler(msg)
  local payload = msg.payload
  if payload then
    local decoded = json.decode(payload)
    if decoded then -- only replace if decoding actually worked...
      payload = decoded
    end
  end
  local topic = msg.topic
  for _, matcher in ipairs(self.handlers) do
    local fields, varargs = mqtt.topic_match(topic, matcher)
    if fields then
      log:debug("MQTT message received: %s", msg.topic)
      matcher.handler(self, payload, fields, varargs)
      return
    end
  end
  log:warn("unknown MQTT message received: %s", msg.topic)
end

function Bridge:start()
  self.mqtt_zipato = mqtt.client {
    uri = self.mqtt_uri,
    id = self.zipato_id,
    clean = "first",
    reconnect = true,
    -- will = {
    --   topic = self.base_topic .. "$state",
    --   payload = self.states.lost,
    --   qos = 1,
    --   retain = true,
    -- },
    on = {
      connect = function(connack)
        self:zipato_connect_handler(connack)
      end,
      message = function(msg)
        assert(self.mqtt_zipato:acknowledge(msg))
        self:zipato_message_handler(msg)
      end,
    }
  }

  self.handlers = {}
  for _, entity in ipairs(zipsub) do
    if (entity.response or {}).topic then
      local topic = self.zipato_base .. "/" .. entity.response.topic
      table.insert(self.handlers, 1, { -- reverse order, since attribs will get most updates
        topic = topic,
        keys = entity.response.keys,
        handler = assert(entity.handler, "no handler for " .. topic)
      })
    end
  end

  -- add the mqtt client to the main loop to start it
  self.first_connect = true
  require("mqtt.loop").add(self.mqtt_zipato)

  -- set up timer to track discovery process
  self.discovery_complete = false
  if self.discovery_tracker then
    self.discovery_tracker:cancel()
  end
  self.discovery_tracker = copas.timer.new({
    recurring = true,
    delay = 15,
    params = self,
    callback = function(this_timer, this_bridge)
      if not this_bridge.networks_expected then
        return -- not yet started
      end
      log:info("Zipabox discovery in progress: %s/%s nw, %s/%s dev, %s/%s ep, %s/%s cep, %s/%s attr, %s/%s val",
        this_bridge.networks_found, this_bridge.networks_expected,
        this_bridge.devices_found, this_bridge.devices_expected,
        this_bridge.endpoints_found, this_bridge.endpoints_expected,
        this_bridge.clusterendpoints_found, this_bridge.clusterendpoints_expected,
        this_bridge.attributes_found, this_bridge.attributes_expected,
        this_bridge.attribute_values_found, this_bridge.attribute_values_expected)
      local complete = this_bridge.networks_found == this_bridge.networks_expected
        and this_bridge.devices_found == this_bridge.devices_expected
        and this_bridge.endpoints_found == this_bridge.endpoints_expected
        and this_bridge.clusterendpoints_found == this_bridge.clusterendpoints_expected
        and this_bridge.attributes_found == this_bridge.attributes_expected
        and this_bridge.attribute_values_found == this_bridge.attribute_values_expected
      if complete then
        this_bridge:discovery_completed()
      end
    end,
  })
  return true
end

function Bridge:lookup_by_uuid(uuid)
  return self.zipabox.networks[uuid] or self.zipabox.devices[uuid] or
          self.zipabox.endpoints[uuid] or self.zipabox.clusterEndpoints[uuid] or
          self.zipabox.attributes[uuid] or nil
end

function Bridge:discovery_completed()
  if self.discovery_complete then
    return
  end
  log:info("Zipabox discovery complete")
  self.discovery_tracker:cancel()
  self.discovery_complete = true
  self.discovery_tracker = nil

  -- build a tree; network/device/endpoint/clusterep/attribute
  self.zipabox.networks.list = nil
  for _, network in pairs(self.zipabox.networks) do
    local device_by_uuid = {}
    for _, device_ref in pairs(network.devices) do
      local device = self:lookup_by_uuid(device_ref.uuid)
      device.endpoints = device.endpoints or {}
      device_by_uuid[device_ref.uuid] = device

      local endpoint_by_uuid = {}
      for _, endpoint_ref in pairs(device.endpoints) do
        local endpoint = self:lookup_by_uuid(endpoint_ref.uuid)
        endpoint.clusterEndpoints = endpoint.clusterEndpoints or {}
        endpoint_by_uuid[endpoint_ref.uuid] = endpoint

        local clusterEndpoint_by_uuid = {}
        for _, clusterEndpoint_ref in pairs(endpoint.clusterEndpoints) do
          local clusterEndpoint = self:lookup_by_uuid(clusterEndpoint_ref.uuid)
          clusterEndpoint.attributes = clusterEndpoint.attributes or {}
          clusterEndpoint_by_uuid[clusterEndpoint_ref.uuid] = clusterEndpoint

          local attribute_by_uuid = {}
          for _, attribute_ref in pairs(clusterEndpoint.attributes) do
            local attribute = self:lookup_by_uuid(attribute_ref.uuid)
            attribute_by_uuid[attribute_ref.uuid] = attribute
          end
          clusterEndpoint.attributes = attribute_by_uuid
        end
        endpoint.clusterEndpoints = clusterEndpoint_by_uuid
      end
      device.endpoints = endpoint_by_uuid
    end
    network.devices = device_by_uuid
  end

  local config = self.zipabox.info
  local serial = config.boxSerial
  config.networks = self.zipabox.networks
  local contents = assert(json.encode(config))

  local filename = pl_path.join(self.config_path, "zipabox-" .. serial .. ".json")
  assert(pl_utils.writefile(filename, contents))
  log:info("Written to file: %s", filename)

  self.mqtt_zipato:disconnect()
  self.mqtt_zipato:shutdown()
end


function Bridge:stop()
end

return Bridge
