require 'middleclass'

local gravity = 450
local physics_accuracy = 1
local sqrt = math.sqrt
local mouse_influence = 20
local mouse_cut         = 10

Constraint = class('Constraint')

function Constraint:initialize(p1, p2, spacing, tear_distance)
  self.p1 = p1
  self.p2 = p2
  self.length = spacing
  self.tear_distance = tear_distance
end


function Constraint:solve()
  local diff_x = self.p1.x - self.p2.x
  local diff_y = self.p1.y - self.p2.y
  local dist = sqrt(diff_x * diff_x + diff_y * diff_y)
  local diff = (self.length - dist) / dist

  if dist > self.tear_distance then
    self.p1:remove_constraint(self)
  end

  local scalar_1 = (1 / self.p1.mass) / ((1 / self.p1.mass) + (1 / self.p2.mass))
  local scalar_2 = 1 - scalar_1

  self.p1.x = self.p1.x + diff_x * scalar_1 * diff
  self.p1.y = self.p1.y + diff_y * scalar_1 * diff

  self.p2.x = self.p2.x - diff_x * scalar_2 * diff
  self.p2.y = self.p2.y - diff_y * scalar_2 * diff
end


function Constraint:draw()
  love.graphics.line(self.p1.x, self.p1.y, self.p2.x, self.p2.y)
end


Point = class('Point')

function Point:initialize(x, y)
  self.x = x
  self.y = y
  self.px = x
  self.py = y
  self.ax = 0
  self.ay = 0
  self.mass = 1
  self.constraints = {}
  self.pinned = false
  self.pin_x = nil
  self.pin_y = nil
end

function Point:update(dt)
  self:add_force(0, self.mass * gravity)
  local vx = self.x - self.px
  local vy = self.y - self.py
  local delta = dt * dt

  local nx = self.x + 0.99 * vx + 0.5 * self.ax * delta
  local ny = self.y + 0.99 * vy + 0.5 * self.ay * delta

  self.px = self.x
  self.py = self.y

  self.x = nx
  self.y = ny

  self.ax = 0
  self.ay = 0
end

function Point:update_mouse()
  if not mouse.down then
    return
  end

  local diff_x = self.x - mouse.x
  local diff_y = self.y - mouse.y
  local dist = sqrt(diff_x * diff_x + diff_y * diff_y)

  if love.mouse.isDown('l') and dist < mouse_influence then
      self.px = self.x - (mouse.x - mouse.px) * 1.8
      self.py = self.y - (mouse.y - mouse.py) * 1.8

  elseif dist < mouse_cut then
      self.constraints = {}
  end
end

function Point:draw()
  if #self.constraints == 0 then
    return
  end
  for index, constraint in ipairs(self.constraints) do
    constraint:draw()
  end
end

function Point:solve_constraints()
  for index, constraint in ipairs(self.constraints) do
    constraint:solve()
  end

  if self.y < 1 then
   self.y = 2 * (1) - self.y
  elseif self.y > love.graphics.getHeight() then
    self.y = 2 * love.graphics.getHeight() - self.y
  end

  if self.x > love.graphics.getWidth() then
   self.x = 2 * (love.graphics.getWidth()) - self.x

  elseif self.x < 1 then
    self.x = 2 * 1 - self.x
  end

  -- Pinning
  if self.pinned then
    self.x = self.pin_x
    self.y = self.pin_y
  end
end

function Point:attach(P, spacing, tear_distance)
  local constraint = Constraint(self, P, spacing, tear_distance)
  table.insert(self.constraints, constraint)
end

function Point:remove_constraint(lnk)
  for index, constraint in ipairs(self.constraints) do
    if constraint == lnk then
      table.remove(self.constraints, index)
      return
    end
  end
end

function Point:add_force(fx, fy)
  self.ax = self.ax + fx / self.mass
  self.ay = self.ay + fy / self.mass
end

function Point:pin(px, py)
  self.pinned = true
  self.pin_x = px
  self.pin_y = py
end


Physics = class('Physics')

function Physics:initialize(points)
  self.points = points
  self.delta_sec = 16 / 1000;
  self.accuracy = physics_accuracy
end

function Physics:update(dt)
  for i = self.accuracy, 0, -1 do
    for index, point in ipairs(self.points) do
      point:solve_constraints()
    end
  end

  for index, point in ipairs(self.points) do
    point:update_mouse()
    point:update(dt)
  end
end

