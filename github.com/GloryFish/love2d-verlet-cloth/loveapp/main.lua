
require 'verlet'

local gravity = 450
local cloth_height      = 30
local cloth_width       = 50
local start_y           = 20
local spacing           = 7
local tear_distance     = 80


function love.load()
  points = build_cloth()
  once = true
  physics = Physics(points);
  mouse = {
    down = false,
    x = 0,
    y = 0,
    px = 0,
    py = 0,
  }
end

function love.keypressed(key, unicode)
  if key == 'escape' then
    love.event.push('quit')
  end
end


function love.update(dt)
  mouse.down = love.mouse.isDown('l') or love.mouse.isDown('r')
  mouse.px = mouse.x
  mouse.py = mouse.y
  mouse.x = love.mouse.getX()
  mouse.y = love.mouse.getY()

  physics:update(dt);
end

function love.draw()
  love.graphics.clear()
  love.graphics.setColor(255, 255, 255)
  for index, point in ipairs(points) do
    point:draw()
  end
end

function build_cloth()
  local points = {}
  local start_x = love.graphics.getWidth() / 2 - cloth_width * spacing / 2

  for y = 1, cloth_height do
    for x = 1, cloth_width do
      local p = Point(start_x + (x * spacing) - spacing, start_y + (y * spacing) - spacing)

      if x ~= 1 then
        p:attach(points[#points], spacing, tear_distance)
      end

      if y ~= 1 then
        p:attach(points[(y - 2) * cloth_width + x], spacing, tear_distance)
      end

      if y == 1 then
        p:pin(p.x, p.y)
      end

      table.insert(points, p)
    end
  end
  return points
end