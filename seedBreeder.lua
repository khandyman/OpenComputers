--[[
This program uses OpenComputers to 
automatically breed AgriCraft (for Minecraft 
version 1.7.10) crops, with AgriCraft's hard 
mode set in its config (i.e. 4 parents are 
required to have a chance at increased stats 
or mutations for children)

The program should be run on an OC robot with
the following components installed:
  - at least a tier 2 case, and corresponding
    basic hardware (i.e., cpu, memory, etc.)
  - screen
  - keyboard
  - geolyzer
  - navigation upgrade
  - inventory upgrade
  - inventory controller upgrade

The following components are optional, but
recommended:
  - internet card (for downloading the code
    to the robot)
  - card container (for swapping cards on the fly)
  - upgrade container (same, but for upgrades)

Change the coordinate positions of the following
tables to match your in-world locations:
  - charger (an OC charger)
  - analyzer (this is a regular AgriCraft analyzer)
  - trash (any modded trash can)
  - stickStorage (any inventory, to store crop sticks)
  - cropStorage (any inventory, to store crop output)
  - seedScan (any position near your breeding site, 
    it's basically a rest position for the robot, and
    also used to scan new seeds with the geolyzer)
  - crops (5 adjacent blocks of farmland, in the 
    shape of a plus sign, for the 4 parent crops
    and the cross crop in the center for breeding)

The following robot slots are used by the program:
  - slot 1 (hand rake needs to be placed here)
  - slot 2 (crop sticks will be pulled from 
    stickStorage and placed here)
  - slot 3 (crops obtained from harvesting will
    be placed here)
  - slot 4 (seeds obtained from harvesting will
    be placed here)
  - slot 13 (temp slot used for equipping single
    items to the robot's tool belt)
  - slot 15 (a sample crop output item should be
    placed here by the player (e.g., wheat if 
    breeding wheat seeds))
  - slot 16 (a sample item of the seeds being bred
    should be placed here by the player)

When running the program one of the following
two arguments must be provided on the command
line:
  - start (to begin a breeding cycle with fresh
    "1/1/1" seeds)
  - continue (to begin with existing, partially
    developed parent seeds)
--]]

local robot = require 'robot'
local component = require 'component'
local computer = require 'computer'
local sides = require 'sides'
local inventory = component.inventory_controller
local nav = component.navigation
local geolyzer = component.geolyzer

--###########################################
--## coordinate positions and variables #####
--###########################################
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

maxSeedLevel = 3
parentsGrown = false
seedLevels = {[1] = 3, [2] = 3, [3] = 3, 
  [4] = 3}
seedGrowth = {[1] = 0, [2] = 0, [3] = 0, 
  [4] = 0, [5] = 0}
slots = {rake = 1, sticks = 2, crops = 3, 
  seeds = 4}

local destination = charger
local entryPoint = ""
local args = {...}

-- argument setup --
if args[1] ~= nil then
  if args[1] == "start" then
    entryPoint = "start"
  elseif args[1] == "continue" then
    entryPoint = "continue"
  end
end

if args[2] ~= nil then
  if args[2] == "analyzer" then
    destination = analyzer
  elseif args[2] == "charger" then
    destination = charger
  elseif args[2] == "trash" then
    destination = trash
  elseif args[2] == "stickStorage" then
    destination = stickStorage
  elseif args[2] == "cropStorage" then
    destination = cropStorage
  elseif args[2] == "seedScan" then
    destination = seedScan
  elseif args[2] == "cropSouth" then
    destination = crops[1]
  elseif args[2] == "cropWest" then
    destination = crops[2]
  elseif args[2] == "cropNorth" then
    destination = crops[3]
  elseif args[2] == "cropEast" then
    destination = crops[4]
  elseif args[2] == "cropCenter" then
    destination = crops[5]
  end
end


--###########################################
--######### movement functions ##############
--###########################################
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

---------------------------------------------
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
---------------------------------------------

---------------------------------------------
function normalize(coord)
  if coord > 0 then
    coord = math.floor(coord)
  elseif coord < 0 then
    coord = math.ceil(coord)
  end
  
  return coord
end
---------------------------------------------


--###########################################
--######### inventory functions #############
--###########################################
---------------------------------------------
function count(slot)
  local stack = inventory.getStackInInternalSlot(slot)
    
  if stack ~= nil then
    return stack.size
  else
    return 0
  end
end
---------------------------------------------

---------------------------------------------
function compareItems(slot)
  local itemName = ""
  local seedName = inventory.
    getStackInInternalSlot(16).name
  local cropName = inventory.
    getStackInInernalSlot(15).name
  
  if inventory.getStackInInternalSlot(slot) ~= nil then
    itemName = inventory.
      getStackInInternalSlot(slot).name
  end

  if itemName ~= nil then
    if seedName == itemName then
      return "seed"
    elseif itemName == "minecraft:tallgrass" or
        itemName == "minecraft:double_plant" then
      return "grass"
    elseif itemName == cropName then
      return "crop"
    end
  end
end
---------------------------------------------

---------------------------------------------
function lowSticks()
  robot.select(slots.sticks)
  local stackSize = count(slots.sticks)
  
  if stackSize < 16 then
    print("Supply of crop sticks is low. "..
      "Currently at "..stackSize..".")
    return true
  else
    return false
  end
end
---------------------------------------------

---------------------------------------------
function getSticks()
  moveLocation(stickStorage)
  robot.select(slots.sticks)
  robot.suckDown(32)
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
function equipItem(slot)
  curSlot = robot.select()
  robot.select(slot)
  robot.transferTo(13,1)
  robot.select(13)
  inventory.equip()
  robot.select(curSlot)
end
---------------------------------------------

---------------------------------------------
function dumpTrash()
  moveLocation(trash)

  for i = 3,8,1 do
    if compareItems(i) ~= "crop" then
      robot.select(i)
      robot.dropDown()
    end
  end
  
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
function storeCrops()
  moveLocation(cropStorage)
  
  for i = 3,8,1 do
    if compareItems(i) == "crop" then
      robot.select(i)
      robot.dropDown()
    end
  end
    
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
function searchSeeds()
  --local checkName = inventory.getStackInInternalSlot(15).name
  
  for i = 3,8,1 do
    local comparison = compareItems(i)
    
    if comparison == "seed" then
      return "seed"
    elseif comparison == "grass" then
      return "grass"
    else
      return "crop"
    end
  end
end
---------------------------------------------

---------------------------------------------
function lowEnergy()
  local energy = computer.energy()
  
  if energy < 1000 then
    print("Energy level is low. Reserves at "..
        math.floor(energy)..". Recharging.")
    return true
  else
    return false
  end
end
---------------------------------------------

---------------------------------------------
function getEnergy()
  moveLocation(charger)

  repeat
    os.sleep(5)
    local energy = computer.energy()
  until (energy > 20000)

  print("Energy is full. Reserves at "..
    math.floor(energy)..".")
end
---------------------------------------------


--###########################################
--########## breeding functions #############
--###########################################
---------------------------------------------
function placeSticks()
  if analyzeBlock().name == "minecraft:air" then
    equipItem(slots.sticks)

    if robot.useDown() then
      return true
    end
  end

  return false
end
---------------------------------------------

---------------------------------------------
function placeCross()
  if analyzeBlock().name == "AgriCraft:crops" then
    equipItem(slots.sticks)

    if robot.useDown() then
      return true
    end
  end

  return false
end
---------------------------------------------

---------------------------------------------
function breakCrop(target)
  --moveLocation(target)
  --robot.select(slots.crops)
  
  if robot.swingDown() then
    return true
  else
    return false
  end
end
---------------------------------------------

---------------------------------------------
function useRake()
  equipItem(1)
  
  if robot.useDown() then
    robot.select(slots.rake)
    inventory.equip()
    robot.select(slots.crops)
    
    if searchSeeds() == "grass" then
      placeCross()
      dumpTrash()
      return false
    elseif searchSeeds() == "seed" then
      breakCrop()
      return true
    end
  end
end
---------------------------------------------

---------------------------------------------
function plantCrop()
  if analyzeBlock().name == "AgriCraft:crops" then
    if compareItems(slots.seeds) == "seed" then
      equipItem(slots.seeds)
    elseif compareItems(slots.crops) == "seed" then
      equipItem(slots.crops)
    end

    if robot.useDown() then
      return true
    else
      robot.swingDown()
      
      if robot.useDown() then
        return true
      end
    end
  end

  return false
end
---------------------------------------------

---------------------------------------------
function analyzeBlock()
  local scan = geolyzer.analyze(sides.down)

  return scan
end
---------------------------------------------

---------------------------------------------
function calculateLevels()
  local seedScan, seedMaturity
  local statStrength, statGrowth, statGain 
  local scanResults = {name = "", level = 0, maturity = 0}
  
  seedScan = analyzeBlock()
  statStrength = seedScan.strength
  statGrowth = seedScan.growth
  statGain = seedScan.gain

  scanResults.name = seedScan.name
  scanResults.level = statStrength + statGrowth + statGain
  scanResults.maturity = seedScan.metadata
  
  return scanResults
end
---------------------------------------------

---------------------------------------------
function setLevels()
  local minSeedLevel = 0
  local scan = {}
print("entering setLevels")
  for i = 1,4,1 do
    moveLocation(crops[i])
    scan = calculateLevels()
    
    seedLevels[i] = scan.level
    seedGrowth[i] = scan.maturity
    
    if seedGrowth[i] == 7 then
      parentsGrown = true
    else
      parentsGrown = false
    end
print("seedLevels["..i.."] = "..scan.level.. 
  " and seedGrowth["..i.."] = "..scan.maturity)
    if scan.level > maxSeedLevel then
      maxSeedLevel = scan.level
print("maxSeedLevel is "..maxSeedLevel)
    end
    
--[[    if scan.level < minSeedLevel or minSeedLevel == 0 then
      minSeedLevel = scan.level
print("minSeedLevel is "..minSeedLevel)
    end--]]
  end
end
---------------------------------------------

---------------------------------------------
function analyzeSeeds(quantity)
  moveLocation(analyzer)
  robot.select(slots.seeds)
  
  if robot.dropDown(quantity) then
    os.sleep(4)
  else
    robot.select(slots.crops)
    
    if robot.dropDown(quantity) then
      os.sleep(4)
    end
  end
    
  robot.suckDown()

  if quantity == 1 then
    moveLocation(seedScan)
    placeSticks()
    plantCrop()
  
    local seedLevel = calculateLevels().level

    robot.select(slots.seeds)
    
    if robot.swingDown() then
      return seedLevel
    else
      return -1
    end
  end
end
---------------------------------------------

---------------------------------------------
function compareSeeds(newSeed)
  local lowestSeedNum = -1
  local minSeedLevel = 3
  local scan
  
  for i = 1,4,1 do
    --moveLocation(crops[i])
    --scan = calculateLevels()
    
print("minSeedLevel = "..minSeedLevel)
    if seedLevels[i] < minSeedLevel or minSeedLevel == 3 then
print("seedLevels[i] = "..seedLevels[i])
      minSeedLevel = seedLevels[i]
      lowestSeedNum = i
    end
  end

  if newSeed > maxSeedLevel then
    print("New max seed level of "..newSeed..
      " reached.")
    maxSeedLevel = newSeed
  end

  if minSeedLevel < newSeed then
    return lowestSeedNum
  else
    return -1
  end
end
---------------------------------------------

---------------------------------------------
function replaceSeeds(newSeed)
    target = compareSeeds(newSeed)
  
    if target ~= -1 then
        print("Crop position "..target.." being replaced.")
        moveLocation(crops[target])
        robot.swingDown()
        
        if placeSticks() and plantCrop() then
          seedLevels[target] = newSeed
          parentsGrown = false
          moveLocation(seedScan)
          return true
        end
    end
    
    return false
end
---------------------------------------------

---------------------------------------------
function waitForParents()
  local result = {}
  
  if lowEnergy() then
    getEnergy()
  end

  while parentsGrown == false do
    for i = 1,4,1 do
      if seedGrowth[i] <= 7 then
        moveLocation(crops[i])
        result = calculateLevels()

        if result.name == "AgriCraft:crops" then
          seedLevels[i] = result.level
          seedGrowth[i] = result.maturity
          
          if result.maturity == 7 then
            parentsGrown = true
          else
            parentsGrown = false
            break
          end
        end
      end
    end
    
    moveLocation(seedScan)
    os.sleep(20)
  end
end
---------------------------------------------

---------------------------------------------
function waitForChild()
  local childGrown = false
  local result = {}
  
  while childGrown == false do
    if lowEnergy() then
      getEnergy()
    end
    
    moveLocation(crops[5])
    result = analyzeBlock()
      
    if result.name == "AgriCraft:crops" then
      maturity = result.metadata

      if maturity ~= 0 then
        if useRake() then
          if searchSeeds() == "seed" then
            childGrown = true
            break
          end
        end
      end
    end
    
    moveLocation(seedScan)
    os.sleep(20)
  end
end
---------------------------------------------
function plantStartingSeeds()
  analyzeSeeds(4)
  
  for i = 1,4,1 do
    moveLocation(crops[i])
    placeSticks()
    plantCrop()
  end
  
  moveLocation(seedScan)
end
---------------------------------------------

---------------------------------------------
function main()
  -- set entry point
  if entryPoint == "start" then
    print("seedBreeder starting. Setting initial crop positions.")
    plantStartingSeeds()
  elseif entryPoint == "continue" then
    print("seedBreeder resuming. Scanning current growth levels.")
    setLevels()
  else
    print("Please provide an entry point "..
      "(start or continue) as an argument.")
    return
  end
      
  waitForParents()
  
  print("Starting Positions set. Entering main loop")
  while maxSeedLevel ~= 30 do
    if lowEnergy() then
      getEnergy()
    end
    
    print("Setting child spawn conditions.")
    -- initiate child growth
    if lowSticks() then
      getSticks()
    end
          
    moveLocation(crops[5])
    placeSticks()
    placeCross()
    waitForChild()
    
    -- scan new child
    print("Child crop grown. Scanning for seed level.")
    
    newSeed = analyzeSeeds(1)
    
    if newSeed == 30 then
      print("Maximum seed level reached. Exiting program.")
      moveLocation(charger)
      break
    else
      print("Maximum seed level not reached. Replacing seeds.")
      replaceSeeds(newSeed)
      storeCrops()
      dumpTrash()
    end
    
    waitForParents()
  end
end
---------------------------------------------

main()
