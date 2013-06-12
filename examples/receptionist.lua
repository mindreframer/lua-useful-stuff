-- receptionist.lua
-- Employment office queuing model, example 19.2 from
-- Pooley, R., "An introduction to programming in Simula"
-- http://www.macs.hw.ac.uk/~rjp/bookhtml

local simulua = require "simulua"
local queue = require "queue"

-- variables
local MANUAL = 1  -- skill category

-- processes
local manual, skilled -- interviewers
local receptionist

local function interviewer (title)
  local interviewerQ = queue()
  return simulua.process(function()
    while true do
      if not interviewerQ:isempty() then
        simulua.hold(3.5) -- interview time taken as 3.5 minutes
        local next = interviewerQ:retrieve()
        simulua.activate(next, simulua.current(), true) -- after current
        simulua.hold(3) -- 3 minutes to clear desk
      else
        simulua.hold(5) -- wait 5 minutes before checking queue again
      end
    end
  end, {Q = interviewerQ})
end

local function jobhunter (skill)
  return simulua.process(function()
    print(string.format(
        "Job hunter %d joins receptionist queue at time %.1f",
        skill, simulua.time()))
    simulua.wait(receptionist.Q)
    print(string.format(
        "Job hunter %d joins interview queue at time %.1f",
        skill, simulua.time()))
    simulua.hold(1) -- 1 minute to join new queue
    if skill == MANUAL then
      simulua.wait(manual.Q)
    else
      simulua.wait(skilled.Q)
    end
    print(string.format(
        "Job hunter %d leaves employment office at time %.1f",
        skill, simulua.time()))
  end)
end

do -- receptionist
  local receptionistQ = queue()
  receptionist = simulua.process(function()
    while true do
      if not receptionistQ:isempty() then
        simulua.hold(2)
        local customer = receptionistQ:retrieve()
        simulua.activate(customer)
      else
        simulua.hold(1)
      end
    end
  end, {Q = receptionistQ})
end

-- simulation
simulua.start(function()
  simulua.activate(receptionist)
  manual = interviewer"Manual"
  simulua.activate(manual)
  skilled = interviewer"Skilled"
  simulua.activate(skilled)
  for _, skill in ipairs{1, 2, 2, 1} do
    simulua.activate(jobhunter(skill))
    simulua.hold(2)
  end
  simulua.hold(100)
end)

