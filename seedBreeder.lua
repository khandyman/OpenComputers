local robot = require 'robot'
local component = require 'component'
local computer = require 'computer'
local sides = require 'sides'
local inventory = component.inventory_controller
local nav = component.navigation
local geolyzer = component.geolyzer

---------------------------------------------
----coordinate positions and variables-------
---------------------------------------------
charger = {x = 358, y = 65, z = 357}
analyzer = {x = 358, y = 65, z = 360}
trash = {x = 358, y = 65, z = 364}
stickStorage = {x = 358, y = 65, z = 363}
cropStorage = {x = 358, y = 65, z = 362}
seedScan = {x = 354, y = 65, z = 356}

crops = {}
crops[1] = {x = 356, y = 65, z = 355} --south
crops[2] = {x = 355, y = 65, z = 354} --west
crops[3] = {x = 356, y = 65, z = 353} -- north
crops[4] = {x = 357, y = 65, z = 354} --east
crops[5] = {x = 356, y = 65, z = 354} --center

seeds = {[1] = 3, [2] = 3, [3] = 3, [4] = 3}

slots = {rake = 1, sticks = 2, seeds = 3}


local destination = charger
local args = {...}

if args[1] ~= nil then
  if args[1] == "analyzer" then
    destination = analyzer
  elseif args[1] == "charger" then
    destination = charger
  elseif args[1] == "trash" then
    destination = trash
  elseif args[1] == "stickStorage" then
    destination = stickStorage
  elseif args[1] == "cropStorage" then
    destination = cropStorage
  elseif args[1] == "seedScan" then
    destination = seedScan
  elseif args[1] == "cropSouth" then
    destination = crops[1]
  elseif args[1] == "cropWest" then
    destination = crops[2]
  elseif args[1] == "cropNorth" then
    destination = crops[3]
  elseif args[1] == "cropEast" then
    destination = crops[4]
  elseif args[1] == "cropCenter" then
    destination = crops[5]
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
    moveDirection("right", distance.x)
  elseif distance.x < 0 then
    moveDirection("left", math.abs(distance.x))
  end
  
  if distance.z > 0 then
    moveDirection("back", distance.z)
  elseif distance.z < 0 then
    moveDirection("forward", math.abs(distance.z))
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

function compareItems(itemName, slot)
  stackName = inventory.
    getStackInInternalSlot(slot).name

  if stackName ~= nil then
    if itemName == stackName then
      return true
    end
  end

  return false
end

function getSticks()
  if checkSticks() < 16 then
    moveLocation(stickStorage)
    robot.select(slots.sticks)
    
    if robot.suckDown(32) then
      return true
    end
  end

  return false
end

function equipItem(slot)
  robot.select(slot)
  robot.transferTo(16,1)
  robot.select(16)
  inventory.equip()
end

function dumpSeeds()
  moveLocation(trash)

  for i = 3,16,1 do
    if compareItems("agricraft:crops", i) then
      robot.select(i)
      dropDown()
    end
  end
end

function storeCrops()
  moveLocation(cropStorage)

  for i = 3,16,1 do
    if not compareItems("agricraft:crops", i) then
      robot.select(i)
      dropDown()
    end
  end
end

function lowEnergy()
  energy = computer.energy()
  
  if energy < 1000 then
    return true
  else
    print("Energy level is good. Reserves at "..
        math.floor(energy)..".")
    return false
  end
end

function getEnergy()
  moveLocation(charger)

  repeat
    os.sleep(5)
    energy = computer.energy()
  until (energy > 20000)

  print("Energy is full. Reserves at "..
    math.floor(energy)..".")
end
---------------------------------------------


---------------------------------------------
--------breeding functions-------------------
---------------------------------------------
function breakCrop(target)
  moveLocation(target)
  robot.swingDown()
end

function plantCrop()
  if analyzeBlock().name == "AgriCraft:cropsItem" then
    equipItem(slots.seeds)

    if robot.useDown() then
      return true
    end
  end

  return false
end

function analyzeSeed()
  moveLocation(analyzer)
  robot.select(slots.seeds)
  robot.dropDown()
  os.sleep(4)
  robot.suckDown()
  moveLocation(seedScan)
  placeSticks()
  plantCrop()
  
  seed = analyzeBlock()
  strength = seed.strength
  growth = seed.growth
  gain = seed.gain
  seedLevel = strength + growth + gain

  robot.swingDown()
  
  return seedLevel
end

function compareSeeds()
  inventorySeed = analyzeSeed()
  lowestSeedLevel = -1
  lowestSeedNum = -1
  
  for i = 1,3,1 do
    if seeds[i] < seeds[i + 1] then
      lowestSeedLevel = seeds[i]
      lowestSeedNum = i
    else
      lowestSeedLevel = seeds[i + 1]
      lowestSeedNum = i + 1
    end
  end
  
  if lowestSeedLevel < inventorySeed then
    return lowestSeedNum
  else
    return -1
  end
end

function replaceSeeds()
    target = compareSeeds()
  
    if target ~= -1 then
        moveLocation(crops.target)
        robot.swingDown()
        placeSticks()
        
        if plantCrop() then
          return true
        end
    end
    
    return false
end

function placeSticks()
  if analyzeBlock().name == "minecraft:air" then
    equipItem(slots.sticks)

    if robot.useDown() then
      return true
    end
  end

  return false
end

function placeCross()
  if analyzeBlock().name == "AgriCraft:cropsItem" then
    equipItem(slots.sticks)

    if robot.useDown() then
      return true
    end
  end

  return false
end

function analyzeBlock()
  scan = geolyzer.analyze(sides.down)

  return scan
end

function plantStartingSeeds()
  moveLocation(analyzer)
  robot.select(slots.seeds)
  robot.drop(4)
  os.sleep(2)
  robot.suckDown()
  
  for i = 1,4,1 do
    moveLocation(crops[i])
    placeSticks()
    plantCrop()
  end
end
---------------------------------------------


function main()
  --lowEnergy()
  --getSticks()
  --moveLocation(destination)
  placeSticks()
end

main()
