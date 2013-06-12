//------------------------------------------------------------------------------
// image.js: Image
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.Image = PKEngine.Control.extend(
{
  image: undefined,

  width: undefined,
  height: undefined,

  init: function(x, y, width, height, image)
  {
    this.x = x;
    this.y = y;
    // NOTE: image resource can be loaded later
    this.image = image;
    if (image)
    {
      this.width = image.width;
      this.height = image.height;
    }
    this.set_size(width, height);
  },

  set_image: function(image, width, height)
  {
    assert(!image || typeof image == 'object', I18N("[PKEngine.Image.set_image]: Invalid type of given image!"))
    this.image = image;
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

  draw: function()
  {
    PKEngine.GUI.Viewport.notify_control_draw_start()

    if (!this.visible || !this.image)
    {
      return;
    }

    // Uncomment to test bug with zero width / height
//     if( !this.width && this.width !== undefined ||
//         !this.height && this.height !== undefined)
//     {
//       console.log("Tried to draw image with zero width or height!", this);
//       CRITICAL_ERROR("Tried to draw image with zero width or height!");
//     }

    DrawImage(this.image, this.x, this.y, this.width, this.height, this.anchor_x, this.anchor_y);
  }
})


//------------------------------------------------------------------------------

var DrawImage = function(image, x, y, width, height, anchor_x, anchor_y, transparency, clip_area, rotation_in_rad)
{
  if (!image)
  {
    CRITICAL_ERROR(I18N('Tried to draw non-existing image!'))
    return
  }

  if (!width)
  {
    //TODO: Uncommented when bug with zero width / height would be fixed
    //assert(width === undefined || width === false, "Invalid width:" + String(width));
    width = image.width;
  }

  if (!height)
  {
    //TODO: Uncommented when bug with zero width / height would be fixed
    //assert(height === undefined || height === false, "Invalid height:" + String(height));
    height = image.height;
  }

  if (transparency === undefined) { transparency = 1; }


  var tl_corner = PKEngine.Anchoring.calc_tl_corner(x, y, anchor_x, anchor_y, width, height)


  var preserved_properties = changeContextProperties({ globalAlpha: transparency })

  if (clip_area)
  {
    PKEngine.GUI.ClipArea.set(clip_area)
  }

  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();

  if (rotation_in_rad)
  {
    game_field_2d_cntx.save()
    game_field_2d_cntx.translate(tl_corner.x + width/2, tl_corner.y + height/2);
    game_field_2d_cntx.rotate(rotation_in_rad);

    tl_corner = { x: (-width/2), y: (-height/2)}
  }

  game_field_2d_cntx.drawImage(image, tl_corner.x, tl_corner.y, width, height);

  if (rotation_in_rad)
  {
    game_field_2d_cntx.restore()
  }

  if (clip_area)
  {
    PKEngine.GUI.ClipArea.restore()
  }

  changeContextProperties(preserved_properties)
}
