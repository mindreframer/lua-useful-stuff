//------------------------------------------------------------------------------
// time.js: Time functions
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.check_namespace('Time');

PK.Time.get_current_timestamp = function()
{
  return ((new Date)*1 - 1);
}
