//------------------------------------------------------------------------------
// web_storage.js: Web Storage
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Note: Localization for 'ERROR: no localStorage() support!'
// and 'WebStorage ERROR: QUOTA_EXCEEDED_ERR' must be implemented in user code
//
//------------------------------------------------------------------------------

PK.WebStorage = new function()
{
  var available_ = false;

  this.available = function()
  {
    return available_;
  }

  this.init = function()
  {
    if (window.localStorage === undefined)
    {
      LOG(I18N('ERROR: no localStorage() support!'));
      return false;
    }
    available_ = true;
    return true;
  }

  this.read_item = function(key)
  {
    if (!this.available())
      return;

    if (!key)
      return;

    return localStorage.getItem(key);
  }

  this.set_item = function(key, value)
  {
    if (!this.available())
      return;

    if (!key)
      return;

    try
    {
      localStorage.setItem(key, value);
    }
    catch (e)
    {
      if (e == QUOTA_EXCEEDED_ERR)
      {
        LOG(I18N('WebStorage ERROR: QUOTA_EXCEEDED_ERR'));
        return false;
      }
    }
    return true;
  }

  this.remove_item = function(key)
  {
    if (!this.available())
      return;

    if (!key)
      return;

    return localStorage.removeItem(key);
  }
}
