local robot = require 'robot'
local component = require 'component'
nav = component.navigation

---------------------------------------------
-------coordination positions----------------
---------------------------------------------
charger = {x = 358, y = 65, z = 357}
analyzer = {x = 358, y = 65, z = 358}
cropSouth = {x = 356, y = 65, z = 355}
cropWest = {x = 355, y = 65, z = 354}
cropNorth = {x = 356, y = 65, z = 353}
cropEast = {x = 357, y = 65, z = 354}
cropCenter = {x = 356, y = 65, z = 354}


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

function moveLocation(targetX, targetY, targetZ)
  local distance = {}
  local currentX, currentY, currentZ = 
    nav.getPosition()
  
  distance.x = targetX - currentX
  distance.y = targetY - currentY
  distance.z = targetZ - currentZ
  
  if distance.x > 0 then
    direction("right", normalize(distance.x))
  elseif distance.x < 0 then
    direction("left", normalize(distance.x))
  end
  
  if distance.z > 0 then
    direction("back", normalize(distance.z))
  elseif distance.z > 0 then
    direction("forward", normalize(distance.z))
  end
end

function normalize(coord)
  if coord > 0 then
    coord = math.floor(coord)
  elseif coord < 0 then
    coord = math.abs(math.ceil(coord))
  end
  
  return coord
end
---------------------------------------------

function main()
  moveLocation(cropCenter)
end

main()
