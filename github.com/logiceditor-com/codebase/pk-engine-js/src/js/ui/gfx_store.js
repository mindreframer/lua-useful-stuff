//------------------------------------------------------------------------------
// gfx_store.js: Graphics store
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.GraphicsStore = new function()
{
  var images_ = {}


  this.add = function(name, src, on_load_or_already_added, on_error, check_already_loaded)
  {
    if (check_already_loaded === undefined) check_already_loaded = false

    if (check_already_loaded && this.image_is_loaded(name))
    {
//       // TODO: Localize
//       assert(
//           src == images_[name],
//           "Image '" + name + "' is already loaded, src: "+ String(images_[name].src) + ", new src: "+ String(src)
//         )
//
//       // TODO: Localize
//       LOG("Warning: Attempt to load already loaded image: " + name + ", " + images_[name].src)
//       if(window.console && console.log)
//       {
//         console.log("Warning: Attempt to load already loaded image: ", name, images_[name].src)
//       }

      if (on_load_or_already_added)
      {
        on_load_or_already_added()
      }

      return images_[name]
    }

    var image = new Image()

    image.onload  = on_load_or_already_added
    image.onerror = on_error
    image.src     = src

    images_[name] = image

    return image
  }


  this.add_images = function(images, on_load_or_already_added, on_error, check_already_loaded)
  {
    for(var name in images)
      this.add(name, images[name], on_load_or_already_added, on_error, check_already_loaded)
  }


  this.get = function(name, key, fail_if_not_found)
  {
    if (fail_if_not_found === undefined) fail_if_not_found = true

    var img
    if (key !== undefined)
      img = images_[name + "." + key]
    else
      img = images_[name]

    if (!img)
    {
      if (fail_if_not_found)
      {
        CRITICAL_ERROR(I18N('No image: ${1}', (name + (key !== undefined ? ("." + key) : "" ))))
      }
      return undefined
    }

    return img
  }


  this.image_is_loaded = function(name, key)
  {
    var img = this.get(name, key, false)

    return img && PK.check_is_image_loaded(images_[name])
  }


  this.count_loaded = function()
  {
    var num = 0

    for(var name in images_)
      if (PK.check_is_image_loaded(images_[name]))
        num++

    return num
  }


  this.count_total = function()
  {
    return PK.count_properties(images_)
  }
}
