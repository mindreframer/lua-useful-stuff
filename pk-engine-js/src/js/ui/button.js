//------------------------------------------------------------------------------
// button.js: Button
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.Button = PKEngine.Control.extend(
{
  pressed_: false,

  //----------------------------------------------------------------------------

  states: {},
  state: 'off',

  width: undefined,
  height: undefined,

  init: function(x, y, width, height, states, initial_state)
  {
    this.x = x;
    this.y = y;
    this.states = states;
    this.state = initial_state;
    var image = this.states[this.state];
    if (image)
    {
      this.width = image.width;
      this.height = image.height;
    }
    this.set_size(width, height);
  },

  set_size: function(width, height)
  {
    if (width) { this.width = width; }
    if (height) { this.height = height; }
  },

  get_width: function()
  {
    return this.width;
  },

  get_height: function()
  {
    return this.height;
  },

  set_states: function(states)
  {
    this.states = states;
  },

  set_state: function(state)
  {
    if (this.state === state)
    {
      return;
    }

    this.state = state;

    PKEngine.GUI.Viewport.request_redraw();
  },

  get_state: function()
  {
    return this.state;
  },

  on_mouse_down: function(x, y)
  {
    if (!this.is_on_control_(x, y))
    {
      if (this.pressed_)
      {
        this.pressed_ = true;
        PKEngine.GUI.Viewport.request_redraw();
      }
      return false;
    }

    this.pressed_ = true;
    PKEngine.GUI.Viewport.request_redraw();

    PKEngine.SoundSystem.stop_and_play('Button');

    return true;
  },

  on_click: function(x, y)
  {
    var is_on_me = this.is_on_control_(x, y);

    // Don't react if was not pressed before
    if (!this.pressed_)
    {
      return false;
    }

    this.pressed_ = false;
    PKEngine.GUI.Viewport.request_redraw();

    return is_on_me;
  },

  draw: function()
  {
    PKEngine.GUI.Viewport.notify_control_draw_start();

    if (!this.visible)
    {
      return;
    }

    var image = this.states[this.state];

    if (this.pressed_ && this.states['pressed'])
    {
      image = this.states['pressed'];
    }

    if (!image.complete)
    {
      // Cannot draw image until it was loaded
      return;
    }

    DrawImage(image, this.x, this.y, this.width, this.height, this.anchor_x,  this.anchor_y);
  },

  is_on_control_: function(x, y)
  {
    // FIXME: Move method to Control
    if (!this.enabled || !this.visible)
    {
      return false;
    }

    if (!this.width || !this.height)
    {
      var image = this.states[this.state];
      if (!this.width) { this.width = image.width; }
      if (!this.height) { this.height = image.height; }
    }

    var tl_corner = PKEngine.Anchoring.calc_tl_corner(
      this.x, this.y,
      this.anchor_x, this.anchor_y,
      this.width, this.height
    );

    return (
      x >= tl_corner.x && x <= tl_corner.x + this.width &&
      y >= tl_corner.y && y <= tl_corner.y + this.height
    )
  }
})
