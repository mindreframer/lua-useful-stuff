//------------------------------------------------------------------------------
// main_loop.js: Main loop
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GameEngine');

PKEngine.GameEngine.MainLoop = new function()
{
  var instance_ = this

  var can_process_events_ = true

  var custom_main_loop_actions_ = false


  //----------------------------------------------------------------------------
  // private methods
  //----------------------------------------------------------------------------

  var run_frame_ = function()
  {
    PK.Error.handle_error(function ()
    {
      requestAnimFrame(run_frame_)

      // Handle events (from server)
      if (can_process_events_)
        PKEngine.EventQueue.run()

      if (custom_main_loop_actions_)
        custom_main_loop_actions_()


      // Note: It's useless to move it to separate callback since
      //       JS uses cooperative multitasking still
      if (PKEngine.GUI.Renderer)
      {
        PKEngine.GUI.Renderer.render()
      }
    }, 'PKEngine.GameEngine.MainLoop');
  }


  //----------------------------------------------------------------------------
  // public methods
  //----------------------------------------------------------------------------


  this.allow_event_processing = function()
  {
    can_process_events_ = true
  }


  this.prohibit_event_processing = function()
  {
    can_process_events_ = false
  }


  this.start = function(start_delay, custom_main_loop_actions)
  {
    custom_main_loop_actions_ = custom_main_loop_actions

    // shim layer with setTimeout fallback
    window.requestAnimFrame = (function(){
      return  window.requestAnimationFrame       ||
              window.webkitRequestAnimationFrame ||
              window.mozRequestAnimationFrame    ||
              window.oRequestAnimationFrame      ||
              window.msRequestAnimationFrame     ||
              function(/* function */ callback, /* DOMElement */ element){
                window.setTimeout(callback, 1000 / PKEngine.Const.MAXIMUM_FPS);
              };
    })();

    setTimeout(run_frame_, start_delay);
  }
}
