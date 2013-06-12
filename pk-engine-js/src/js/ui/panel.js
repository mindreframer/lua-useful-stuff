//------------------------------------------------------------------------------
// panel.js: Panel class
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

PKEngine.GUI.makeBasePanel = function(panel_class_name, whole_config)
{
  assert(panel_class_name, I18N('No panel class name'))
  assert(whole_config, I18N('No config for panel class ${1}', panel_class_name))
  assert(whole_config.class_config, I18N('No class config for panel class ${1}', panel_class_name))

  var DEFAULT_BUTTON_VISIBILITY = true
  var DEFAULT_BUTTON_STATE = 'on'


  return new function()
  {
    var name_ = whole_config.name ? whole_config.name : panel_class_name
    assert(name_, I18N('Anonymous panel'))

    var panel_class_name_ = panel_class_name

    var common_background_ = PKEngine.GUIControls.get_common_background()

    var config_ = whole_config.class_config

    var x_ = (whole_config.instance_config && whole_config.instance_config.x !== undefined) ?
      whole_config.instance_config.x : (config_ && config_.x ? config_.x : 0)
    if (whole_config.parent_x)
      x_ += whole_config.parent_x

    var y_ = (whole_config.instance_config && whole_config.instance_config.x !== undefined) ?
      whole_config.instance_config.y : (config_ && config_.y ? config_.y : 0)
    if (whole_config.parent_y)
      y_ += whole_config.parent_y

    var visible_ = config_ && config_.visible ? config_.visible : true
    if (whole_config.instance_config && whole_config.instance_config.visible !== undefined)
    {
      visible_ = whole_config.instance_config.visible
    }

    var align_ = whole_config.instance_config && whole_config.instance_config.align ?
      whole_config.instance_config.align : 'left'


    var background_config_ = { draw_common_background: true }
    if (config_)
    {
      if(config_.background && config_.background !== true )
        background_config_ = config_.background
      else if (config_.background === false )
        background_config_ = { draw_common_background: false }
    }

    if (background_config_.image)
    {
      if (background_config_.x === undefined)
        background_config_.x = 0
      if (background_config_.y === undefined)
        background_config_.y = 0
    }

    var image_resource_config_ = config_ ? config_.image_resources : false
    var image_config_ = config_ ? config_.images : false
    var label_config_ = config_ ? config_.labels : false
    var button_config_ = config_ ? config_.buttons : false

    var panels_ = {}

    var label_font_ = config_ && config_.fonts && config_.fonts['default'] ? config_.fonts['default'] : undefined
    if (!label_font_)
      label_font_ = PKEngine.GUIControls.get_common_font()

    var image_resources_ = {}
    var images_ = {}, labels_ = {}, buttons_ = {}

    var global_class_name_ = function(local_name)
    {
      return panel_class_name_ + "." + local_name
    }

    var instance_child_name_ = function(local_name)
    {
      return name_ + "." + local_name
    }

    var client2parentX = function(x)
    {
      if (typeof x != "number")
        return x
      return x_ + x
    }
    var client2parentY = function(y)
    {
      if (typeof y != "number")
        return y
      return y_ + y
    }


    // Note: Called once at the end of this constructor
    var init_ = function()
    {
      for (var name in config_.panels)
      {
        var instance_config = config_.panels[name]

        var child_class_config = assert(
            PKEngine.GUIControls.get_control_config(instance_config['class']),
            I18N('Undefined panel class: ${1}', instance_config['class'])
          )

        var maker = assert(
            PKEngine.GUIControlFactory[instance_config['class']],
            I18N('Cannot create panel: ${1}', instance_config['class'])
          )

        panels_[name] = maker()

        panels_[name].init({
            name: name,
            class_config: child_class_config,
            instance_config: instance_config,
            parent_x: x_,
            parent_y: y_
          })
      }

      if (image_resource_config_)
      {
        for(var name in image_resource_config_)
        {
          if (typeof image_resource_config_[name] == 'object')
          {
            var image_set = image_resource_config_[name]
            image_resources_[name] = {}
            for(var key in image_set)
            {
              assert(typeof key == 'string', I18N('Bad image set key: ${1}', global_class_name_(name)))
              assert(
                typeof image_set[key] == 'string',
                I18N('Bad image set src: ${1}', global_class_name_(name))
              )
              image_resources_[name][key] = PKEngine.GraphicsStore.add(
                  global_class_name_(name) + "." + key, image_set[key] + PKEngine.Const.ANTI_CACHE,
                  PKEngine.Loader.check_loaded_data, PK.image_loading_error
                )
            }
          }
          else
          {
            assert(typeof name == 'string', I18N('Bad image set key: ${1}', panel_class_name_))
            assert(
              typeof image_resource_config_[name] == 'string',
              I18N('Bad image set src: ${1}', global_class_name_(name))
            )
            image_resources_[name] = PKEngine.GraphicsStore.add(
                global_class_name_(name), image_resource_config_[name] + PKEngine.Const.ANTI_CACHE,
                PKEngine.Loader.check_loaded_data, PK.image_loading_error
              )
          }
        }
      }

      if (image_config_)
      {
        for(var name in image_config_)
        {
          var image = image_config_[name],
              x = client2parentX ? client2parentX(image.x) : image.x,
              y = client2parentY ? client2parentY(image.y) : image.y,
              width = image.width ? image.width : undefined,
              height = image.height ? image.height : undefined;

          var resource = undefined;
          if (image.resource)
          {
            resource = PK.clone(image.resource);
            if (typeof resource == "string")
            {
              resource = global_class_name_(image.resource);
            }
            else
            {
              resource.group = global_class_name_(resource.group);
            }
          }
          else if (image.common_resource)
          {
            resource = image.common_resource
          }

          if (resource)
          {
            if (typeof resource == "string")
            {
              resource = PKEngine.GraphicsStore.get(resource)
            }
            else
            {
              resource = PKEngine.GraphicsStore.get(resource.group, resource.key)
            }
          }

          images_[name] = new PKEngine.Image(x, y, width, height, resource);
          if (image.visible !== undefined)
          {
            images_[name].set_visible(image.visible);
          }

          images_[name].set_anchor(image.anchor_x, image.anchor_y);
        }
      }

      if (label_config_)
      {
        for(var name in label_config_)
        {
          var label = label_config_[name],
              x = client2parentX ? client2parentX(label.x) : label.x,
              y = client2parentY ? client2parentY(label.y) : label.y,
              params = PK.clone(label.params),
              text;

          if (typeof label.text == 'string')
          {
            text = I18N(label.text)
          }
          else
          {
            text = String(label.text)
          }

          if (!params.size && label_font_)
          {
            params.size = label_font_.size
          }

          labels_[name] = new PKEngine.Label(x, y, label.width, label.height,
              label.clickable, text, params
          );
          if (label.visible !== undefined)
          {
            labels_[name].set_visible(label.visible);
          }

          labels_[name].set_anchor(label.anchor_x, label.anchor_y);
        }
      }

      if (button_config_)
      {
        for(var name in button_config_)
        {
          var state = DEFAULT_BUTTON_STATE;
          var button_config = button_config_[name];
          var states = {};

          if (button_config.disabled)
          {
            state = 'off'
          }

          if (button_config.state)
          {
            state = button_config.state
          }

          if (button_config['img_on'])
          {
            states['on'] = PKEngine.GraphicsStore.add(
              name, button_config['img_on'] + PKEngine.Const.ANTI_CACHE,
              PKEngine.Loader.check_loaded_data, PK.image_loading_error
            )
          }

          if (button_config['img_off'])
          {
            states['off'] = PKEngine.GraphicsStore.add(
              name, button_config['img_off'] + PKEngine.Const.ANTI_CACHE,
              PKEngine.Loader.check_loaded_data, PK.image_loading_error
            );
          }

          if (button_config['img_prsd'])
          {
            states['pressed'] = PKEngine.GraphicsStore.add(
              name, button_config['img_prsd'] + PKEngine.Const.ANTI_CACHE,
              PKEngine.Loader.check_loaded_data, PK.image_loading_error
            );
          }

          var x = client2parentX ? client2parentX(button_config.x) : button_config.x,
              y = client2parentY ? client2parentY(button_config.y) : button_config.y,
              width = button_config.width ? button_config.width : undefined,
              height = button_config.height ? button_config.height : undefined;
          buttons_[name] = new PKEngine.Button(x, y, width, height, states, state);

          buttons_[name].set_visible(
              button_config.visible !== undefined ? button_config.visible : DEFAULT_BUTTON_VISIBILITY
            );
          if (button_config.disabled)
          {
            buttons_[name].disable();
          }

          buttons_[name].set_state(state);
          buttons_[name].set_anchor(button_config.anchor_x, button_config.anchor_y);
        }
      }
    }

    //--------------------------------------------------------------------------

    this.get_config = function()
    {
      return config_
    }

    this.get_label_font = function(label_name)
    {
      if(!label_name)
        return label_font_
      return assert(assert(labels_[label_name], I18N("No label: ${1}", String(label_name))).params)
    }

    this.get_image_resource = function(name, key)
    {
      if (key !== undefined)
      {
        assert(image_resources_[name], I18N("No image group: ${1}", String(name)))
        return image_resources_[name][key]
      }
      return image_resources_[name]
    }


    //--------------------------------------------------------------------------

    this.get_image = function(name) { return images_[name] }
    this.get_label = function(name) { return labels_[name] }
    this.get_button = function(name) { return buttons_[name] }
    this.get_panel = function(name) { return panels_[name] }


    this.set_control_origin = function(name, x, y, container, type_name, method_name)
    {
      var control = container[name]
      if (!control) { CRITICAL_ERROR(I18N('${1} not found: ${2}', type_name, instance_child_name_(name))); return }
      if (!method_name)
      {
        if (x !== undefined)  control.x = x
        if (y !== undefined)  control.y = y
      }
      else
        control[method_name](x,y)
    }

    this.set_image_origin  = function(name, x,y) { return this.set_control_origin(name, x, y,  images_,  'Image') }
    this.set_label_origin  = function(name, x,y) { return this.set_control_origin(name, x, y,  labels_,  'Label') }
    this.set_button_origin = function(name, x,y) { return this.set_control_origin(name, x, y, buttons_, 'Button') }
    this.set_panel_origin = function(name, x,y) { return this.set_control_origin(name, x, y, panels_, 'Panel', 'set_origin') }

    //--------------------------------------------------------------------------

    this.set_image = function(name, image_resource)
    {
      var image = images_[name]
      if (!image)
      {
        CRITICAL_ERROR(I18N('Image not found: ${1}', instance_child_name_(name)))
        return
      }

      image.set_image(image_resource);
    }

    this.set_label_text = function(name, value, params)
    {
      var label = labels_[name]
      if (!label)
      {
        CRITICAL_ERROR(I18N('Label not found: ${1}', instance_child_name_(name)))
        return
      }

      label.set_text((value !== undefined) ? value.toString() : "");

      if (params)
      {
        label.set_params(params);
      }
    }

    this.set_button_state = function(name, state)
    {
      var button = buttons_[name]
      if (!button)
      {
        CRITICAL_ERROR(I18N('Button not found: ${1}', instance_child_name_(name)))
        return
      }

      button.set_state(state)
    }


    //--------------------------------------------------------------------------

    this.on_mouse_down = function(x, y)
    {
      var button_pressed = false

      for(var name in buttons_)
      {
        if (buttons_[name].on_mouse_down(x, y))
          button_pressed = true
      }

      for(var i in panels_)
        button_pressed |= panels_[i].on_mouse_down(x, y)

      return button_pressed
    }

    //--------------------------------------------------------------------------

    this.on_click = function(x, y)
    {
      var button_pressed_name = false
      var label_pressed_name = false

      for(var name in buttons_)
      {
        if (buttons_[name].on_click(x, y))
        {
          button_pressed_name = instance_child_name_(name)
        }
      }

      if (button_pressed_name)
      {
        return button_pressed_name
      }

      for(var name in labels_)
      {
        if (labels_[name].on_click(x, y))
        {
          label_pressed_name = instance_child_name_(name)
        }
      }

      if (label_pressed_name)
      {
        return label_pressed_name
      }

      for(var i in panels_)
      {
        var result = panels_[i].on_click(x, y)
        if (result)
        {
          return result
        }
      }

      return false
    }

    //--------------------------------------------------------------------------

    this.on_mouse_move = function(x, y)
    {
      // Note: nothing to do
      return false;
    }

    //--------------------------------------------------------------------------

    this.is_visible = function() { return visible_ }

    //--------------------------------------------------------------------------

    this.get_align = function() { return align_ }

    //--------------------------------------------------------------------------

    this.get_origin = function() { return { x: x_, y: y_ } }
    this.set_origin = function(x, y) { this.move(x ? (x - x_) : 0, y ? (y - y_) : 0) }

    this.move = function(offset_x, offset_y)
    {
      x_ += offset_x; y_ += offset_y

      for(var i in panels_)
        panels_[i].move(offset_x, offset_y)
    }

    this.show = function()
    {
      //console.log("[Panel.show]", name_, panel_class_name_, visible_)

      visible_ = true

      PKEngine.GUI.Viewport.request_redraw()
    }

    this.hide = function()
    {
      //console.log("[Panel.hide]", name_, panel_class_name_, visible_)

      visible_ = false

      PKEngine.GUI.Viewport.request_redraw()
    }

    //--------------------------------------------------------------------------

    this.draw = function()
    {
      PKEngine.GUI.Viewport.notify_control_draw_start()

      if (!visible_)
        return;

      PKEngine.reset_shadow();

      if (background_config_.draw_common_background && common_background_)
      {
        var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
        game_field_2d_cntx.drawImage(
            PKEngine.GraphicsStore.get(common_background_),
            0, 0,
            PKEngine.GUIControls.get_size().width, PKEngine.GUIControls.get_size().height
          );
      }

      if (background_config_.image)
      {
        DrawImage(
            PKEngine.GraphicsStore.get(background_config_.image),
            client2parentX(background_config_.x), client2parentY(background_config_.y)
          );
      }

      for(var i in images_)
      {
        images_[i].draw();
      }

      for(var i in buttons_)
      {
        buttons_[i].draw();
      }

      for(var i in labels_)
      {
        labels_[i].draw();
      }

      for(var i in panels_)
      {
        panels_[i].draw()
      }
    }

    init_()
  }
}
