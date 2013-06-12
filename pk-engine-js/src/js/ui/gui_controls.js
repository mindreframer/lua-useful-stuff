//------------------------------------------------------------------------------
// gui_controls.js: GUI Controls
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.GUIControls = new function()
{
  var config_ = {}

  // Actually each screen is a singleton
  this.screens_by_class_name_ = {}

  //---------------------------------------------------------------------------

  this.init = function(gui_config, language)
  {
    config_ = gui_config.init(language)
  }

  //---------------------------------------------------------------------------

  this.SCREEN_NAMES = {}

  this.get_screen = function(name)
  {
    return assert(this.screens_by_class_name_[name], I18N('Screen not found: ${1}', name))
  }


  //---------------------------------------------------------------------------

  this.load_graphics = function()
  {
    if (config_.image_resources)
    {
      // Note: common images would be stored in GraphicsStore only,
      //       no other (global) container stores them

      var panel_name_ = 'global'
      var image_config_ = config_.image_resources

      // TODO: Generalize, this is copy-paste from panel
      for(var name in image_config_)
      {
        if(typeof image_config_[name] == 'object')
        {
          var image_set = image_config_[name]
          for(var key in image_set)
          {
            assert(typeof key == 'string', I18N('Bad image set key: ${1}', (panel_name_ + "." + name)))
            assert(
              typeof image_set[key] == 'string',
              I18N('Bad image set src: ${1}', (panel_name_ + "." + name))
            )
            PKEngine.GraphicsStore.add(
                name + "." + key, image_set[key] + PKEngine.Const.ANTI_CACHE,
                PKEngine.Loader.check_loaded_data, PK.image_loading_error
              )
          }
        }
        else
        {
          assert(typeof name == 'string', I18N('Bad image set key: ${1}', panel_name_))
          assert(
            typeof image_config_[name] == 'string',
            I18N('Bad image set src: ${1}', (panel_name_ + "." + name))
          )
          PKEngine.GraphicsStore.add(
              name, image_config_[name] + PKEngine.Const.ANTI_CACHE,
              PKEngine.Loader.check_loaded_data, PK.image_loading_error
            )
        }
      }
    }


    for(var control_name in config_.screens)
    {
      var class_name = control_name

      var screen = assert(PKEngine.GUIControlFactory[class_name](), I18N('Cannot create panel: ${1}', class_name))

      this.screens_by_class_name_[control_name] = screen

      this.SCREEN_NAMES[control_name] = class_name

      screen.init({ class_config: this.get_control_config(class_name) })
    }
  }

  this.get_control_config = function(name) { return config_.controls[name]; }

  this.get_image_folder = function() { return config_.img_folder; }

  this.get_size = function() { return config_.size; }
  this.get_center = function() { return config_.center; }

  this.get_common_background = function(name)
  {
    if (name === undefined)
      name = 'default'
    if(config_ && config_.common_backgrounds && config_.common_backgrounds[name])
      return config_.common_backgrounds[name];
    return false
  }

  this.get_common_font = function(name)
  {
    if (name === undefined)
      name = 'default'
    if(config_.common_fonts && config_.common_fonts[name])
      return config_.common_fonts[name];
    return false
  }

  this.get_loader_parameters = function() { return config_.loader; }
}
