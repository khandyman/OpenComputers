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
tables in the code below to match your in-world 
locations:
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
  - slot 5 (crops obtained from harvesting will
    be placed here)
  - slot 6 (place 4 of the seeds to be bred
    in this slot; seeds obtained from the
    breeding process will be placed here)
  - slot 13 (a sample crop output item should be
    placed here by the player (e.g., wheat if 
    breeding wheat seeds))
  - slot 14 (a sample item of the seeds being bred
    should be placed here by the player)
  - slot 16 (temp slot used for equipping single
    items to the robot's tool belt)

When running the program one of the following
two arguments must be provided on the command
line:
  - start (to begin a breeding cycle with fresh
    "1/1/1" seeds (or "5/5/5" seeds if bred 
    from full strength parents))
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
parentsMaturity = 0
seedLevels = {[1] = 3, [2] = 3, [3] = 3, 
  [4] = 3}
seedGrowth = {[1] = 0, [2] = 0, [3] = 0, 
  [4] = 0, [5] = 0}
slots = {rake = 1, sticks = 2, crops = 5, seeds = 6,
  cropItem = 13, seedItem = 14, swap = 16}

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


--###########################################
--######### movement functions ##############
--###########################################
--[[ this function moves the robot in a 
     single direction
     parameters:
       orientation (string) = forward, 
         back, left, right, up, down
       distance (int) = how far to move --]]
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
--[[ this function moves the robot to a 
     specific location
     parameters:
       target (table) = x,y,z coordinates --]]
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
--[[ this function rounds a float down
     parameters:
       coord (float) = the decimal number
         to be rounded
     return value:
       coord (int) the whole number equivalent
         of the float parameter --]]
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
--[[ this function compares an inventory slot
      to a pre-defined list of item types
     parameters:
       slot (int) = the inventory slot
         to be compared
     return value:
       itemType (string) the item type in the
          slot provided --]]
function compareItems(slot)
  local itemName = ""
  local itemType = ""
  local seedItem = inventory.
    getStackInInternalSlot(slots.seedItem).name
  local cropItem = inventory.
    getStackInInternalSlot(slots.cropItem).name
  
  if inventory.getStackInInternalSlot(slot) ~= nil then
    itemName = inventory.
      getStackInInternalSlot(slot).name
  end

  if itemName ~= nil then
    if itemName == seedItem then
      itemType = "seed"
    elseif itemName == cropItem then
      itemType = "crop"
    elseif itemName == "minecraft:tallgrass" or
        itemName == "minecraft:double_plant" then
      itemType = "grass"
    elseif itemName == "AgriCraft:handRake" then
      itemType = "rake"
    elseif itemName == "AgriCraft:cropsItem" then
      itemType = "sticks"
    else
      itemType = "unknown"
    end
  end
  
  return itemType
end
---------------------------------------------

---------------------------------------------
--[[ this function counts the item stack in
      an inventory slot
     parameters:
       slot (int) = the inventory slot
         to be counted
     return value:
       stackSize (string) the item type in the
          slot provided --]]
function count(slot)
  local stack = inventory.getStackInInternalSlot(slot)
  local stackSize = 0
    
  if stack ~= nil then
    stackSize = stack.size
  end
  
  return stackSize
end
---------------------------------------------

---------------------------------------------
--[[ this function searches the robot inventory
      for grass and seeds, then deletes them --]]
function dumpTrash()
  moveLocation(trash)

  for i = 3,12,1 do
    if compareItems(i) ~= "crop" then
      robot.select(i)
      robot.dropDown()
    end
  end
  
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
--[[ this function equips a single item from
      a given slot to the robot's tool slot
     parameters:
       slot (int) = the inventory slot
         to be equipped from --]]
function equipItem(slot)
  local curSlot = robot.select()
  robot.select(slot)
  robot.transferTo(slots.swap,1)
  robot.select(slots.swap)
  inventory.equip()
  robot.select(curSlot)
end
---------------------------------------------

---------------------------------------------
--[[ this function moves the robot to its
      charger and waits there until energy
      is full --]]
function getEnergy()
  local energy
  
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
--[[ this function moves the robot to 
      stickStorage and refills its crop sticks --]]
function getSticks()
  moveLocation(stickStorage)
  robot.select(slots.sticks)
  robot.suckDown(64 - count(slots.sticks))
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
--[[ this function checks the robot's energy
      level, and if low prints a warning 
     return value: boolean true if energy low,
      false if not --]]
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
--[[ this function checks the robot's stick
      supply, and if low prints a warning 
     return value: boolean true if sticks low,
      false if not --]]
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
--[[ this function puts inventory items back
      where they belong --]]
function resetInventory()
  local itemName
  local toolEmpty = false
  local swapEmpty = false
  
  robot.select(slots.swap)
  
  repeat
    if inventory.getStackInInternalSlot(slots.swap) == nil then
      inventory.equip()
      toolEmpty = true
    end

    if inventory.getStackInInternalSlot(slots.swap) ~= nil then
      itemName = compareItems(slots.swap)

      if itemName == "rake" then
        robot.transferTo(slots.rake, 1)
      elseif itemName == "sticks" then
        robot.transferTo(slots.sticks, count(slots.swap))
      elseif itemName == "seed" then
        robot.transferTo(12, count(slots.swap))
      end
    else
      swapEmpty = true
    end
  until (toolEmpty == true and swapEmpty == true)
  
  for i = 3,12,1 do
    if compareItems(i) == "seed" and i ~= 6 then
      robot.select(i)
      robot.transferTo(slots.seeds, 1)
      break
    end
  end
  
  robot.select(slots.crops)
end
---------------------------------------------

---------------------------------------------
--[[ this function counts the quantity of item
      types in the robot's middle inventory slots
     return value: foundItems (table) the count
      of each type of item found --]]
function searchSlots()
  local comparison = ""
  local foundItems = {slot = 0, seeds = 0, grass = 0, crops = 0}
  
  for i = 3,12,1 do
    comparison = compareItems(i)
    
    if comparison == "seed" then
      foundItems.slot = i
      foundItems.seeds = foundItems.seeds + 1
    elseif comparison == "grass" then
      foundItems.grass = foundItems.grass + 1
    elseif comparison == "crop" then
      foundItems.crops = foundItems.crops + 1
    end
  end
  
  return foundItems
end
---------------------------------------------

---------------------------------------------
--[[ this function moves the robot to crop
      storage and places any crops in its
      inventory into storage --]]
function storeCrops()
  moveLocation(cropStorage)
  
  for i = 3,12,1 do
    if compareItems(i) == "crop" then
      robot.select(i)
      robot.dropDown()
    end
  end
    
  robot.select(slots.crops)
end
---------------------------------------------

--###########################################
--########## breeding functions #############
--###########################################
---------------------------------------------
function breakCrop(target)
  if robot.swingDown() then
    resetInventory()
    return true
  else
    return false
  end
end
---------------------------------------------

---------------------------------------------
function placeCross()
  if analyzeBlock().name == "AgriCraft:crops" then
    equipItem(slots.sticks)

    if robot.useDown() then
      resetInventory()
      return true
    end
  end

  return false
end
---------------------------------------------

---------------------------------------------
function placeSticks()
  if analyzeBlock().name == "minecraft:air" then
    equipItem(slots.sticks)

    if robot.useDown() then
      --resetInventory()
      return true
    end
  end

  return false
end
---------------------------------------------

---------------------------------------------
function plantCrop()
  if analyzeBlock().name == "AgriCraft:crops" then
    equipItem(slots.seeds)

    robot.useDown()
    robot.select(slots.swap)
    inventory.equip()
    
    if inventory.getStackInInternalSlot(slots.swap) ~= nil then
      robot.swingDown()
      inventory.equip()
      robot.useDown()
    end
    
    resetInventory()
  end
end
---------------------------------------------

---------------------------------------------
function plantStartingSeeds()
  analyzeSeeds(4)
  
  for i = 1,4,1 do
    moveLocation(crops[i])
    placeSticks()
    plantCrop()
  end
  
  moveLocation(charger)
end
---------------------------------------------

---------------------------------------------
function replaceSeeds(newSeed)
    target = compareSeeds(newSeed)
  
    if target ~= -1 then
        print("Crop position "..target.." being replaced.")
        moveLocation(crops[target])
        robot.swingDown()
        
        placeSticks()
        plantCrop()
        seedLevels[target] = newSeed
        parentsMaturity = 0
        moveLocation(charger)
        return true
    else
      print("New seed level is not greater than parents. "..
        "Trashing new seed.")
    end
    
    return false
end
---------------------------------------------

---------------------------------------------
function useRake()
  equipItem(slots.rake)
  
  if robot.useDown() then
    robot.select(slots.rake)
    inventory.equip()
    
    if searchSlots().seeds > 0 then
      breakCrop()
      resetInventory()
      return true
    else
      placeCross()
      return false
    end
  end
end
---------------------------------------------

--###########################################
--########### logic functions ###############
--###########################################
---------------------------------------------
function analyzeBlock()
  local scan = geolyzer.analyze(sides.down)

  return scan
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
function compareSeeds(newSeed)
  local lowestSeedNum = -1
  local minSeedLevel = 0
  local scan
  
  for i = 1,4,1 do
    if seedLevels[i] < minSeedLevel or minSeedLevel == 0 then
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
function setLevels()
  local minSeedLevel = 0
  local scan = {}

  for i = 1,4,1 do
    moveLocation(crops[i])
    scan = calculateLevels()
    
    seedLevels[i] = scan.level
    seedGrowth[i] = scan.maturity
    
    if seedGrowth[i] == 7 then
      parentsMaturity = parentsMaturity + 7
    end

    if scan.level > maxSeedLevel then
      maxSeedLevel = scan.level
    end
  end
end
---------------------------------------------

--###########################################
--########### timing functions ##############
--###########################################
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

      if maturity > 0 then
        if useRake() then
          if searchSlots().seeds > 0 then
            childGrown = true
            break
          end
        end
      end
    end
    
    moveLocation(charger)
    os.sleep(15)
  end
end
---------------------------------------------

---------------------------------------------
function waitForParents()
  local result = {}
  
  if lowEnergy() then
    getEnergy()
  end

  while parentsMaturity < 28 do
    parentsMaturity = 0

    for i = 1,4,1 do
      if seedGrowth[i] <= 7 then
        moveLocation(crops[i])
        result = calculateLevels()

        if result.name == "AgriCraft:crops" then
          seedLevels[i] = result.level
          seedGrowth[i] = result.maturity
          
          if result.maturity == 7 then
            parentsMaturity = parentsMaturity + 7
          else
            break
          end
        end
      end
    end
    
    if parentsMaturity < 28 then
      moveLocation(charger)
      os.sleep(15)
    end
  end
end
---------------------------------------------

--###########################################
--######## main program execution ###########
--###########################################
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
