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
}

build = {
  type = "builtin",

  modules = {
    ["homie-zipato1.init"] = "src/homie-zipato1/init.lua",
  },

  install = {
    bin = {
      ["homie-zipato1"] = "bin/homie-zipato1.lua",
    }
  },

  copy_directories = {
    -- can be accessed by `luarocks homie-zipato1 doc` from the commandline
    "docs",
  },
}
