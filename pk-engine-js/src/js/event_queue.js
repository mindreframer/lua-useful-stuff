//------------------------------------------------------------------------------
// event_queue.js: Queue of events which should be run
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.EventQueue = new function()
{
  var queue_ = []

  this.push = function(event)
  {
    queue_.push(event)
  }

  this.run = function()
  {
    for (var i = 0; i < queue_.length; i++)
      queue_[i].run()
    queue_.length = 0
  }
}
