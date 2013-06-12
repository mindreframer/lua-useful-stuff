--------------------------------------------------------------------------------
-- dot.lua: convert DB schema to dot file
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("dot", "DOT")

--------------------------------------------------------------------------------

local convert_db_schema_to_dot
do
  local COLOR_TABLE = "lightgrey"
  local COLOR_KEY = "yellow"
  local COLOR_FIELD = "white"
  local COLOR_PRIMARY = "lightblue"
  local COLOR_SERIALIZED_LIST = "grey"
  local COLOR_PRIMARY_SERIALIZED = "cyan"

  local down = { }

  down.table = function(walkers, data)
    local cat = walkers.cat_

    walkers.cur_table_name_ = data.name
    walkers.cur_links_ = { }

    walkers.ports_[data.name] = { n = 0 }
    cat (data.name)
        '[label=<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">\n'
        '<TR><TD PORT="0" COLSPAN="2" BGCOLOR="' (COLOR_TABLE) '">' (data.name)
        '</TD></TR>\n'
  end

  -- NOTE: list_node itself is ignored (but its contents are not)
  down.serialized_list = function(walkers, data)
    local cat = walkers.cat_

    walkers.cur_serialized_list_name_ = data.name
    cat '<TR><TD COLSPAN="2">\n'
        '<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">\n'
        '<TR><TD PORT="0" COLSPAN="2" BGCOLOR="' (COLOR_SERIALIZED_LIST)
        '">' (data.name)
        '</TD></TR>\n'
  end

  down.list_node = do_nothing
  down.metadata = do_nothing

  local add_field = function(walkers, name)
    local ports = walkers.ports_[walkers.cur_table_name_]
    ports.n = ports.n + 1

    -- TODO: Do we need this?
    ports[name] = ports.n

    return ports.n
  end

  local add_ref = function(walkers, from_field, to_table)
    local cur_table_name = walkers.cur_table_name_
    local ports = walkers.ports_[cur_table_name]

    walkers.cur_links_[#walkers.cur_links_ + 1] =
    {
      from = cur_table_name .. ":v" .. ports[from_field];
      to = to_table .. ":" .. '0';
    }
  end

  local cat_field = function(walkers, tag, name, color, port_name)
    color = color or COLOR_FIELD

    local cur_table_name = walkers.cur_table_name_
    local ports = walkers.ports_[cur_table_name]
    local port = ports[port_name or name]

    local cat = walkers.cat_
    cat '<TR>'
        '<TD PORT="k' (port) '" BGCOLOR="' (color) '">' (tag) '</TD>'
        '<TD PORT="v' (port) '" BGCOLOR="' (color) '">' (name) '</TD>'
        '</TR>'
        '\n'
  end

  local field_up = function(tag, color)
    return function(walkers, data)
      add_field(walkers, data.name)
      cat_field(walkers, tag, data.name, color)
    end
  end

  local ref_up = function(tag, color)
    return function(walkers, data)
      add_field(walkers, data.name)
      add_ref(walkers, data.name, data.table)
      cat_field(walkers, tag, data.name, color)
    end
  end

  local serialized_list_ref_up = function(tag, color)
    return function(walkers, data)
      local port_name = walkers.cur_serialized_list_name_ .. "." .. data.name

      add_field(walkers, port_name)
      add_ref(walkers, port_name, data.table)
      cat_field(walkers, tag, data.name, color, port_name)
    end
  end

  local up = setmetatable(
      { },
      {
        __index = function(t, tag)
          local v = field_up(tag)
          t[tag] = v
          return v
        end;
      }
    )

  up.optional_ref = ref_up('optional_ref')
  up.ref = ref_up('ref')

  up.primary_ref = ref_up('primary_ref', COLOR_PRIMARY)
  up.primary_key = field_up('primary_key', COLOR_PRIMARY)

  up.serialized_primary_ref = serialized_list_ref_up(
      'serialized_primary_ref',
      COLOR_PRIMARY
    )
  up.serialized_primary_key = field_up(
      'serialized_primary_key',
      COLOR_PRIMARY_SERIALIZED
    )

  up.string = function(walkers, data)
    add_field(walkers, data.name)
    cat_field(walkers, 'string (' .. (data[1]) .. ')', data.name)
  end

  up.table = function(walkers, data)
    local cat = walkers.cat_
    cat '</TABLE>>,shape="plaintext"];\n'

    for i = 1, #walkers.cur_links_ do
      local link = walkers.cur_links_[i]
      cat (link.from) ' -> ' (link.to) ' [style="solid",arrowhead="normal"];\n'
    end

    cat '\n'
  end

  up.serialized_list = function(walkers, data)
    local cat = walkers.cat_
    cat '</TABLE></TD></TR>\n'

    walkers.cur_serialized_list_name_ = false
  end

  up.list_node = do_nothing
  up.metadata = do_nothing

  up.key = function(walkers, data)
    local color = COLOR_KEY
    local tag = 'key'
    local name = data.name

    local cat = walkers.cat_
    cat '<TR>'
        '<TD PORT="k1" BGCOLOR="' (color) '">' (tag) '</TD>'
        '<TD PORT="v1" BGCOLOR="' (color) '">' (name) '</TD>'
        '</TR>'
        '\n'
  end

  up.unique_key = function(walkers, data)
    local color = COLOR_KEY
    local tag = 'unique_key'
    local name = data.name

    local cat = walkers.cat_
    cat '<TR>'
        '<TD PORT="k1" BGCOLOR="' (color) '">' (tag) '</TD>'
        '<TD PORT="v1" BGCOLOR="' (color) '">' (name) '</TD>'
        '</TR>'
        '\n'
    --[[
    for i = 1, #data do
      cat '<TR>'
          '<TD PORT="v1" BGCOLOR="' (color) '">' (data[i]) '</TD>'
          '</TR>'
          '\n'
    end
    --]]
  end

  -- TODO: Render database as subgraph cluster
  --       (see abie/converters/dot.lua for example)

  convert_db_schema_to_dot = function(tables)
    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
      ports_ = { };
      cur_links_ = { };
      cur_table_name_ = false;
      cur_serialized_list_name = false;
    }

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    return [[
// DB Schema
// Render with $ dot file.dot -Tpdf -o file.pdf

strict digraph G {
compound = true;
outputorder = edgesfirst;
overlap = false;
splines = true;
concentrate = true;

]] .. concat() .. [[
}
]]
  end
end

--------------------------------------------------------------------------------

return
{
  convert_db_schema_to_dot = convert_db_schema_to_dot;
}
