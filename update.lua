local filesystem = require 'filesystem'
local shell = require 'shell'

filesystem.remove("/home/seedBreeder.lua")

shell.execute("wget https://raw."..
  "githubusercontent.com/khandyman/"..
  "OpenComputers/main/seedBreeder.lua");
