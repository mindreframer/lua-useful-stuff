//------------------------------------------------------------------------------
// loader.js: Loading of resources: check, draw
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

/**
 * Loader
 */
PKEngine.Loader = new function ()
{
  var loader_back_img_ = undefined;
  var loader_line_img_ = undefined;
  var preloader_resource_count_ = 0;

  /**
   * Callback
   */
  var on_preloader_initialized_ = undefined;

  /**
   * Callback
   */
  var on_resource_loading_complete_ = undefined;

  var last_loading_progress_ = 0;
  var resources_loaded_ = false;

  /**
  * Dom ids
  */
  var loader_id_ = 'div_loader';
  var resources_id_ = 'resources';

  /**
   * Returns object containing ids and paths
   *
   * @param img_path
   * @param lang
   */
  this.make_images_config = function (img_path, lang)
  {
    return {
      'preloader_background': img_path + "loader/preloader_" + lang + ".jpg",
      'preloader_progressbar': img_path + "loader/loader_line.png",
      'spacer_top': img_path + "spacer_top.png",
      'spacer_bottom': img_path + "spacer_bottom.png",
      'error_label': img_path + "error/" + lang + "/label_error.png",
      'close_button': img_path + "buttons/" + lang + "/btn_close.png",
      'error_window_bg': img_path + "error/bg_window.jpg"
    };
  }

  /**
   * Initialize loader with params
   *
   * @param on_preloader_initialized callback
   * @param on_resource_loading_complete callback
   * @param loader_id DOM id
   * @param resources_id DOM id
   * @param images object containing ids and paths, returns by make_images_config
   */
  this.init = function (on_preloader_initialized,
    on_resource_loading_complete,
    loader_id,
    resources_id,
    images)
  {
    on_preloader_initialized_ = on_preloader_initialized;
    on_resource_loading_complete_ = on_resource_loading_complete;
    loader_id_ = loader_id;
    resources_id_ = resources_id;

    $('<div id="'+resources_id_+'" style="display: none;">')
        .appendTo($('#' + loader_id_));

    /**
     * Shortcut
     * @param image_name
     */
    var create_image = function (image_name)
    {
      return $('<img/>', { src: images[image_name], id: image_name });
    };

    loader_back_img_ = create_image('preloader_background')
      .load(PKEngine.Loader.check_preloader_ready)
      .error(
          function ()
          {
            CRITICAL_ERROR(I18N('Cant load loader background!'));
          }
      )
      .appendTo($('#' + loader_id_))[0];

    loader_line_img_ = create_image('preloader_progressbar')
      .load(PKEngine.Loader.check_preloader_ready)
      .error(
          function ()
          {
            CRITICAL_ERROR(I18N('Cant load loader progress bar!'));
          }
      )
      .appendTo($('#' + resources_id_))[0];

    create_image('spacer_top')
      .load(PKEngine.Loader.check_preloader_ready)
      .appendTo($('#' + resources_id_));
    create_image('spacer_bottom')
      .load(PKEngine.Loader.check_preloader_ready)
      .appendTo($('#' + resources_id_));
    create_image('error_label')
      .load(PKEngine.Loader.check_preloader_ready)
      .appendTo($('#' + resources_id_));
    create_image('close_button')
      .load(PKEngine.Loader.check_preloader_ready)
      .appendTo($('#' + resources_id_));
    create_image('error_window_bg')
      .load(PKEngine.Loader.check_preloader_ready)
      .appendTo($('#' + resources_id_));
  }

  /**
   * Check if preloader ready
   */
  this.check_preloader_ready = function ()
  {
    preloader_resource_count_ += 1;

    if (preloader_resource_count_ > $('#' + resources_id_ + ' img').length)
    {
      if (on_preloader_initialized_)
      {
        on_preloader_initialized_();
      }
    }
  }

  /**
   * Switch to canvas, show game field
   */
  this.switch_to_canvas = function ()
  {
    // Hide temporary div to prevent influence on layout
    $('#' + loader_id_).hide();
    var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
    game_field_2d_cntx.drawImage(loader_back_img_, 0, 0);
    loader_back_img_.is_drawn = true;
    PKEngine.GUI.Viewport.show_game_field();
  }

  /**
   * Check loaded data
   */
  this.check_loaded_data = function ()
  {
    if (resources_loaded_) return;

    if (!loader_back_img_.is_drawn)
    {
      PKEngine.Loader.switch_to_canvas();
    }

    // graphics

    var loading_progress = PKEngine.GraphicsStore.count_loaded();
    var all_resources = PKEngine.GraphicsStore.count_total();

    // audio

    if (!PKEngine.SoundSystem.IsDisabled())
    {
      loading_progress += PKEngine.SoundStore.count_loaded();
      all_resources += PKEngine.SoundStore.count_total();
    }

    if(loading_progress > last_loading_progress_)
    {
      last_loading_progress_ = loading_progress;

      var pb_width = Math.ceil(loader_line_img_.width * loading_progress / all_resources);
      if (pb_width > loader_line_img_.width)
      {
        pb_width = loader_line_img_.width;
      }
      PKEngine.reset_shadow();
      var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
      game_field_2d_cntx.drawImage(
        loader_line_img_,
        0, 0,
        pb_width, loader_line_img_.height,
        PKEngine.GUIControls.get_loader_parameters().line_coords.x,
        PKEngine.GUIControls.get_loader_parameters().line_coords.y,
        pb_width, loader_line_img_.height
      );
    }

    if (loading_progress >= all_resources)
    {
      resources_loaded_ = true;
      if (on_resource_loading_complete_)
      {
        on_resource_loading_complete_();
      }
      return;
    }

    setTimeout(PKEngine.Loader.check_loaded_data, 1000 / PKEngine.Const.MAXIMUM_FPS);
  }

  /**
   * Returns if resources are loaded
   */
  this.resources_are_loaded = function ()
  {
    return resources_loaded_;
  }

}
