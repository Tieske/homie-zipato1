local package_name = "homie-zipato1"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "Tieske"
local github_repo_name = "homie-zipato1"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "Bridge between Homie and Zipabox1",
  detailed = [[
    Bridge between Homie and Zipabox1
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
  "homie",
  "luabitop", -- for Lua 5.1 compatibility
  "lua-cjson",
}

build = {
  type = "builtin",

  modules = {
    ["homie-zipato1.devices"] = "src/homie-zipato1/devices.lua",
    ["homie-zipato1.discover"] = "src/homie-zipato1/discover.lua",
  },

  install = {
    bin = {
      ["zipato-discover"] = "bin/zipato-discover.lua",
      ["homie-zipato"] = "bin/homie-zipato.lua",
    }
  },
}
