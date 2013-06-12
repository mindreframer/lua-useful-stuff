//------------------------------------------------------------------------------
// platform.js: Platform
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.Platform = new function()
{
  var platform_type_;
  var DETECT_IPAD_ONLY_ = true;

  this.TYPE = { UNKNOWN : 0, PC : 1, IPAD : 2, SGT : 3 }

  this.detect = function(dbg_platform)
  {
    if (dbg_platform)
    {
      switch(dbg_platform)
      {
        case "PC":
          platform_type_ = this.TYPE.PC;
          break;
        case "IPAD":
          platform_type_ = this.TYPE.IPAD;
          break;
        case "SGT":
          platform_type_ = this.TYPE.SGT;
          break;
        default:
          LOG(I18N('Invalid dbg_platform: ${1}', dbg_platform))
          platform_type_ = this.TYPE.PC;
      }
      return platform_type_;
    }

    platform_type_ = this.TYPE.PC;

    if (!DETECT_IPAD_ONLY_)
    {
      if (navigator.userAgent.indexOf("iPhone3C1") != -1)
      {
        platform_type_ = "iphone4g";
      }
      else if (
          navigator.userAgent.indexOf("Android") != -1 ||
          navigator.userAgent.indexOf("iPhone") != -1 ||
          navigator.userAgent.indexOf("iPod") != -1
        )
      {
        platform_type_ = "iphone_android";
      }
    }

    if (navigator.userAgent.indexOf("iPad") != -1)
    {
      platform_type_ = this.TYPE.IPAD;
    }

    return platform_type_;
  }

  // Note: Normally you should never call this method, it's left only for quickfixes!
  this.get_type = function()
  {
    CRITICAL_ERROR(I18N("PKEngine.Platform.get_type called! Call this function only for quickfixes!"))

    return platform_type_;
  }
}
