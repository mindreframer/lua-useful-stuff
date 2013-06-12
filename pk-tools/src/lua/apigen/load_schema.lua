--------------------------------------------------------------------------------
-- load_schema.lua: api schema loader
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local is_table,
      is_function,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_function',
        'is_string'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string,
      assert_is_nil
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string',
        'assert_is_nil'
      }

local empty_table,
      tset,
      torderedset,
      torderedset_insert,
      twithdefaults
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'tset',
        'torderedset',
        'torderedset_insert',
        'twithdefaults'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_dsl_loader
      = import 'pk-core/dsl_loader.lua'
      {
        'make_dsl_loader'
      }

local find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("load_schema", "LAS")

--------------------------------------------------------------------------------

local load_schema
do
  local common_data_filter = function(name_data, value_data)
    if is_function(value_data) then
      -- A special case for handler-only tags
      value_data =
      {
        handler = value_data;
      }
    elseif is_string(value_data) then
      -- A special case for text-only tags
      value_data =
      {
        text = value_data;
      }
    end

    -- Letting user to override any default values (including name and tag)
    return twithdefaults(value_data, name_data)
  end

  local common_patch_data = function(namespace, tag, data)
    assert_is_nil(data.tag, "tag field is reserved")
    assert_is_nil(data.namespace, "namespace field is reserved")
    assert_is_nil(data.id, "id field is reserved")

    data.tag = tag
    data.namespace = namespace
    data.id = namespace .. ":" .. tag

    return data
  end

  local create_common_name_filter = function(namespace)
    arguments(
        "string", namespace
      )

    return function(tag, name, ...)
      assert(select("#", ...) == 0, "extra arguments are not supported")

      if is_table(name) then -- data-only-call
        local data = name
        -- Allowing data.name to be missing.
        return common_patch_data(namespace, tag, data)
      end

      return common_patch_data(
          namespace,
          tag,
          {
            name = name;
          }
        )
    end
  end

  local create_common_dsl_loader = function(namespace)
    return make_dsl_loader(
        create_common_name_filter(namespace),
        common_data_filter
      )
  end

  local create_root_name_filter = function(namespace, positions, root_ids)
    local filter = create_common_name_filter(namespace)

    return function(...)
      local data = filter(...)
      if not root_ids or root_ids[data.id] then
        if positions[data.name] then
          -- TODO: Remove this limitation!
          error("bad schema: duplicate top-level tag name " .. data.name)
        end
        torderedset_insert(positions, data.name)
      end
      return data
    end
  end

  local create_root_data_filter = function(dest, positions, root_ids)
    return function(...)
      local data = common_data_filter(...)
      if not root_ids or root_ids[data.id] then
        dest[positions[data.name]] = data
      end
      return data
    end
  end

  local create_root_dsl_loader = function(namespace, dest, positions, root_ids)
    return make_dsl_loader(
        create_root_name_filter(namespace, positions, root_ids),
        create_root_data_filter(dest, positions, root_ids)
      )
  end

  local output_name_filter = function(tag, name, node_name, ...)
    assert(select("#", ...) == 0, "extra arguments are not supported")

    local namespace = "output"

    if is_table(name) then -- data-only-call
      local data = name

      assert(data.name, "name field missing")
      assert(data.node_name, "node_name field missing")

      return common_patch_data(namespace, tag, data)
    end

    return common_patch_data(
        namespace,
        tag,
        {
          name = name;
          node_name = node_name or name;
        }
      )
  end

  local root_tags = tset
  {
    "static_url";
    "cacheable_url";
    "url";
    "url_with_dynamic_output_format";
    "raw_url";
    "export";
    "extend_context";
  }

  load_schema = function(directory_name)
    arguments(
        "string", directory_name
      )

    -- TODO: Move all these functions outside.
    local api = { }
    local positions = torderedset({ })

    do
      local api_name_filter = function(tag, name, ...)
        assert(select("#", ...) == 0, "extra arguments are not supported")

        local namespace = "api"
        if is_table(name) then -- data-only-call
          local data = name
          -- Allowing node.name to be missing

          -- Arbitrary limitation to simplify implementation. Remove if needed.
          assert(
              not root_tags[tag],
              "data-only calls at top level are not supported"
            )
          return common_patch_data(namespace, tag, data)
        end

        if is_function(name) then -- special case for handler call
          local handler = name

          return common_patch_data(namespace, tag, { handler = handler })
        end

        local data = { name = name }
        if root_tags[tag] then
          data.urls = { name }
          -- TODO: FIXME. This should honor urls = {} overrides
          --       (base_url in particular).
          if name:sub(#name) == "/" then
            data.urls[#data.urls + 1] = name .. "index"
            data.filename = name:gsub("%.", "/") .. "index.lua"
          else
            data.filename = name:gsub("%.", "/") .. ".lua"
          end

          -- TODO: Remove this limitation
          if positions[data.name] then
            error(
                "duplicate `" .. "api:"..tag.."' name:"
             .. "`" .. data.name .. "'"
              )
          end

          torderedset_insert(positions, name)
        elseif tag == "version" then
          api.version = assert_is_string(name) -- TODO: ?! HACK!
        else
          -- TODO: This is too early to throw this error!
          --       See pkle for the real way to handle this!
          error(
              'unexpected tag at root: `api:'..tag .. ' "' .. data.name .. '"\''
            )
        end
        return common_patch_data(namespace, tag, data)
      end

      local api_data_filter = function(name_data, value_data)
        -- A special case for handler-only tags
        if is_function(value_data) then
          value_data =
          {
            handler = value_data;
          }
        end

        -- Letting user to override any default values (including name and tag)
        local data = twithdefaults(value_data, name_data)

        if root_tags[data.tag] then
          api[positions[data.name]] = data
        end

        return data
      end

      -- TODO: Use different name and data filters!
      local dsl_loaders =
      {
        api = make_dsl_loader(api_name_filter, api_data_filter);

        output = make_dsl_loader(output_name_filter, common_data_filter);

        input = create_common_dsl_loader("input");
        test = create_common_dsl_loader("test");
        doc = create_root_dsl_loader(
            "doc",
             api,
             positions,
             tset { "doc:text" }
          );
        io_type = create_root_dsl_loader("io_type", api, positions);
        err = create_common_dsl_loader("err");
      }

      local environment =
      {
        import = import; -- This is a trusted sandbox
      }

      for name, dsl_loader in pairs(dsl_loaders) do
        environment[name] = dsl_loader:get_interface()
      end

      local process_file = function(filename)
        log("loading api schema from", filename)

        local chunk = assert(loadfile(filename))
        setfenv(
            chunk,
            setmetatable(
                environment,
                {
                  __index = function(t, k)
                    error("attempted to read global `" .. tostring(k) .. "'", 2)
                  end;

                  __newindex = function(t, k, v)
                    error("attempted to write to global `" .. tostring(k) .. "'", 2)
                  end;
                }
              )
          )

        assert(
            xpcall(
                chunk,
                function(err)
                  log_error("failed to load DSL data:\n"..debug.traceback(err))
                  return err
                end
              )
          )
      end

      --

      local files = find_all_files(directory_name, ".*%.lua$")
      assert(#files > 0, "no schema files found")

      table.sort(files)

      for i = 1, #files do
        process_file(files[i])
      end

      for name, dsl_loader in pairs(dsl_loaders) do
        api = dsl_loader:finalize_data(api)
      end
    end

    return api
  end
end
--------------------------------------------------------------------------------

return
{
  load_schema = load_schema;
}
