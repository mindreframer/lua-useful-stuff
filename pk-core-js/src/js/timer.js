//------------------------------------------------------------------------------
// timer.js: Timer
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.Timer = new function()
{
  this.make = function() { return new function()
  {
    var start_, period_

    this.start = function(period) // period in ms
    {
      period_ = period
      start_ = PK.Time.get_current_timestamp()
    }

    this.reset = function()
    {
      start_ = undefined
      period_ = undefined
    }

    this.is_complete = function()
    {
      if (!start_)
        return true

      if (PK.Time.get_current_timestamp() < start_ + period_)
        return false

      this.reset()

      return true
    }
  }}
}
