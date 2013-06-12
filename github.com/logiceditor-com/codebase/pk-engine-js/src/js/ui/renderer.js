//------------------------------------------------------------------------------
// renderer.js: Renderer
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

PKEngine.GUI.Renderer = new function()
{
  var PERIOD_ = 1000 // ms
  var FPS_RECT_ = { top: 0, left: 0, bottom: 50, right: 100 }

  var must_draw_fps_ = false

  var last_period_end_time_ = 0, last_frame_time_ = 0
  var frames_in_current_period_ = 0

  var fps_ = 0
  var max_frame_interval_ = 0 // ms


  var count_fps_ = function()
  {
    var now = PK.Time.get_current_timestamp()

    max_frame_interval_ = Math.max(max_frame_interval_, now - last_frame_time_)
    last_frame_time_ = now

    if (now >= last_period_end_time_ + PERIOD_)
    {
      fps_ = frames_in_current_period_ / ((now - last_period_end_time_) / 1000)
      last_period_end_time_ = now

      if (must_draw_fps_)
        draw_fps_()

      frames_in_current_period_ = 1;
      max_frame_interval_ = 0;
    }
    else
    {
      frames_in_current_period_++
    }

    return fps_
  }


  var draw_fps_ = function()
  {
    var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
    game_field_2d_cntx.clearRect(
        FPS_RECT_.left, FPS_RECT_.top,
        FPS_RECT_.right - FPS_RECT_.left, FPS_RECT_.bottom - FPS_RECT_.top
      )

    game_field_2d_cntx.fillStyle = "white"
    game_field_2d_cntx.font = "12pt bold Arial"

    game_field_2d_cntx.textAlign = "left"
    game_field_2d_cntx.fillText("FPS =", 0, 20)
    game_field_2d_cntx.textAlign = "right"
    game_field_2d_cntx.fillText((fps_).toFixed(1), 85, 20)

    game_field_2d_cntx.textAlign = "left"
    game_field_2d_cntx.fillText("dt =", 0, 40)
    game_field_2d_cntx.textAlign = "right"
    game_field_2d_cntx.fillText((max_frame_interval_ / 1000).toFixed(3), 85, 40)
  }


  this.get_fps = function()
  {
    return fps_
  }

  this.get_max_frame_interval = function()
  {
    return max_frame_interval_
  }


  this.set_fps_draw_flag = function(f)
  {
    must_draw_fps_ = f
  }


  this.render = function()
  {
    count_fps_()

    PKEngine.GUI.Viewport.draw()

    if (must_draw_fps_)
      draw_fps_()
  }
}
