local robot = require 'robot'
local component = require 'component'
--local computer = require 'computer'
local inventory = component.inventory_controller
local nav = component.navigation
local geolyzer = component.geolyzer

---------------------------------------------
----coordinate positions and variables-------
---------------------------------------------
charger = {x = 358, y = 65, z = 357}
analyzer = {x = 358, y = 65, z = 358}
trash = {x = 358, y = 65, z = 356}
stickStorage = {x = 358, y = 65, z = 359}
seedStorage = {x = 358, y = 65, z = 360}
crops = {}
crops[0] = {x = 356, y = 65, z = 355} --south
crops[1] = {x = 355, y = 65, z = 354} --west
crops[2] = {x = 356, y = 65, z = 353} -- north
crops[3] = {x = 357, y = 65, z = 354} --east
crops[4] = {x = 356, y = 65, z = 354} --center

slots = {rake = 1, sticks = 2, seeds = 3}


local destination = charger
local args = {...}

if args[1] ~= nil then
  if args[1] == "analyzer" then
    destination = analyzer
  elseif args[1] == "cropSouth" then
    destination = cropSouth
  elseif args[1] == "cropWest" then
    destination = cropWest
  elseif args[1] == "cropNorth" then
    destination = cropNorth
  elseif args[1] == "cropEast" then
    destination = cropEast
  elseif args[1] == "cropCenter" then
    destination = cropCenter
  end
end


---------------------------------------------
-------movement functions--------------------
---------------------------------------------
function moveDirection(orientation, distance)
  if orientation == "right" then
    robot.turnRight()
  elseif orientation == "left" then
    robot.turnLeft()
  end
  
  for i = 1, distance do
    if orientation == "forward" or 
        orientation == "right" or
        orientation == "left" then
      robot.forward()
    elseif orientation == "back" then
      robot.back()
    elseif orientation == "up" then
      robot.up()
    elseif orientation == "down" then
      robot.down()
    end
  end
  
  if orientation == "right" then
    robot.turnLeft()
  elseif orientation == "left" then
    robot.turnRight()
  end
end

function moveLocation(target)
  local distance = {}
  local targetX = target.x
  local targetY = target.y
  local targetZ = target.z
  local currentX, currentY, currentZ = 
    nav.getPosition()
  
  distance.x = targetX - normalize(currentX)
  distance.y = targetY - normalize(currentY)
  distance.z = targetZ - normalize(currentZ)
  
  if distance.x > 0 then
    direction("right", distance.x)
  elseif distance.x < 0 then
    direction("left", math.abs(distance.x))
  end
  
  if distance.z > 0 then
  elseif distance.z > 0 then
    direction("forward", math.abs(distance.z))
  end
end

function normalize(coord)
  if coord > 0 then
    coord = math.floor(coord)
  elseif coord < 0 then
    coord = math.ceil(coord)
  end
  
  return coord
end
---------------------------------------------


---------------------------------------------
-------inventory functions-------------------
---------------------------------------------
function checkSticks()
  robot.select(slots.sticks)
  stackSize = count(slots.sticks)
  
  print("Supply of crop sticks is at "..stackSize..".")
  
  return stackSize
end
  
function count(slot)
  stack = inventory.getStackInInternalSlot(slot)
    
  if stack ~= nil then
    return stack.size
  end
  
  return 0
end

function getSticks()
  if checkSticks() < 16 then
    moveLocation(stickStorage)
    robot.select(slots.sticks)
    
    if robot.SuckDown(32) then
      return true
    end
  end

  return false
end

function dumpSeeds()
  
end

function checkEnergy()
  energy = computer.energy()
  
  if energy > 1000 then
    print("Energy level is good. Reserves at "..
        math.floor(energy)..".")
    return true
  end
  
  return false
end
---------------------------------------------


---------------------------------------------
--------breeding functions-------------------
---------------------------------------------
function breakCrop(target)
  moveLocation(target)
  robot.swingDown()
end

function plantSeeds()
  
end

function replaceSeeds()

end

function placeSticks()
  robot.select(slots.sticks)
  
  if analyzeBlock() == "minecraft:air" then
    robot.select(slots.sticks)
  end
end

function placeCross()
  if analyzeBlock() == "agricraft:crop_sticks" then
    robot.select(slots.sticks)
    robot.useDown()
  end
end

function analyzeBlock()
  scan = geolyzer.analyze(sides.down)

  if scan ~= nil then
    name = scan.name
    return name
  else
    return ""
  end
end

function analyzeSeed()
  
end

function compareSeeds()
  
end
---------------------------------------------


function main()
  checkEnergy()
  checkSticks()
  moveLocation(destination)
end

main()
