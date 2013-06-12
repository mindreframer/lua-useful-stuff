--------------------------------------------------------------------------------
-- generate_docs.lua: api documentation generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local table_insert, table_remove = table.insert, table.remove

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_number
      = import 'lua-nucleo/type.lua'
      {
        'is_number'
      }

local assert_is_string,
      assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string',
        'assert_is_table'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local do_nothing,
      invariant
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing',
        'invariant'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local torderedset,
      torderedset_insert,
      tmap_values
      = import 'lua-nucleo/table-utils.lua'
      {
        'torderedset',
        'torderedset_insert',
        'tmap_values'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local make_ordered_named_cat_manager
      = import 'lua-nucleo/ordered_named_cat_manager.lua'
      {
        'make_ordered_named_cat_manager'
      }

local make_pretty_xml_schema_builder
      = import 'pk-engine/pretty_xml_schema_builder.lua'
      {
        'make_pretty_xml_schema_builder'
      }

local make_pretty_json_schema_builder
      = import 'pk-engine/pretty_json_schema_builder.lua'
      {
        'make_pretty_json_schema_builder'
      }

local fill_apidoc_placeholders
      = import 'apigen/apidoc.lua'
      {
        'fill_apidoc_placeholders'
      }

local create_io_formats
      = import 'apigen/util.lua'
      {
        'create_io_formats'
      }

local prettyprint_lua,
      prettyprint_json
      = import 'apigen/pretty.lua'
      {
        'prettyprint_lua',
        'prettyprint_json'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "generate_docs", "GDO"
  )

--------------------------------------------------------------------------------

-- TODO: Support static URLs as well?

local generate_docs
do
  local down, up = { }, { }
  do
    local node_down = function(fn)
      return function(walkers, data)
        table_insert(walkers.path_, data)

        return fn(walkers, data)
      end
    end

    local node_up = function(fn)
      return function(walkers, data)
        fn(walkers, data)

        assert(table_remove(walkers.path_) == data)
      end
    end

--------------------------------------------------------------------------------

    local nesting_node_down = function(fn)
      return node_down(function(walkers, data)
        walkers.nesting_ = walkers.nesting_ + 1
        return fn(walkers, data)
      end)
    end

    local nesting_node_up = function(fn)
      return node_up(function(walkers, data)
        fn(walkers, data)
        walkers.nesting_ = walkers.nesting_ - 1
      end)
    end

--------------------------------------------------------------------------------

    local pop_cat = function(walkers, data)
      walkers:pop_cat()
    end

--------------------------------------------------------------------------------

    local url_down = function(walkers, data)
      walkers:push_cat("url", data.name:gsub("^/", "")) [[

\subsubsection{]] (data.name) [[} \index{URL!]] (data.name) [[}

${fmt:doc.notes:]] (data.name) [[}

\nopagebreak[1]
\paragraph*{IN}\linebreak
\nopagebreak[4]
${fmt:input:]] (data.name) [[}
${fmt:input.comment:]] (data.name) [[}

\nopagebreak[1]
\paragraph*{OUT}\linebreak
\nopagebreak[4]
${fmt:output:]] (data.name) [[}
${fmt:output.comment:]] (data.name) [[}

\nopagebreak[1]
\paragraph*{Ошибки}\linebreak
\nopagebreak[4]
${fmt:additional_errors:]] (data.name) [[}
${fmt:additional_errors.comment:]] (data.name) [[}
]]
    end

    local url_up = function(walkers, data)
      walkers:pop_cat()
    end

    local simple_urls =
    {
      "api:cacheable_url";
      "api:url";
      "api:url_with_dynamic_output_format";
      "api:static_url";
    }

    for i = 1, #simple_urls do
      down[simple_urls[i]] = node_down(url_down)
      up[simple_urls[i]] = node_up(url_up)
    end

    down["api:raw_url"] = node_down(url_down)
    up["api:raw_url"] = node_up(function(walkers, data)
      walkers:named_cat("fmt", "output:" .. walkers.path_[1].name) [[

\hspace{\fill}
\linebreak
\linebreak
\em{(Raw формат.)}
]]

      return url_up(walkers, data)
    end)

--------------------------------------------------------------------------------

    down["api:dynamic_output_format"] = node_down(do_nothing)

    up["api:dynamic_output_format"] = node_up(function(walkers, data)
      walkers:named_cat("fmt", "output:" .. walkers.path_[1].name) [[

\hspace{\fill}
\linebreak
\linebreak
\em{(Динамический формат.)}
]]
    end)

--------------------------------------------------------------------------------

    local formats
    do
      local create_leaf, create_node, create_list, create_cdata
      local tag_types

      local cat_input = function(walkers, name, type)
        local cat = walkers:context_cat()
        local prefix = walkers.input_name_prefix_

        -- TODO: Ensure that nested lists are rendered correctly!

        local full_name
        if #prefix == 0 then
          full_name = name
        else
          full_name = prefix[1]

          for i = 2, #prefix do
            full_name = full_name .. "[" .. prefix[i] .. "]"
          end

          full_name = full_name .. "[" .. name .. "]"
        end

        cat [[\hspace{\fill} \\]]
        if walkers.need_amp_ then
          cat [[\&]]
        else
          walkers.need_amp_ = true
        end

        cat [[\bf{]] (full_name) [[}=\textit{]] (type) [[}
]]
      end

      -- TODO: Generalize
      local indent
      do
        local indent_cache = setmetatable(
            { },
            {
              __index = function(t, k)
                local v = ("  "):rep(k)
                t[k] = v
                return v
              end;
            }
          )

        indent = function(n)
          return indent_cache[n]
        end
      end

      local N = indent

      local Q = function(s)
        return ("%q"):format(s)
      end

      local common_input =
      {
        down = function(walkers, node)
          cat_input(walkers, node.name, node.tag)
        end;

        up = do_nothing;
      }

      local cat_method = function(walkers, data, method_name, is_root)
        local cat = walkers.build_renderer_cat_
        local nesting = walkers.nesting_

        local field, node = data.name, data.node_name

        if is_root then
          field = nil -- TODO: ?!
        end

        if node == field then
          node = nil
        end

        cat [[
  ]] (N(nesting)) [[builder:]] (method_name)

        if node then
          cat [[ (]] ((field == nil) and [[nil]] or (Q(field)))
          [[, ]] (Q(node)) [[)]]
        else
          cat [[ ]] (Q(field))
        end

        return cat
      end

      local set_sample_value = function(walkers, value)
        local data = walkers.sample_data_
        if not data then
          data = { }
          walkers.sample_data_ = data
        end

        local path = walkers.path_
        for i = 1, #path - 1 do
          local node = path[i]
          if node.namespace == "output" then
            local key = node.name or 1
            data = assert_is_table(data[key])

            -- Hack
            if
              tag_types[create_list][node.tag] and
              tag_types[create_node][path[i + 1].tag]
            then
              data = assert_is_table(data[1])
            end
          end
        end

        local key = path[#path].name or 1
        assert(data[key] == nil)
        data[key] = value
      end

      create_leaf = invariant
      {
        input = common_input;
        output =
        {
          down = function(walkers, node)
            -- TODO: Honor optional nodes?
            cat_method(walkers, node, "attribute", false) [[;
]]

            set_sample_value(walkers, node.tag)
          end;

          up = do_nothing;
        };
      }

      create_cdata = invariant
      {
        input = common_input;
        output =
        {
          down = function(walkers, node)
            -- TODO: Honor optional nodes?
            cat_method(walkers, node, "named_cdata", false) [[;
]]

            set_sample_value(walkers, node.tag)
          end;

          up = do_nothing;
        };
      }

      create_list = function(param)
        local is_root = param.is_root
        return
        {
          input =
          {
            down = function(walkers, node)
              cat_input(walkers, node.name .. "[size]", "INTEGER")
              table_insert(
                  walkers.input_name_prefix_,
                  node.name .. "[}<N>\\bf{]"
                )
            end;

            up = function(walkers, node)
              walkers:context_cat() [[\hspace{\fill} \\...]]
              table_remove(walkers.input_name_prefix_)
            end;
          };

          output =
          {
            down = function(walkers, node)
              -- TODO: Honor optional nodes?
              cat_method(walkers, node, "ilist", is_root) [[

  ]] (N(walkers.nesting_)) [[{
]]

              -- TODO: Render "..." after the sample element somehow
              set_sample_value(walkers, { [1] = { } })
            end;

            up = function(walkers, node)
              local cat = walkers.build_renderer_cat_

              cat [[
  ]] (N(walkers.nesting_)) [[};
]]
            end;
          };
        }
      end

      create_node = function(param)
        local is_root = param.is_root
        return
        {
          input = common_input;
          output =
          {
            down = function(walkers, node)
              -- TODO: Honor optional nodes?
              cat_method(walkers, node, "node", is_root) [[

  ]] (N(walkers.nesting_)) [[{
]]

              set_sample_value(walkers, { })
            end;

            up = function(walkers, node)
              local cat = walkers.build_renderer_cat_

              cat [[
  ]] (N(walkers.nesting_)) [[};
]]
            end;
          };
        }
      end

      tag_types =
      {
        [create_leaf] = { };
        [create_node] = { };
        [create_list] = { };
        [create_cdata] = { };
      }

      -- Hack to get is_root to the functions
      -- TODO: Refactor this
      local leaf = invariant { create_leaf }
      local node = invariant { create_node }
      local list = invariant { create_list }
      local cdata = invariant { create_cdata }

      local context = { }
      -- API 3.0 TODO: check and remove comment
      context.boolean = leaf
      context.string = leaf
      context.identifier = leaf
      context.url = leaf
      context.db_id = leaf
      context.number = leaf
      context.integer = leaf
      context.nonnegative_integer = leaf
      context.text = cdata
      context.uuid = leaf
      context.ilist = list
      context.node = node
      context.list_node = node
      context.int_enum = leaf
      context.string_enum = leaf
      context.file = leaf

      context.optional = function(data)
        data.optional = true
        return data
      end

      context.root = function(data)
        data.root = true
        return data
      end

      formats = { }
      for name, fmt in pairs(create_io_formats(context)) do
        local fn = fmt[1]

        tag_types[fn][name] = true

        formats[name] = fn(fmt)
      end
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["input:"..name] = nesting_node_down(format.input.down)
      up["input:"..name] = nesting_node_up(format.input.up)
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["output:"..name] = nesting_node_down(format.output.down)
      up["output:"..name] = nesting_node_up(format.output.up)
    end

--------------------------------------------------------------------------------

    down["api:input"] = node_down(function(walkers, data)
      walkers.nesting_ = 0
      walkers.need_amp_ = false
      walkers.input_name_prefix_ = { }

      local root_name = walkers.path_[1].name

      walkers:named_cat("fmt", "input:" .. root_name) [[

\nopagebreak[4]
\begin{lstlisting}
\hspace{\fill} \\
${fmt:input.GET:]] (root_name) [[}
\end{lstlisting}

${fmt:input.notes:]] (root_name) [[}
]]

      walkers:push_cat("fmt", "input.GET:" .. root_name)
    end)

    up["api:input"] = node_up(function(walkers, data)
      walkers.nesting_ = nil
      walkers.need_amp_ = nil
      walkers.input_name_prefix_ = nil

      if #data == 0 then -- Hack!
        walkers:context_cat() [[

  \em{(Нет)}
]]
       end

      walkers:pop_cat()
    end)

--------------------------------------------------------------------------------

    local cat_output_template = function(walkers, data)
      local root_name = walkers.path_[1].name

      walkers:named_cat("fmt", "output:" .. root_name) [[

\nopagebreak[4]
\subparagraph*{XML:}\linebreak

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.xml}
${fmt:output.xml:]] (root_name) [[}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

\nopagebreak[0]
\subparagraph*{JSON:}\linebreak

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.json}
${fmt:output.json:]] (root_name) [[}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

\nopagebreak[0]
\subparagraph*{Lua:}\linebreak

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {.json}
${fmt:output.lua:]] (root_name) [[}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

${fmt:output.notes:]] (root_name) [[}
]]
    end

    local output_down, output_up
    do
      output_down = function(walkers, data)
        local cat, concat = make_concatter()

        walkers.build_renderer_cat_ = cat
        walkers.build_renderer_concat_ = concat
        walkers.sample_data_ = nil
      end

      local build_renderer_env = setmetatable(
          { },
          {
            __index = function(t, k)
              if k == "build_events_renderer" then
                -- TODO: WTF? Get rid of this!
                local build_events_renderer
                = import 'logic/webservice/client_events.lua'
                {
                  'build_events_renderer'
                }

                t[k] = build_events_renderer

                return build_events_renderer
              end
              error("attempted to read global `" .. tostring(k) .. "'")
            end;

            __newindex = function(t, k)
              error("attempted to write to global `" .. tostring(k) .. "'")
            end;
          }
        )

      local pretty_xml_schema_builder = make_pretty_xml_schema_builder()
      local pretty_json_schema_builder = make_pretty_json_schema_builder()

      output_up = function(walkers, data, build_renderer_src)
        local root_name = walkers.path_[1].name

        build_renderer_src = [[
return function(builder)
  return
]] .. (build_renderer_src) .. [[
end
]]

        local build_renderer = assert(loadstring(build_renderer_src))
        setfenv(build_renderer, build_renderer_env)
        build_renderer = assert(build_renderer())

        if walkers.sample_data_ == nil then
          -- TODO: Print file:line information.
          error(
              "bad implementation: sample data missing for\n"..tstr(data).."\n"
            )
        end

        do
          local render = assert(
              pretty_xml_schema_builder:commit(
                  build_renderer(pretty_xml_schema_builder)
                )
            )

          walkers:named_cat("fmt", "output.xml:" .. root_name) (
              assert(
                  render(walkers.sample_data_)
                ):gsub("[%s\n]+$", "") -- trim trailing whitespaces
            )
        end

        do
          local render = assert(
              pretty_json_schema_builder:commit(
                  build_renderer(pretty_json_schema_builder)
                )
            )

          walkers:named_cat("fmt", "output.json:" .. root_name) (
              assert(
                  render(walkers.sample_data_)
                ):gsub("[%s\n]+$", "") -- trim trailing whitespaces
            )
        end

        do
          walkers:named_cat("fmt", "output.lua:" .. root_name) (
              prettyprint_lua(
                  -- TODO: Inconsistent. Pass table above as well?
                  walkers.sample_data_
                )
            )
        end

        walkers.build_renderer_cat_ = nil
        walkers.build_renderer_concat_ = nil
        walkers.sample_data_ = nil
      end
    end

--------------------------------------------------------------------------------

    down["api:output"] = node_down(function(walkers, data)
      walkers.nesting_ = 0
      output_down(walkers, data)
    end)

    up["api:output"] = node_up(function(walkers, data)
      walkers.nesting_ = nil
      cat_output_template(walkers, data)
      output_up(walkers, data, walkers.build_renderer_concat_())
    end)

--------------------------------------------------------------------------------

    down["api:output_with_events"] = node_down(function(walkers, data)
      output_down(walkers, data)

      walkers.nesting_ = 1
    end)

    up["api:output_with_events"] = node_up(function(walkers, data)
      walkers.nesting_ = nil
      cat_output_template(walkers, data)

      walkers.sample_data_ =
      {
        result = walkers.sample_data_ or { };
        events = { };
      }

      output_up(
          walkers,
          data,
          [[
  builder:node(nil, "ok")
  {
    builder:node "result"
    {
]] .. walkers.build_renderer_concat_() .. [[
    };
    build_events_renderer(builder);
  };
]]
        )
    end)

--------------------------------------------------------------------------------

    local io_types =
    {
      "enum";
      "integer";
      "string";
      "text";
      "timestamp";
    }

    local create_io_type_handler = function(name)
      -- TODO: Implement
      return function(walkers, data)
        local type_descr = name

        -- Hack
        if name == "string" then
          local min, max = data.min_length, data.max_length
          assert(min) -- Should be caught by validate_schema
          assert(max)

          if min == max then
            type_descr = type_descr .. " (" .. min .. ")"
          else
            type_descr = type_descr .. " (" .. min .. ", " .. max .. ")"
          end
        end

        walkers:push_cat("type", data.name) [[


\subsection*{]] (data.name) [[}\index{Типы!]] (data.name) [[}

\nopagebreak[4]
*]] (type_descr) [[*
]]
      end
    end

    for i = 1, #io_types do
      local name = io_types[i]
      down["io_type:"..name] = create_io_type_handler(name)
      up["io_type:"..name] = pop_cat
    end

--------------------------------------------------------------------------------

    down["doc:description"] = node_down(function(walkers, data)
      local path = walkers.path_
      local root_name = path[1].name

      -- Hack?
      local cat
      if #path > 1 and path[#path - 1].namespace == "err" then
        cat = walkers:named_cat(
            "fmt",
            "err.notes:" .. root_name .. "." .. path[#path - 1].tag
          )
      elseif #path == 2 then
        -- Root tag docs
        cat = walkers:named_cat("fmt", "doc.notes:" .. root_name)
      elseif #path > 2 then
        -- Input or output docs
        local io_mode = path[2].tag -- Hack
        cat = walkers:named_cat("fmt", io_mode .. ".notes:" .. root_name)

        cat [[\nopagebreak[2]

*]]
        local need_dot = false
        for i = 1, #path do
          if path[i].namespace == io_mode then
            if need_dot then
              cat "."
            else
              need_dot = true
            end
            cat (path[i].name)
          end
        end
        cat [[:* ]]
      else
        cat = walkers:context_cat()
      end

      cat [[
\nopagebreak[4]
]] (data.name)

      if data.text then
        local text = data.text
        local base_offset = text:match("^(%s+)%S.*")
        if base_offset then
          text = text:sub(#base_offset + 1)
            :gsub("\n"..base_offset, "\n") -- Trim indentation
            :gsub("%s+$", "") -- Trim trailing spaces
        end

        cat [[
\nopagebreak[0]

]] (text)
      end
    end)

    up["doc:description"] = node_up(do_nothing)

--------------------------------------------------------------------------------

    down["doc:comment"] = node_down(function(walkers, data)
      local path = walkers.path_
      local root_name = path[1].name

      -- Hack?
      local cat
      if data.namespace == "err" then
        cat = walkers:named_cat(
            "fmt",
            "err.comment:" .. root_name .. "." .. data.tag
          )
      elseif #path == 2 then
        -- Root tag docs
        cat = walkers:named_cat("fmt", "doc.notes:" .. root_name)
      elseif #path > 2 then
        -- Input or output or additional_errors docs
        local mode = path[2].tag -- Hack
        cat = walkers:named_cat("fmt", mode .. ".comment:" .. root_name)
      else
        cat = walkers:context_cat()
      end

      local text = data.name .. (data.text or "")
      local base_offset = text:match("^(%s+)%S.*")
      if base_offset then
        text = text:sub(#base_offset + 1)
          :gsub("\n"..base_offset, "\n") -- Trim indentation
          :gsub("%s+$", "") -- Trim trailing spaces
      end

      cat [[
\nopagebreak[4]

]] (text)
    end)

    up["doc:comment"] = node_up(do_nothing)

--------------------------------------------------------------------------------

    local additional_errors =
    {
      "ACCOUNT_NOT_FOUND";
      "ACCOUNT_TEMPORARILY_UNAVAILABLE";
      "BANNED";
      "DUPLICATE_EUID";
      "GARDEN_IS_GIFT";
      "NOT_ALLOWED";
      "NOT_ENOUGH_MONEY";
      "NOT_ENOUGH_SPACE";
      "NOT_FOUND";
      "NOT_READY";
      "NOT_SUPPORTED";
      "PLANT_IS_ALIVE";
      "SERVER_FULL";
      "SLOT_ALREADY_BOUGHT";
      "SLOT_NOT_AVAILABLE";
      "UNAUTHORIZED";
      "UNREGISTERED";
-------------------------------------------
---------- sppip errors -------------------
-------------------------------------------
      "APPLICATION_NOT_FOUND";
      "PAYSYSTEM_NOT_FOUND";
    }

    local additional_error_handler = function(walkers, data)
      local root_name = walkers.path_[1].name
      -- TODO: Try \begin{description} instead
      walkers:named_cat("fmt", "additional_errors:" .. root_name) [[
\item ${!:]] (data.tag) [[}${fmt:err.notes:]] (root_name) [[.]] (data.tag) [[}]]
[[${fmt:err.comment:]] (root_name) [[.]] (data.tag) [[}
]]
      end

    for i = 1, #additional_errors do
      down["err:"..additional_errors[i]] = node_down(do_nothing)
      up["err:"..additional_errors[i]] = node_up(additional_error_handler)
    end

--------------------------------------------------------------------------------

    down["api:additional_errors"] = node_down(function(walkers, data)
      local root_name = walkers.path_[1].name
      walkers:named_cat(
          "fmt", "additional_errors:" .. root_name
        ) [[
\begin{itemize}
]]
end)

    up["api:additional_errors"] = node_up(function(walkers, data)
      local root_name = walkers.path_[1].name

      local cat = walkers:named_cat(
          "fmt", "additional_errors:" .. root_name
        )
      -- Hack
      if #data == 0 then
        cat [[

\hspace{\fill}
\linebreak

\em{(Только стандартные)}
]]
      end

      local root_name = walkers.path_[1].name
      walkers:named_cat(
          "fmt", "additional_errors:" .. root_name
        ) [[
\end{itemize}
]]
end)

--------------------------------------------------------------------------------

    down["doc:text"] = node_down(do_nothing)
    up["doc:text"] = node_up(function(walkers, data)
      walkers.cat_ (data.text)
    end)

--------------------------------------------------------------------------------

  end

  local push_cat = function(self, group, name)
    spam("push_cat", group, name)
    local cat = self.cat_groups_[group]:named_cat(name)
    table.insert(self.context_cat_stack_, cat)
    return cat
  end

  local pop_cat = function(self)
    spam("pop_cat")
    assert(table.remove(self.context_cat_stack_))
  end

  local context_cat = function(self)
    return assert(
        self.context_cat_stack_[#self.context_cat_stack_],
        "empty context cat stack"
      )
  end

  -- Not doing push
  local named_cat = function(self, group, name)
    spam("named_cat", group, name)
    return self.cat_groups_[group]:named_cat(name)
  end

  local cat_group_mt =
  {
    __index = function(t, k)
      local v = make_ordered_named_cat_manager()
      t[k] = v
      return v
    end;
  }

  generate_docs = function(schema)
    arguments(
        "table",  schema
      )

    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      push_cat = push_cat;
      pop_cat = pop_cat;
      context_cat = context_cat;
      named_cat = named_cat;
      --
      cat_ = cat;
      cat_groups_ = setmetatable(
          { },
          cat_group_mt
        );
      context_cat_stack_ = { };
      --
      path_ = { };
    }

    log("generating documentation template")

    for i = 1, #schema do
      walk_tagged_tree(schema[i], walkers, "id")
    end

    assert(#walkers.context_cat_stack_ == 0)

    log("filling template placeholders")

    return fill_apidoc_placeholders(
        walkers.cat_groups_,
        schema.version,
        concat()
      )
  end
end

--------------------------------------------------------------------------------

return
{
  generate_docs = generate_docs;
}
