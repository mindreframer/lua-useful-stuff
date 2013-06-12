//------------------------------------------------------------------------------
// i18n.js: Internationalization
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.i18n = new function()
{
  var instance_ = this

  var language_packs_ = new Object
  var current_language_ = undefined

  //enum to use more strict typization after adding all languages
  this.language = new Object

  //----------------------------------------------------------------------------

  this.set_current_language = function(lang)
  {
    current_language_ = lang
  }

  this.get_current_language = function()
  {
    return current_language_
  }

  //----------------------------------------------------------------------------

  this.add_language_pack = function(lang, pack)
  {
    if (current_language_ === undefined)
    {
      this.set_current_language(lang)
    }

    language_packs_[lang] = pack
    this.language[lang] = lang
  }

  //----------------------------------------------------------------------------

  this.extend_language_pack = function(lang, pack)
  {
    if (language_packs_[lang] == undefined)
    {
      this.add_language_pack(lang, pack)
      return
    }

    for(var k in pack)
    {
      language_packs_[lang][k] = pack[k]
    }
  }

  //----------------------------------------------------------------------------

  this.raw_text = function(s)
  {
    // TODO: Maybe add next assert?
    //assert(s !== undefined, "No parameter for raw_text")

    var loc_text = ""

    if (current_language_ === undefined)
    {
      CRITICAL_ERROR("Current language not set! Text: " + s)
      loc_text = '<' + s + '>';
    }
    else if (!language_packs_[current_language_])
    {
      CRITICAL_ERROR("No language pack for " + current_language_ + ". Text: " + s)
      loc_text = '<' + s + '>';
    }
    else
    {
      loc_text = language_packs_[current_language_][s];
    }

    return loc_text
  }

  //----------------------------------------------------------------------------

  this.text = function(s)
  {
    // Note: Error message not localized:-)
    assert( s !== undefined, 'No parameters for PK.i18n.text()')

    var loc_text = instance_.raw_text(s)

    if(loc_text === undefined)
    {
      //console.log("not found string: `" + s + "`")
      //LOG("'" + s + "' : '',");
      return '*' + s + '*';
    }

    if (arguments.length == 1)
    {
      return loc_text
    }

    // Note: Commented code is more correct, but a bit slower
    //var fs_args = Array.prototype.slice.call(arguments, 1)
    //fs_args.unshift(loc_text)
    var fs_args = arguments
    fs_args[0] = loc_text

    var result = PK.formatString.apply(window, fs_args)
    //console.log(loc_text, ' -> ', result, fs_args)

    return result
  }

}

var I18N = PK.i18n.text
