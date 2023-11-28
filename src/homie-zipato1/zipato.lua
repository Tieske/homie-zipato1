--- Zipato box class.
--
-- An instance represents a single Zipabox.
--
-- @copyright Copyright (c) 2023-2023 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local Zipato = {}
Zipato._VERSION = "0.0.1"
Zipato._COPYRIGHT = "Copyright (c) 2023-2023 Thijs Schreijer"
Zipato._DESCRIPTION = "Bridge between Homie and Zipabox1"
Zipato.__index = Zipato

function Zipato.new(opts)
  assert(opts ~= Zipato, "Don't call 'new' with colon notation")
  local self = {}
  self.zipato_base = opts.zipato_base or "zipato" -- base topic for zipato boxes


  setmetatable(self, Zipato)

  return self
end

function Zipato:start()
end

function Zipato:stop()
end

return Zipato
