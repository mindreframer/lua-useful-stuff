//------------------------------------------------------------------------------
// image.js: Utilities working with DOM images
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

/**
 * Log image loading error.
 *
 * @param evt
 */
PK.image_loading_error = function(evt)
{
  console.log(this, evt);
  var src = (this && this.src) ? this.src : "(invalid image)";
  GUI_ERROR(I18N('Failed to load: ${1}', src));
  this.loading_failure = true;
}


/**
 * Check is image loaded.
 *
 * @param img
 */
PK.check_is_image_loaded = function(img)
{
  // During the onload event, IE correctly identifies any images that
  // weren’t downloaded as not complete. Others should too. Gecko-based
  // browsers act like NS4 in that they report this incorrectly.
  if (!img || !img.complete)
  {
    return false;
  }

  // However, they do have two very useful properties: naturalWidth and
  // naturalHeight. These give the true size of the image. If it failed
  // to load, either of these should be zero.
  if (typeof img.naturalWidth != "undefined" && img.naturalWidth == 0)
  {
    return false;
  }

  // No other way of checking: assume it’s ok.
  return true;
}


/**
 * Check is image loaded or failed.
 *
 * @param img
 */
PK.check_is_image_loaded_or_failed = function(img)
{
  if(PK.check_is_image_loaded(img))
  {
    return true;
  }

  return img && img.loading_failure;
}
