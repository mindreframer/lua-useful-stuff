//------------------------------------------------------------------------------
// sound_store.js: Sound store
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.SoundStore = new function()
{
  var sounds_ = {};
  var loaded_sounds_ = 0;
  var total_sounds_ = 0;
  var errors_ = [];
  var on_error_ = undefined;

  var MEDIA_ERROR_CODES =
    [
      'MEDIA_UNDEFINED_ERROR',
      'MEDIA_ERR_ABORTED',
      'MEDIA_ERR_NETWORK',
      'MEDIA_ERR_DECODE',
      'MEDIA_ERR_SRC_NOT_SUPPORTED'
    ];
  this.loading_complete = false;

  function resource_failed_(sound)
  {
    var audio = sounds_[sound].handler;

    if (audio && audio.error && audio.error.code > 0 && errors_)
    {
      errors_.push(audio.src + " get error_code=" + audio.error.code + "\n" + MEDIA_ERROR_CODES[audio.error.code]);
    }

    delete sounds_[sound].handler;
    resource_loading_finished_(sound);
  }

  function resource_loading_finished_(sound)
  {
    //In case the resource loading wasn't canceled by timeout
    if (!sounds_[sound].loaded)
    {
      sounds_[sound].loaded = true;
      loaded_sounds_ += 1;
    }

    //All images was loaded, successfully or not
    if (loaded_sounds_ >= total_sounds_ && !this.loading_complete)
    {
      this.loading_complete = true;
      if (errors_ && errors_.length > 0 && on_error_)
      {
        on_error_(errors_);
      }
    }
  }

  this.load_sounds = function(config)
  {
    var store = this,
      soundFormat = PKEngine.SoundSystem.return_sound_extension_by_browser_support();

    loaded_sounds_ = 0;
    total_sounds_ = PK.count_properties(PKEngine.SoundConfig.Sounds);

    for(var sound in config.Sounds)
    {
      sounds_[sound] =
      {
        'loaded' : false,
        'handler': new Audio()
      };

      if (!sounds_[sound].handler.addEventListener)
      {
        this.resource_failed_(sound);
        continue;
      }

      sounds_[sound].handler.src = config.AudioPath + config.Sounds[sound] + soundFormat + PKEngine.Const.ANTI_CACHE;
      sounds_[sound].handler.addEventListener("canplaythrough", (function(sound)
      {
        return function()
        {
          resource_loading_finished_(sound);
        }
      })(sound), false);

      sounds_[sound].handler.onerror = (function(sound)
      {
        return function()
        {
          resource_failed_(sound);
        }
      })(sound);

      sounds_[sound].handler.load();
    }

    setTimeout(function()
    {
      var errors = [];
      for(var sound in sounds_)
      {
        if (!sounds_[sound].loaded) {
          var audio = sounds_[sound].handler;
          delete sounds_[sound].handler;
          resource_loading_finished_(sound);
          errors.push(audio.src + " timeout");
          errors_ = false;
        }
      }

      if (errors.length > 0) {
        on_error_(errors);
      }
    }, PKEngine.Const.RESOURCES_LOADING_TIMEOUT);
  }

  this.get = function(sound)
  {
    return sounds_[sound];
  }

  this.get_all_sounds = function()
  {
    var sounds = [];
    for(var sound in sounds_)
    {
      sounds.push(sound);
    }

    return sounds;
  }

  this.count_loaded = function()
  {
    return loaded_sounds_;
  }

  this.count_total = function()
  {
    return total_sounds_;
  }

  this.set_error_handler = function(callback)
  {
    on_error_ = callback;
  }
}
