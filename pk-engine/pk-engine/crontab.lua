--------------------------------------------------------------------------------
-- crontab.lua: stores crons, determines next occurrence of cron
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

-- Crontab format ("hash"):
--
-- {
--   s          = "*";
--   m          = "*";
--   h          = "*";
--   dom        = "*";
--   mon        = "*";
--   dow        = "*";
--   group      = "cron_group_name";
--   log        = "cron_log_filename";
--   channel    = "task_processor_channel_name";
--   task       = "task_name";
--   task_args  = {args};
-- }
--
--
-- Alternative crontab format ("array"):
--
-- "*","*","*","*","*","*", "gr", "fn", "cn", "tn", {args}
--  ^   ^   ^   ^   ^   ^     ^     ^     ^     ^     ^
--  |   |   |   |   |   |     |     |     |     |     |
--  |   |   |   |   |   |     |     |     |     |     +- task arguments
--  |   |   |   |   |   |     |     |     |     +------- task name
--  |   |   |   |   |   |     |     |     -------------- task processor channel name
--  |   |   |   |   |   |     |     |
--  |   |   |   |   |   |     |     +------------------- cron log filename
--  |   |   |   |   |   |     +------------------------- cron group name
--  |   |   |   |   |   |
--  |   |   |   |   |   +------------------------------- day of week (0 - 6) (Sunday=0)
--  |   |   |   |   +----------------------------------- month (1 - 12)
--  |   |   |   +--------------------------------------- day of month (1 - 31)
--  |   |   +------------------------------------------- hour (0 - 23)
--  |   +----------------------------------------------- min (0 - 59)
--  +--------------------------------------------------- sec (0 - 59)
--
-- Cron table is a bit complex thing, but we support only few things
-- (see http://en.wikipedia.org/wiki/CRON_expression for full description)
--
-- +-----------------------------------------------------+
-- |    FIELD     |     VALUES      | SPECIAL CHARACTERS |
-- +--------------+-----------------+--------------------+
-- | Seconds      | 0-59            |       , - *        |
-- | Minutes      | 0-59            |       , - *        |
-- | Hours        | 0-23            |       , - *        |
-- | Day of month | 1-31            |       , - *        |
-- | Month        | 1-12 or JAN-DEC |       , - *        |
-- | Day of week  | 0-6 or SUN-SAT  |       , - *        |
-- +-----------------------------------------------------+
--

--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("crontab", "CTB")

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local assert_is_number,
      assert_is_table,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_number',
        'assert_is_table',
        'assert_is_string'
      }

local is_number,
      is_string,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_number',
        'is_string',
        'is_table'
      }

local tcount_elements,
      tiflip,
      tijoin_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'tcount_elements',
        'tiflip',
        'tijoin_many'
      }

--------------------------------------------------------------------------------

-- TODO: Generalize to lua-nucleo
local make_timestamp = function(dom, mon, y, h, m, s)
  arguments(
      "number", dom,
      "number", mon,
      "number", y,
      "number", h,
      "number", m,
      "number", s
    )

  return
  {
    day = dom;
    month = mon;
    year = y;
    hour = h;
    min = m;
    sec = s;
  }
end

-- TODO: Generalize to lua-nucleo
local unpack_time = function(timestamp)
  arguments(
      "number", timestamp
    )
  local t = os.date("*t", timestamp)
  return t.year, t.month, t.day, t.hour, t.min, t.sec
end

-- TODO: Generalize to lua-nucleo
-- from http://lua-users.org/wiki/DayOfWeekAndDaysInMonthExample
local get_days_in_month = function(year, month)
  arguments(
      "number", year,
      "number", month
    )

  local days_in_month = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local d = days_in_month[month]

  -- check for leap year
  if month == 2 then
    if math.mod(year,4) == 0 then
     if math.mod(year,100) == 0 then
      if math.mod(year,400) == 0 then
          d = 29
      end
     else
      d = 29
     end
    end
  end

  return d
end

-- TODO: Generalize to lua-nucleo
-- from http://richard.warburton.it
local get_day_of_week = function(timestamp)
  arguments(
      "number", timestamp
    )
  return os.date('*t',timestamp)['wday'] - 1
end

-- TODO: Generalize to lua-nucleo
local day_of_week_name_to_number, month_name_to_number
do
  local months =
  {
    ["1"] = 1; ["2"] = 2; ["3"] = 3; ["4"] = 4; ["5"] = 5; ["6"] = 6;
    ["7"] = 7; ["8"] = 8; ["9"] = 9; ["10"] = 10; ["11"] = 11; ["12"] = 12;
    --
    ["january"]   =  1;
    ["february"]  =  2;
    ["march"]     =  3;
    ["april"]     =  4;
    ["may"]       =  5;
    ["june"]      =  6;
    ["july"]      =  7;
    ["august"]    =  8;
    ["september"] =  9;
    ["october"]   = 10;
    ["november"]  = 11;
    ["december"]  = 12;
    -- guffy names
    ["jan"] = 1; ["feb"] = 2; ["mar"] = 3; ["apr"] = 4; ["may"] = 5; ["jun"] = 6;
    ["jul"] = 7; ["aug"] = 8; ["sep"] = 9; ["oct"] = 10; ["nov"] = 11; ["dec"] = 12;
  }

  local days_of_week =
  {
    ["0"] = 0; ["1"] = 1; ["2"] = 2; ["3"] = 3; ["4"] = 4; ["5"] = 5; ["6"] = 6;
    --
    ["sunday"]    = 0;
    ["monday"]    = 1;
    ["tuesday"]   = 2;
    ["wednesday"] = 3;
    ["thursday"]  = 4;
    ["friday"]    = 5;
    ["saturday"]  = 6;
    -- guffy names
    ["sun"] = 0;
    ["mon"] = 1;
    ["tue"] = 2;
    ["wed"] = 3;
    ["thu"] = 4;
    ["fri"] = 5;
    ["sat"] = 6;
  }

  day_of_week_name_to_number = function(v)
    arguments(
        "string", v
      )
    return days_of_week[v:lower()]
  end

  month_name_to_number = function(v)
    arguments(
        "string", v
      )
    return months[v:lower()]
  end
end

--------------------------------------------------------------------------------

-- TODO: Refactor! Then write tests and move to separate file or even to lua-nucleo
local make_enumerator_from_set, make_enumerator_from_interval
do
  local get_first = function(self)
    method_arguments(self)
    return self.min_value_
  end

  local get_next = function(self, value)
    method_arguments(
        self,
        "number", value
      )
    if value <= self.min_value_ then return self.min_value_ end
    if value  > self.max_value_ then return nil end
    return assert(self.next_values_[value])
  end

  local contains = function(self, value)
    method_arguments(
        self,
        "number", value
      )
    return value >= self.min_value_ and value <= self.max_value_
      and self.next_values_[value] == value
  end

  make_enumerator_from_set = function(values)
    arguments(
        "table", values
      )

    local next_values
    do
      next_values = {}
      local curr_index = 1
      for i = values[1], values[#values] do
        if i > values[curr_index] then curr_index = curr_index + 1 end
        assert(i <= values[curr_index])
        next_values[i] = values[curr_index]
      end
    end

    return
    {
      get_first = get_first;
      get_next = get_next;
      contains = contains;
      --
      values_ = values;
      min_value_ = values[1];
      max_value_ = values[#values];
      next_values_ = next_values;
    }
  end

  make_enumerator_from_interval = function(first, last)
    arguments(
        "number", first,
        "number", last
      )
    local values = {}
    for i = first, last do values[#values + 1] = i end
    return make_enumerator_from_set(values)
  end
end

--------------------------------------------------------------------------------

local make_cron
do
  local make_enumerator_array
  do
    local get_first_till = function(self, max_enumerator)
      method_arguments(
          self
        )
      optional_arguments(
          "table", max_enumerator
        )
      local values = {}
      for i = 1, #self.enumerators_ do
        local current = self.enumerators_[i]
        values[#values + 1] = current:get_first()
        if current == max_enumerator then
          break
        end
      end
      return unpack(values)
    end

    make_enumerator_array = function(...)
      return
      {
        get_first_till = get_first_till;
        --
        enumerators_ = {...};
      }
    end
  end

  -- TODO: Generalize to lua-nucleo
  local MAX_TIMESTAMP = 2^31 - 1

  local MAX_ITERATIONS = MAX_TIMESTAMP

  local get_next_occurrence = function(self, base_time)
    method_arguments(
        self,
        "number", base_time
      )
    return self:get_next_occurrence_till(base_time, MAX_TIMESTAMP)
  end

  local get_next_occurrence_till = function(self, base_timestamp, end_timestamp)
    method_arguments(
        self,
        "number", base_timestamp,
        "number", end_timestamp
      )

--     spam(
--        "get_next_occurrence_till:",
--        "start =", os.date("%c", base_timestamp),
--        "end =", os.date("%c", end_timestamp)
--      )

    local SECONDS = self.seconds_
    local MINUTES = self.minutes_
    local HOURS = self.hours_
    local DAYS = self.days_
    local MONTHS = self.months_
    local DAYS_OF_WEEK = self.days_of_week_

    local enumerator_array = make_enumerator_array(SECONDS, MINUTES, HOURS, DAYS, MONTHS)

    local baseYear,
          baseMonth,
          baseDay,
          baseHour,
          baseMinute,
          baseSecond = unpack_time(base_timestamp)

    local endYear, endMonth, endDay = unpack_time(end_timestamp)

    local year = baseYear
    local month = baseMonth
    local day = baseDay
    local hour = baseHour
    local minute = baseMinute
    local second = baseSecond + 1
    --spam(
    --    "year", year, ", month", month, ", day", day,
    --    ", hour", hour, ", minute", minute, ", second", second
    --  )

    -- Second
    second = SECONDS:get_next(second)
    if not second then
      second = enumerator_array:get_first_till(SECONDS)
      minute = minute + 1
    end
   -- spam("minute, second =", minute, second)

    -- Minute
    minute = MINUTES:get_next(minute)
    if not minute then
      second, minute = enumerator_array:get_first_till(MINUTES)
      hour = hour + 1
    elseif minute > baseMinute then
      second = enumerator_array:get_first_till(SECONDS)
    end
   -- spam("hour, minute, second =", hour, minute, second)

    -- Hour
    hour = HOURS:get_next(hour)
    if not hour then
      second, minute, hour = enumerator_array:get_first_till(HOURS)
      day = day + 1
    elseif hour > baseHour then
      second, minute = enumerator_array:get_first_till(MINUTES)
    end
    --spam("day, hour, minute, second =", day, hour, minute, second)

    -- Day
    day = DAYS:get_next(day)
    --spam("again day, hour, minute, second =", day, hour, minute, second)

    local iterations = 0
    while true and iterations < MAX_ITERATIONS do
      iterations = iterations + 1
      if not day then
        second, minute, hour, day = enumerator_array:get_first_till(DAYS)
        month = month + 1
      elseif day > baseDay then
        second, minute, hour = enumerator_array:get_first_till(HOURS)
      end
      --spam("ita " .. iterations .. ": month, day, hour, minute, second =",
      --    month, day, hour, minute, second
      --  )

      -- Month
      month = MONTHS:get_next(month)
      if not month then
        second, minute, hour, day, month = enumerator_array:get_first_till(MONTHS)
        year = year + 1
      elseif month > baseMonth then
        second, minute, hour, day = enumerator_array:get_first_till(DAYS)
      end
      --spam("itb " .. iterations .. ": year, month, day, hour, minute, second =",
      --    year, month, day, hour, minute, second
      --  )

      --
      -- The day field in a cron expression spans the entire range of days
      -- in a month, which is from 1 to 31. However, the number of days in
      -- a month tend to be variable depending on the month (and the year
      -- in case of February). So a check is needed here to see if the
      -- date is a border case. If the day happens to be beyond 28
      -- (meaning that we're dealing with the suspicious range of 29-31)
      -- and the date part has changed then we need to determine whether
      -- the day still makes sense for the given year and month. If the
      -- day is beyond the last possible value, then the day/month part
      -- for the schedule is re-evaluated. So an expression like "0 0
      -- 15,31 * *" will yield the following sequence starting on midnight
      -- of Jan 1, 2000:
      --
      --  Jan 15, Jan 31, Feb 15, Mar 15, Apr 15, Apr 31, ...
      --

      local dateChanged = day ~= baseDay or month ~= baseMonth or year ~= baseYear
      --spam("itb " .. iterations .. ": dateChanged =", dateChanged)

      if day > 28 and dateChanged and day > get_days_in_month(year, month) then
        if year >= endYear and month >= endMonth and day >= endDay then
          return false
        end
        day = nil
      else
        break;
      end
    end

    if iterations >= MAX_ITERATIONS then
      return nil, "endless loop detected"
    end

    --spam("after loop: y, m, d, h, min, s =", year, month, day, hour, minute, second)

    local next_timestamp = os.time(make_timestamp(day, month, year, hour, minute, second))
    if next_timestamp > end_timestamp then
      --spam("bad result is: ", os.date("%c", end_timestamp))
      return nil, "next occurrence is after end date"
    end

    -- Day of week
    if DAYS_OF_WEEK:contains(get_day_of_week(next_timestamp)) then
      --spam("result is: ", os.date("%c", next_timestamp))
      return next_timestamp
    end

    local new_base_timestamp = os.time(make_timestamp(day, month, year, 23, 59, 59))

    return self:get_next_occurrence(new_base_timestamp, end_timestamp)
  end


  local load_cron_property = function(value, minv, maxv)
    --spam("load_crop_property", value)
    if is_number(value) then
      return make_enumerator_from_interval(value, value)
    elseif is_table(value) then
      return make_enumerator_from_set(value)
    end
    return make_enumerator_from_interval(minv, maxv)
  end

  make_cron = function(cron_properties)
    arguments(
        "table", cron_properties
      )

    local seconds      = load_cron_property(cron_properties.seconds,      0, 59)
    local minutes      = load_cron_property(cron_properties.minutes,      0, 59)
    local hours        = load_cron_property(cron_properties.hours,        0, 23)
    local days         = load_cron_property(cron_properties.days,         1, 31)
    local months       = load_cron_property(cron_properties.months,       1, 12)
    local days_of_week = load_cron_property(cron_properties.days_of_week, 0,  6)

    return
    {
      get_next_occurrence = get_next_occurrence;
      get_next_occurrence_till = get_next_occurrence_till;
      --
      seconds_      = seconds;
      minutes_      = minutes;
      hours_        = hours;
      days_         = days;
      months_       = months;
      days_of_week_ = days_of_week;
      group_        = assert_is_string(cron_properties.group);
      log_          = assert_is_string(cron_properties.log);
      channel_      = assert_is_string(cron_properties.channel);
      task_         = assert_is_string(cron_properties.task);
      task_args_    = assert_is_table(cron_properties.task_args);
    }
  end
end
-------------------------------------------------------------------------------

local make_cron_properties
do
  local load_date_field
  do
    local load_interval = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )

      local start_s, end_s = data:match("(%w+)%-(%w+)")
      if not start_s or not end_s then
        error("load_interval: can't parse cron property: `" .. data .."'")
      end

      local start_v, end_v = value_extractor(start_s), value_extractor(end_s)
      if not start_v then
        error("load_interval: can't extract value: `" .. start_s .."'")
      elseif not end_v then
        error("load_interval: can't extract value: `" .. end_s .."'")
      end

      if start_v > end_v then
        error("load_interval: invalid interval: " .. start_v, " > ", end_v)
      end

      local values = {}
      for i = start_v, end_v do
        values[#values + 1] = i
      end
      return values
    end

    local load_single_value = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )

      if data:find("-") then
        return load_interval(data, value_extractor)
      end

      local value = value_extractor(data)
      if not value then
        error("load_single_value: can't parse cron property: `" .. data .."'")
      end

      return value
    end

    local load_array = function(data, value_extractor)
      arguments(
          "string", data,
          "function", value_extractor
        )
      local values = {}

      for v in data:gmatch("(.[^,]*),*") do
        local value = load_single_value(v, value_extractor)

        if is_number(value) then
          values[#values + 1] = value
        elseif is_table(value) then
          tijoin_many(values, value)
        else
          log_error("load_array: invalid value type:", value)
          error("load_array: can't process value type: `" .. type(value) .."'")
        end
      end

      table.sort(values)
      return values
    end

    load_date_field = function(field_data, value_extractor)
      arguments(
          "function", value_extractor
        )

      if field_data == nil or field_data == "*" then
        return nil
      elseif is_number(field_data) then
        return load_single_value(tostring(field_data), value_extractor)
      elseif field_data:find(",") then
        return load_array(field_data, value_extractor)
      end

      return load_single_value(field_data, value_extractor)
    end
  end

  local make_string_to_number_converter = function(minv, maxv)
    arguments(
        "number", minv,
        "number", maxv
      )
    assert(minv <= maxv)
    return function(v)
      arguments(
          "string", v
        )
      local n = tonumber(v)
      if not n then error('not a number: ' .. v) end
      if n < minv then error('too small value: ' .. n) end
      if n > maxv then error('too big value: ' .. n) end
      return n
    end
  end

  -- TODO: Check validity (including extra fields as minor)
  local make_cron_properties_from_hash = function(data)
    arguments(
        "table", data
      )
    --spam("make_cron_properties_from_hash", data)
    return
    {
      seconds = load_date_field(data.s, make_string_to_number_converter(0,59));
      minutes = load_date_field(data.m, make_string_to_number_converter(0,59));
      hours = load_date_field(data.h, make_string_to_number_converter(0,23));
      days = load_date_field(data.dom, make_string_to_number_converter(1,31));
      months = load_date_field(data.mon, month_name_to_number);
      days_of_week = load_date_field(data.dow, day_of_week_name_to_number);

      group = assert_is_string(data.group);
      log = assert_is_string(data.log);

      channel = assert_is_string(data.channel);
      task = assert_is_string(data.task);
      task_args = assert_is_table(data.task_args);
    }
  end

  local make_cron_properties_from_array = function(data)
    arguments(
        "table", data
      )
    return make_cron_properties_from_hash(
        {
          s         = data[ 1];
          m         = data[ 2];
          h         = data[ 3];
          dom       = data[ 4];
          mon       = data[ 5];
          dow       = data[ 6];
          group     = data[ 7];
          log       = data[ 8];
          channel   = data[ 9];
          task      = data[10];
          task_args = data[11];
        }
      )
  end

  make_cron_properties = function(raw_cron_data)
    arguments(
        "table", raw_cron_data
      )

    if tcount_elements(raw_cron_data) == #raw_cron_data then
      return make_cron_properties_from_array(raw_cron_data)
    end

    return make_cron_properties_from_hash(raw_cron_data)
  end
end

-------------------------------------------------------------------------------

local make_raw_cron_data_from_string = function(
    date,
    group,
    logn,
    channel,
    task,
    task_args,
    as_hash
  )
  arguments(
      "string", date,
      "string", group,
      "string", logn,
      "string", channel,
      "string", task,
      "table",  task_args
    )
  optional_arguments(
      "boolean", as_hash
    )
  if as_hash == nil then as_hash = false end

  local seconds, minutes, hours, days, months, days_of_week = date:match(
      "%s*"
      .. "(.[^%s]*)" .. "%s*"
      .. "(.[^%s]*)" .. "%s*"
      .. "(.[^%s]*)" .. "%s*"
      .. "(.[^%s]*)" .. "%s*"
      .. "(.[^%s]*)" .. "%s*"
      .. "(.[^%s]*)" .. "%s*"
    )

  if as_hash then
    return
      {
        s   = seconds;
        m   = minutes;
        h   = hours;
        dom = days;
        mon = months;
        dow = days_of_week;

        group = group;
        log   = logn;

        channel   = channel;
        task      = task;
        task_args = task_args;
      }
  end

  return
  {
    seconds, minutes, hours, days, months, days_of_week, group, logn, channel, task, task_args
  }
end

-------------------------------------------------------------------------------

local make_crontab = function(raw_crontab_data)
  arguments(
      "table", raw_crontab_data
    )
  local crons = {}
  for i = 1, #raw_crontab_data do
    crons[#crons + 1] = make_cron_properties(raw_crontab_data[i])
  end
  return crons
end

return
{
  make_timestamp = make_timestamp;
  make_crontab = make_crontab; -- crontab contains cron_properties
  make_cron_properties = make_cron_properties;
  make_raw_cron_data_from_string = make_raw_cron_data_from_string;
  make_cron = make_cron;
}
