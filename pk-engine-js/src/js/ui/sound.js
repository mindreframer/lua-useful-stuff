//------------------------------------------------------------------------------
// sound.js: Sound and music
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.SoundSystem = new function()
{
  var state_;

  this.STATE = { DISABLED : 0, ON : 1, OFF : 2 }

  this.IsDisabled = function() { return state_ == this.STATE.DISABLED }
  this.IsOn = function() { return state_ == this.STATE.ON }
  this.IsOff = function() { return state_ == this.STATE.OFF }

  this.Disable = function() { state_ = this.STATE.DISABLED }
  this.SwitchOn = function() { if (!this.IsDisabled()) state_ = this.STATE.ON }
  this.SwitchOff = function() { if (!this.IsDisabled()) state_ = this.STATE.OFF }

  this.ToggleState = function()
  {
    if (!this.IsDisabled())
    {
      if (this.IsOn())
        this.SwitchOff()
      else
        this.SwitchOn()
    }
  }

  // Initialization

  this.SwitchOn()
}

PKEngine.SoundSystem.return_sound_extension_by_browser_support = function()
{
  var sound_types =
  [
    { ext: '.mp3', mime: 'audio/mpeg' },
    { ext: '.ogg', mime: 'audio/ogg; codecs=vorbis' }
  ]

  if (!window.Audio)
  {
    PKEngine.SoundSystem.Disable();
    return;
  }

  var format = undefined;

  var audio = new Audio();
  for (var i = 0; i < sound_types.length; i++)
  {
    if( audio.canPlayType(sound_types[i].mime) )
    {
      format = sound_types[i].ext
      break;
    }
  }

  if (format == undefined)
  {
    CRITICAL_ERROR(I18N('Sound format undefined!'));
    PKEngine.SoundSystem.Disable();
    return;
  }

  return format
}

PKEngine.SoundSystem.stop_and_play = function(sound, loop)
{
  if (!PKEngine.SoundSystem.IsOn())
    return;

  var audio = PKEngine.SoundStore.get(sound).handler;

  try
  {

    audio.pause();
    audio.currentTime = 0;

    if(loop)
    {
      if (audio.addEventListener)
      {
        audio.is_looped = true
        audio.addEventListener('ended', function()
            {
              if (this.is_looped)
              {
                this.currentTime = 0;
                this.play();
              }
            },
            false
          );
      }
    }

    audio.play();
  }
  catch(e)
  {
    CRITICAL_ERROR(I18N('Error pause and play audio: ${1}', audio.src));
  }
}

PKEngine.SoundSystem.stop_except = function(exceptions)
{
  if (!PKEngine.SoundSystem.IsOn())
    return;

  var sounds = PKEngine.SoundStore.get_all_sounds();

  for(var i = 0; i < sounds.length; i++)
  {
    if (exceptions.indexOf(sounds[i]) < 0) {
      PKEngine.SoundStore.get(sounds[i]).handler.pause();
    }
  }
}

PKEngine.SoundSystem.stop = function(sound)
{
  if (!PKEngine.SoundSystem.IsOn())
    return;

  var audio = PKEngine.SoundStore.get(sound).handler;
  if (!PKEngine.SoundSystem.IsOn())
    return

  try
  {
    audio.is_looped = false
    audio.pause();
    audio.currentTime = 0;
  }
  catch(e)
  {
    CRITICAL_ERROR(I18N('Error pause and play audio: ${1}', audio.src));
  }
}
