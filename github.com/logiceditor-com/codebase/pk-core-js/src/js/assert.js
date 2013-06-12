//------------------------------------------------------------------------------
// assert.js: Assert function
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

function assert(cond, msg)
{
  if (cond)
  {
    return cond
  }
  CRITICAL_ERROR("Assertion failed: " + String(msg))
  return undefined
}
