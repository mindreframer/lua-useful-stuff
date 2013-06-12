//------------------------------------------------------------------------------
// animation_set.js: AnimationSet - container for animations
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

PKEngine.GUI.AnimationSet = new function()
{

// Animation makers
var make_disappearing_object_
var make_moving_object_

this.make = function(on_complete) { return new function()
{

  //--------------------------------------------------------------------------
  // Private properties
  //--------------------------------------------------------------------------

  var animator_packs_ = [ [] ] // Note: we always have first empty pack
  var animators_ = false
  var complete_ = false
  var on_complete_ = on_complete


  //--------------------------------------------------------------------------
  // Start next animator pack
  //--------------------------------------------------------------------------

  var get_next_pack_ = function()
  {
    if (animator_packs_.length == 0)
      return false

    var pack = animator_packs_.shift()
    if (!pack || pack.length == 0)
      return false

    var timestamp = PK.Time.get_current_timestamp()
    for (var i = 0; i < pack.length; i++)
      pack[i].start(timestamp)

    return pack
  }

  var try_start_next_pack_ = function() // return 'true' if started
  {
    animators_ = get_next_pack_()

    if (!animators_)
    {
      complete_ = true
      if (on_complete_)
        on_complete_()
      return false
    }

    return true
  }

  //--------------------------------------------------------------------------
  // Add objects
  //--------------------------------------------------------------------------

  var add_objects_ = function(object_maker, list, start_next_pack)
  {
    var pack = []

    for (var i = 0; i < list.length; i++)
      pack.push(object_maker(list[i]))

    if (start_next_pack)
      animator_packs_.push([])

    animator_packs_[animator_packs_.length - 1] =
      animator_packs_[animator_packs_.length - 1].concat(pack)
  }


  //--------------------------------------------------------------------------
  // Add simple waiters
  //--------------------------------------------------------------------------

  this.add_waiter = function(list, start_next_pack)
  {
    add_objects_(make_waiter_, list, start_next_pack)
  }

  //--------------------------------------------------------------------------
  // Add moving objects
  //--------------------------------------------------------------------------

  this.add_moving_objects = function(list, start_next_pack)
  {
    add_objects_(make_moving_object_, list, start_next_pack)
  }

  //--------------------------------------------------------------------------
  // Add disappearing objects
  //--------------------------------------------------------------------------

  this.add_disappearing_objects = function(list, start_next_pack)
  {
    add_objects_(make_disappearing_object_, list, start_next_pack)
  }


  //--------------------------------------------------------------------------
  // Run animations
  //--------------------------------------------------------------------------

  this.run = function() // return 'true' if complete
  {
    if (complete_)
      return true

    // Note: try_start_next_pack_ must be here because it can be first run() call
    if (!animators_ && !try_start_next_pack_())
        return true

    var timestamp = PK.Time.get_current_timestamp()

    var drawn_region = PKEngine.GUI.Region.make()

    var complete = true
    for(var i = 0; i < animators_.length; i++)
      complete &= animators_[i].run(timestamp, drawn_region)

    // Note: try_start_next_pack_ must be here for correct drawing
    if (complete && !try_start_next_pack_())
      return { complete: true, drawn_region: drawn_region }

    return { complete: false, drawn_region: drawn_region }
  }
}}


//--------------------------------------------------------------------------
// Simple waiter
//--------------------------------------------------------------------------

// Note: Untested function, please remove this note after successful usage
var make_waiter_ = function(params) { return new function() {
  // TODO: Use PK.Timer
  var start_time_ = undefined

  var period_     =  params.period

  var start_progress_ = params.current_progress

  var complete_   = false

  this.start = function(timestamp)
  {
    var ratio = 0
    if (start_progress_)
      ratio = start_progress_

    start_time_ = timestamp - ratio * period_
  }

  this.run = function(timestamp)
  {
    if (!complete_)
      complete_ = (timestamp - start_time_) >= period_
    return complete_
  }
}}


//--------------------------------------------------------------------------
// Animation of moving object
//--------------------------------------------------------------------------

var make_moving_object_ = function(params) { return new function() {
  // TODO: Use PK.Timer
  var start_time_ = undefined

  var image_      =  params.image
  var clip_area_  =  params.clip_area
  var start_pos_  =  params.start_pos
  var end_pos_    =  params.end_pos
  var period_     =  params.period

  var start_progress_ = params.current_progress


  var last_pos_   = PK.clone(start_pos_)
  var complete_   = false

  this.start = function(timestamp)
  {
    var ratio = 0
    if (start_progress_)
      ratio = start_progress_

    start_time_ = timestamp - ratio * period_
  }

  this.run = function(timestamp, drawn_region)
  {
    if (!complete_)
      complete_ = (timestamp - start_time_) >= period_

    var ratio = !complete_ ? ((timestamp - start_time_) / period_) : 1

    var current_pos = {
        x : start_pos_.x + (end_pos_.x - start_pos_.x) * ratio,
        y : start_pos_.y + (end_pos_.y - start_pos_.y) * ratio
      }

    DrawImage(image_, current_pos.x, current_pos.y, undefined, undefined, undefined, undefined, undefined, clip_area_)

    drawn_region.add_rect(
        current_pos.x, current_pos.y,
        current_pos.x + image_.width, current_pos.y + image_.height
      )

    last_pos_ = current_pos

    return complete_
  }
}}


//--------------------------------------------------------------------------
// Animation of disappearing object
//--------------------------------------------------------------------------

var make_disappearing_object_ = function(params) { return new function() {
  // TODO: Use PK.Timer
  var start_time_ = undefined

  var image_      =  params.image
  var clip_area_  =  params.clip_area
  var pos_        =  params.pos
  var period_     =  params.period

  var last_transparency_ = 1
  var complete_   = false

  this.start = function(timestamp)
  {
    start_time_ = timestamp
  }

  this.run = function(timestamp, drawn_region)
  {
    if (!complete_)
      complete_ = (timestamp - start_time_) >= period_

    var ratio = !complete_ ? ((timestamp - start_time_) / period_) : 1

    var transparency = Math.min(1, Math.max( 0, 1 - ratio ))

    // TODO: Localize
    assert(
        transparency <= last_transparency_,
        "Current transparency is too big: " + String(transparency) + " > " + String(last_transparency_)
      )

    DrawImage(image_, pos_.x, pos_.y, undefined, undefined, undefined, undefined, transparency, clip_area_)

    drawn_region.add_rect(pos_.x, pos_.y, pos_.x + image_.width, pos_.y + image_.height)

    last_transparency_ = transparency

    return complete_
  }
}}

}
