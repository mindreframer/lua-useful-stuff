//------------------------------------------------------------------------------
// cookies.js: Cookies module
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Note: jQuery required
//
//------------------------------------------------------------------------------

PK.check_namespace('Cookies');

PK.Cookies.set_longlive_cookie = function(key, value, options)
{
  options = options || {};
  options.expires = 365;
  $.cookie(key, value, options);
}
