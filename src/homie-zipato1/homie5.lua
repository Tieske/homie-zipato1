local Homie5 = {}
Homie5.__index = Homie5

function Homie5.new(opts)
  assert(opts ~= Homie5, "the 'new' method must be called with dot notation, not colon notation")
  local self = {}
  self.id = assert(opts.id, "expected opts.id to be a string")

  return setmetatable(self, Homie5)
end


return Homie5
