#!/usr/bin/env lua

--- CLI application.
-- Description goes here.
-- @script homie-zipato1
-- @usage
-- # start the application from a shell
-- homie-zipato1 --some --options=here

print("Welcome to the homie-zipato1 CLI, echoing arguments:")
for i, val in ipairs(arg) do
  print(i .. ":", val)
end
