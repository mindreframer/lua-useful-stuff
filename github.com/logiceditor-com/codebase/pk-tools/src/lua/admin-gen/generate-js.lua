--------------------------------------------------------------------------------
-- generate-js.lua: client js code generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("generate-js", "GJS")

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local make_concatter,
      fill_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter',
        'fill_placeholders'
      }

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local write_navigator,
      write_table_view,
      write_table_element_editor,
      write_serialized_list_view,
      write_serialized_list_element_editor
      = import 'admin-gen/js-writers.lua'
      {
        'write_navigator',
        'write_table_view',
        'write_table_element_editor',
        'write_serialized_list_view',
        'write_serialized_list_element_editor'
      }

local Q, CR, NPAD, table_contains_game_data
      = import 'admin-gen/misc.lua'
      {
        'Q', 'CR', 'NPAD', 'table_contains_game_data'
      }

local make_db_field_visitor,
      wrap_field_down,
      wrap_table_down,
      wrap_table_up,
      wrap_serialized_list_down,
      wrap_serialized_list_up
      = import 'admin-gen/db_field_visitor.lua'
      {
        'make_db_field_visitor',
        'wrap_field_down',
        'wrap_table_down',
        'wrap_table_up',
        'wrap_serialized_list_down',
        'wrap_serialized_list_up'
      }

--------------------------------------------------------------------------------

--TODO: Duplicate data - same data in table_element_type.js!
local TABLE_ELEMENT_TYPES =
{
  STRING          =  1;
  INT             =  2;
  ENUM            =  3;
  BOOL            =  4;
  DATE            =  5;
  PHONE           =  6;
  MAIL            =  7;
  DB_IDS          =  8;
  BINARY_DATA     =  9;
  MONEY           = 10;
  SERIALIZED_LIST = 11;
}

--------------------------------------------------------------------------------

local generate_navigator
do
  local down = { }

  down.table = function(walkers, data)
    if not table_contains_game_data(data.name) then
      return
    end

    if walkers.first_ then
      walkers.first_ = false
      walkers.cat_ [[{
]]
    else
      walkers.cat_ [[,
          {
]]
    end

    walkers.cat_ [[
            text: I18N(']] (data.name)  [['),
            handler: function() { PK.navigation.go_to_topic("tv_]] (data.name)  [["); }
          }]]
  end

  generate_navigator = function(tables, template_dir, filename_out)
    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = {};
      --
      cat_ = cat;
      first_ = true;
    }

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    local game_model_data = concat()

    write_navigator(
        game_model_data,
        template_dir .. "/navigator.js.template",
        filename_out
      )
  end
end

--------------------------------------------------------------------------------

local collect_table_info
do
  local down, up = { }, { }

  local try_add_key = function(walkers, data)
    local t = walkers.table_infos_[walkers.current_table_name_]

    if #data == 0 then
      t[data.name] = true
    elseif #data == 1 then
      t[data[1]] = true
    end
  end

  local try_add_subordinate_table = function(walkers, data)
    local main_table = assert(data.table)
    local subordinate_table = walkers.current_table_name_

    walkers.table_infos_[main_table].subordinate_tables[
        #walkers.table_infos_[main_table].subordinate_tables + 1
      ] = subordinate_table
  end

  down.table = function(walkers, data)
    walkers.current_table_name_ = data.name

    walkers.table_infos_[walkers.current_table_name_] = {
      subordinate_tables = {}
    }
  end

  up.table = function(walkers, data)
    walkers.current_table_name_ = nil
  end

  down.key = function(walkers, data)
    try_add_key(walkers, data)
  end

  down.primary_key = function(walkers, data)
    try_add_key(walkers, data)
  end

  down.primary_ref = function(walkers, data)
    try_add_key(walkers, data)
    try_add_subordinate_table(walkers, data)
  end

  down.ref = function(walkers, data)
    try_add_subordinate_table(walkers, data)
  end

  down.password = function(walkers, data)
    walkers.table_infos_[walkers.current_table_name_].password_field = data.name
  end

  down.unique_key = function(walkers, data)
    try_add_key(walkers, data)
  end

  collect_table_info = function(tables, filename_out)
    local walkers =
    {
      down = down;
      up = up;
      --
      table_infos_ = {};
    }

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    return walkers.table_infos_
  end
end

--------------------------------------------------------------------------------

local generate_table_views
do

  local cat_renderer = function(cat, column, type, custom_params)
    local padding = column and "            " or "              "

    cat (CR) (padding)
      [[renderer: PK.common_custom_renderers.make_renderer(]] (type) [[,]]

    local first = true
    for k, v in pairs(custom_params) do
      if first then
        cat [[{]] (CR) (padding) [[    ]]
      else
        cat [[,]] (CR) (padding) [[    ]]
      end
      cat (k) " : " (v)
      first = false
    end

    if first then
      cat [[{})]]
    else
      cat (CR) (padding) [[  })]]
    end
  end


  local cat_filter = function(cat, index, name, type, custom_params)
    local padding = "            "

    cat (CR) (padding)
      [[filter: PKAdmin.filters.make_filter(]] (type) [[, ']] (index) [[', I18N(']] (name) [['), ]]

    local first = true
    for k, v in pairs(custom_params) do
      if first then
        cat [[{]] (CR) (padding) [[  ]]
      else
        cat [[,]] (CR) (padding) [[  ]]
      end
      cat (k) " : " (v)
      first = false
    end

    if first then
      cat [[{})]]
    else
      cat (CR) (padding) [[})]]
    end
  end


  local cat_editor = function(cat, type, custom_params)
    local padding = "              "

    cat (CR) (padding)
      [[editor_maker: PK.common_custom_editors.make_editor_maker(]] (type) [[,]]

    local first = true
    for k, v in pairs(custom_params) do
      if first then
        cat [[{]] (CR) (padding) [[  ]]
      else
        cat [[,]] (CR) (padding) [[  ]]
      end
      cat (k) " : " (v)
      first = false
    end

    if first then
      cat [[{})]]
    else
      cat (CR) (padding) [[})]]
    end
  end


  local column_item_concatter = function(
      walkers, cat, field_index, type, name,
      column_data, property_data
    )

    if not type then
      return false
    end

    if column_data and column_data.hidden then
      return false
    end

    local custom_renderer_params, custom_filter_params = {}, {}

    local sortable = "false"
    if walkers.table_infos_[walkers.current_table_name][name] then
      sortable = "true"
    end

    local index, post
    if column_data then
      index = column_data.index
      post = column_data.post
      custom_renderer_params.suffix = column_data.suffix
      custom_renderer_params.precision = column_data.precision

      custom_filter_params.precision = column_data.precision
    end

    if index == nil then index = name end

    if field_index == 1 then
      cat [[{]] (CR)
    else
      cat [[,
          {]] (CR)
    end

    if type == TABLE_ELEMENT_TYPES.ENUM then
      custom_renderer_params.enum_items = "PK.project_enums." .. column_data.enum_name
      custom_filter_params.enum_items = "PK.project_enums." .. column_data.enum_name
    end

    if type == TABLE_ELEMENT_TYPES.DATE then
      custom_renderer_params.print_time = "true"
      custom_filter_params.print_time = "true"
    end

    if type == TABLE_ELEMENT_TYPES.SERIALIZED_LIST then
      custom_renderer_params.serialized_list_view_topic =
        Q("tv_sl_" .. walkers.current_table_name .. "-" .. name)
      custom_renderer_params.serialized_list_name =
        Q(name)
    end

    cat [[
            header: I18N(']]  (name)      [['),
            dataIndex: "]]    (index)     [[",
            sortable: ]]      (sortable)  [[,
            value_type: ]]    (type)      [[,
            convert: PK.common_custom_convertors.make_convertor(]] (type) [[),]]

    cat_renderer(cat, true, type, custom_renderer_params)

    if sortable == "true" then
      cat ","
      cat_filter(cat, index, name, type, custom_filter_params)
    end


    if post then
      cat [[,]] (CR) [[
            ]] (post) (CR) [[
          }]]
    else
      cat (CR) [[
          }]]
    end

    return true
  end

  local property_item_concatter = function(
      walkers, cat, field_index, type, name,
      column_data, property_data
    )

    if not type then
      return false
    end

    if property_data and property_data.hidden then
      return false
    end

    local custom_renderer_params, custom_editor_params = {}, {}

    local post
    if property_data then
      post = property_data.post
      custom_renderer_params.suffix = property_data.suffix
      custom_renderer_params.precision = property_data.precision
    end

    local read_only = false
    if walkers.table_admin_metadata and walkers.table_admin_metadata.read_only_fields then
      read_only = walkers.table_admin_metadata.read_only_fields[name]
    end

    -- Don't generate editors for read-only fields and for binary data / serialized_list
    if read_only
      or type == TABLE_ELEMENT_TYPES.BINARY_DATA
      or type == TABLE_ELEMENT_TYPES.SERIALIZED_LIST
    then
      return false
    end

    local index = Q(NPAD(field_index, 3))

    if field_index == 1 then
      cat (index) [[ : {]] (CR)
    else
      cat [[,
            ]] (index) [[ : {]] (CR)
    end

    if type == TABLE_ELEMENT_TYPES.ENUM then
      custom_renderer_params.enum_items = "PK.project_enums." .. column_data.enum_name
      custom_editor_params.enum_items = "PK.project_enums." .. column_data.enum_name
    end

    cat [[
              loc_name: I18N(']]  (name)  [['),
              mapping: ']]        (name)  [[',
              defaultValue: ']]   ''      [[',
              convert: PK.common_custom_convertors.make_convertor(]] (type) [[),]]

    cat_renderer(cat, false, type, custom_renderer_params)

    cat ","

    cat_editor(cat, type, custom_editor_params)

    if post then
      cat [[,]] (CR) [[
              ]] (post) (CR) [[
            }]]
    else
      cat (CR) [[
            }]]
    end

    return true
  end


  local generate_custom_table_view_tbar = function(subordinate_tables)
    if not subordinate_tables or #subordinate_tables == 0 then
      return 'false'
    end

    local cat, concat = make_concatter()
    cat  [=[[]=]

    for i = 1, #subordinate_tables do

      local table_name = subordinate_tables[i]

      if i > 1 then cat [[,]] end
      cat  (CR) [[
          {
            text: I18N(']] (table_name) [['),
            tooltip: I18N(']] (table_name) [['),
            iconCls:'icon-grid',
            handler: function(grid_panel)
            {
              if (!grid_panel || !grid_panel.selModel)
                return;

              if (grid_panel.selModel.selections.keys.length == 0)
              {
                PK.navigation.go_to_topic(
                    "tv_]] (table_name) [[",
                    undefined,
                    true
                  );
                return
              }

              var element_id = grid_panel.selModel.selections.keys[0];

              PK.navigation.go_to_topic(
                  "tv_]] (table_name) [[",
                  [ element_id ],
                  true
                );
            }
          }]]
    end

    cat  (CR) [=[
        ]]=]

    return concat()
  end

  local down = { }
  do
    down.table = wrap_table_down(
        table_contains_game_data,
        function(walkers, data)
          walkers.visitors.property.serialized_fields = {}
        end
      )

    -- down.list_node = do_nothing

    down.serialized_list = wrap_serialized_list_down(
        nil,
        wrap_field_down(
          function(walkers, data)
            walkers.visitors.property.serialized_fields[
                #walkers.visitors.property.serialized_fields + 1
              ] = data.name;
            return false, TABLE_ELEMENT_TYPES.SERIALIZED_LIST, data.name
          end,
          true
        )
      )

    do
      local PRIMARY_KEY_COLUMN_PROPERTIES = { post = 'id: "id"' }

      local primary_key = wrap_field_down(function(walkers, data)
        return true, TABLE_ELEMENT_TYPES.DB_IDS, data.name,
          PRIMARY_KEY_COLUMN_PROPERTIES,
          { hidden = true }
      end)

      local primary_ref = wrap_field_down(function(walkers, data)
        return true, TABLE_ELEMENT_TYPES.DB_IDS, data.name,
          PRIMARY_KEY_COLUMN_PROPERTIES
      end)

      local serialized_primary_key = wrap_field_down(function(walkers, data)
        return true, TABLE_ELEMENT_TYPES.DB_IDS, data.name,
          PRIMARY_KEY_COLUMN_PROPERTIES
      end)

      local serialized_primary_ref = wrap_field_down(function(walkers, data)
        return true, TABLE_ELEMENT_TYPES.DB_IDS, data.name,
          PRIMARY_KEY_COLUMN_PROPERTIES
      end)

      local bool = wrap_field_down(function(walkers, data)
        return false, TABLE_ELEMENT_TYPES.BOOL, data.name
      end)

      local int = function(size)
        return wrap_field_down(function(walkers, data)
          size = size or assert_is_number(data[1], "bad size")
          local type = TABLE_ELEMENT_TYPES.INT
          local common_params = nil
          if data.render_js and data.render_js.type then
            type = TABLE_ELEMENT_TYPES[data.render_js.type]
            common_params =
            {
              suffix = data.render_js.suffix and Q(data.render_js.suffix)
            }
          end
          return false, type, data.name, common_params, common_params
        end)
      end

      local int_enum = wrap_field_down(function(walkers, data)
        assert_is_table(data.render_js, "no render_js required by enum")
        local enum_name = assert_is_string(data.render_js.enum_name, "bad enum name")
        return false, TABLE_ELEMENT_TYPES.ENUM, data.name,
          {enum_name = enum_name},
          {enum_name = enum_name}
      end)

      local password = wrap_field_down(function(walkers, data)
        return false, TABLE_ELEMENT_TYPES.STRING, data.name,
          { hidden = true },
          { hidden = true }
      end)

      local varchar = function(size, is_optional)
        return wrap_field_down(function(walkers, data)
          size = size or assert_is_number(data[1], "bad size")
          return false, TABLE_ELEMENT_TYPES.STRING, data.name
        end)
      end

      local text = wrap_field_down(function(walkers, data)
        return false, TABLE_ELEMENT_TYPES.STRING, data.name
      end)

      local blob = wrap_field_down(function(walkers, data)
        return false, TABLE_ELEMENT_TYPES.BINARY_DATA, data.name
      end)

      local ref = function(is_optional)
        return wrap_field_down(function(walkers, data)
          return false, TABLE_ELEMENT_TYPES.DB_IDS, data.name
        end)
      end

      local timestamp = wrap_field_down(function(walkers, data)
        return false, TABLE_ELEMENT_TYPES.DATE, data.name
      end)

      local metadata = wrap_field_down(function(walkers, data)

        if data.admin and data.admin.read_only_fields then
          data.admin.read_only_fields = tset(data.admin.read_only_fields)
        end

        walkers.table_admin_metadata = data.admin

        return false, nil
      end)

      local std_int = int(11)

      down.metadata = metadata

      down.primary_key = primary_key
      down.primary_ref = primary_ref

      down.serialized_primary_key = serialized_primary_key
      down.serialized_primary_ref = serialized_primary_ref

      down.blob = blob
      down.boolean = bool
      down.counter = std_int
      down.flags = std_int
      down.int = std_int
      down.int_enum = int_enum
      down.ip = varchar(15)
      down.md5 = varchar(32)
      down.password = password
      down.optional_ip = varchar(15, true)
      down.optional_ref = ref(true)
      down.ref = ref(false)
      down.string = varchar(nil)
      down.text = text
      down.timeofday = std_int
      down.day_timestamp = std_int
      down.timestamp = timestamp
      down.timestamp_created = timestamp
      down.uuid = varchar(37)
      down.weekdays = std_int

      -- down.database = do_nothing
      -- down.key = do_nothing
      -- down.unique_key = do_nothing
      -- down.metadata = do_nothing
    end
  end

--------------------------------------------------------------------------------

  local up = {}
  do
    up.table =  wrap_table_up(function(walkers, data)
      local metadata = walkers.table_admin_metadata or {}

      local custom_tbar = generate_custom_table_view_tbar(
          walkers.table_infos_[walkers.current_table_name].subordinate_tables
        )

      write_table_view(
          data.name,
          walkers.table_primary_key,
          custom_tbar,
          metadata.read_only,
          metadata.append_only,
          metadata.prohibit_deletion,
          walkers.visitors.column.concat(),
          walkers.template_dir_ .. "table_view.js.template",
          walkers.dir_out_
        )

      local plain_properties = [[
          {
            ]] .. walkers.visitors.property.concat() .. CR .. [[
          }]]

      local serialized_fields = "undefined"

      if #walkers.visitors.property.serialized_fields > 0 then
        local cat, concat = make_concatter()
        cat  [=[[
                '-']=]

        for i = 1, #walkers.visitors.property.serialized_fields do
          local name = walkers.visitors.property.serialized_fields[i]
          cat  [[,]] (CR) [[
                {
                  text: I18N('Edit ]] (name) [['),
                  tooltip: I18N('Click to edit ]] (name) [['),
                  iconCls:'icon-edit-serialized-list',
                  handler: function(element_id)
                  {
                    if (element_id)
                    {
                      PK.navigation.go_to_topic(
                          "tv_sl_]] (data.name) "-" (name) [[",
                          [ element_id ],
                          true
                        );
                    }
                  }
                }]]
        end
        cat  (CR) [=[
              ]]=]

        serialized_fields = concat()
      end

      local custom_tbar = "false"
      if walkers.table_infos_[walkers.current_table_name].password_field then
        local password_field_name = walkers.table_infos_[walkers.current_table_name].password_field
        custom_tbar = [=[[
              {
                text:     I18N('Change ]=] .. password_field_name .. [=['),
                tooltip:  I18N('Click to change ]=] .. password_field_name .. [=['),
                iconCls:  'icon-change-password',
                handler:  function(property_grid)
                {
                  PK.Windows.SetPassword( function(new_pass){
                      if(!property_grid.hidden_fields)
                        property_grid.hidden_fields = {}
                      property_grid.hidden_fields.]=] .. password_field_name .. [=[ = new_pass;
                    })
                }
              }
            ]]=]
      end

      local properties = [[function(is_existing_element, callback)
        {
          var properties =]] .. CR .. plain_properties .. [[;

          callback(
              properties,
              undefined,
              ]] .. serialized_fields .. CR .. [[
            );
        }]]

      write_table_element_editor(
          data.name,
          walkers.table_primary_key,
          custom_tbar,
          properties,
          walkers.template_dir_ .. "table_element_editor.js.template",
          walkers.dir_out_
        )

      walkers.visitors.property.serialized_fields = nil
      walkers.table_admin_metadata = nil
    end)

    up.serialized_list = wrap_serialized_list_up(function(walkers, data)

      if not walkers.serialized_list_primary_key then

        log(
            "WARNING: Skipped serialized list",
            walkers.current_table_name .. "." .. walkers.current_serialized_list_name,
            "since it has no primary key!"
          )

      else

        write_serialized_list_view(
            walkers.current_table_name,
            walkers.current_serialized_list_name,
            walkers.serialized_list_primary_key,
            walkers.visitors.column.sl_concat(),
            walkers.template_dir_ .. "serialized_list_view.js.template",
            walkers.dir_out_
          )

        local properties = CR .. [[
        {
            ]] .. walkers.visitors.property.sl_concat() .. CR .. [[
        }]]

        write_serialized_list_element_editor(
            walkers.current_table_name,
            walkers.current_serialized_list_name,
            walkers.serialized_list_primary_key,
            properties,
            walkers.template_dir_ .. "serialized_list_element_editor.js.template",
            walkers.dir_out_
          )
      end
    end)

  end

--------------------------------------------------------------------------------

  generate_table_views = function(tables, table_infos, template_dir, dir_out)
    local walkers =
    {
      down = down;
      up = up;
      --
      table_infos_ = table_infos;
      template_dir_ = template_dir;
      dir_out_ = dir_out;
    }

    walkers.visitors = {}

    walkers.visitors.column = make_db_field_visitor(
        walkers,
        column_item_concatter,
        column_item_concatter,
        false
      );

    walkers.visitors.property = make_db_field_visitor(
        walkers,
        property_item_concatter,
        property_item_concatter,
        false
      );

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end
  end
end

--------------------------------------------------------------------------------

local generate_js = function(
    tables,
    template_dir,
    dir_out,
    must_generate_navigator
  )

  if must_generate_navigator then
    generate_navigator(tables, template_dir, dir_out .. "modules/navigator.js")
  end

  local table_infos = collect_table_info(tables)

  generate_table_views(tables, table_infos, template_dir, dir_out)
end

--------------------------------------------------------------------------------

return
{
  generate_js = generate_js;
}
