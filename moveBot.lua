local robot = require 'robot'
local component = require 'component'
nav = component.navigation

moveBot = {}

function moveBot.direction(orientation, distance)
  if orientation == "right" then
    robot.turnRight()
  elseif orientation == "left" then
    robot.turnLeft()
  end
  
  for i = 1, dis do
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

function moveBot.location(targetX, targetY, targetZ)
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

function moveBot.normalize(coord)
  if coord > 0 then
    coord = math.floor(coord)
  elseif coord < 0 then
    coord = math.abs(math.ceil(coord))
  end
  
  return coord
end

return moveBot
