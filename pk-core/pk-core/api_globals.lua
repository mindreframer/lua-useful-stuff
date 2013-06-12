--------------------------------------------------------------------------------
-- api_globals.lua: api globals tools
-- This file is a part of pk-core library
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

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_string'
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

local empty_table,
      timap,
      tclone,
      tset,
      tijoin_many,
      tkeys,
      tsetof,
      tset_many,
      tsort_kv
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tclone',
        'tset',
        'tijoin_many',
        'tkeys',
        'tsetof',
        'tset_many',
        'tsort_kv'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local make_chunk_inspector
      = import 'lua-aplicado/chunk_inspector.lua'
      {
        'make_chunk_inspector'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("api_globals", "APG")

--------------------------------------------------------------------------------

local list_globals_in_handler = function(checker, data_id, handler_fn)
  arguments(
      "table", checker,
      "string", data_id,
      "function", handler_fn
    )

  local inspector = make_chunk_inspector(handler_fn)
  if inspector:get_num_upvalues() > 0 then
    checker:fail(
        "bad " .. data_id .. ": handler has " .. inspector:get_num_upvalues()
     .. " upvalue(s), must have none"
      )
  end

  local sets = inspector:list_sets()
  for name, positions in pairs(sets) do
    for i = 1, #positions do
      local pos = positions[i]

      checker:fail(
          "bad " .. data_id .. ": handler changes global"
       .. " `" .. name .. "'"
       .. (
          pos.line and (" at " .. (pos.source or "") .. ":" .. pos.line) or "")
        )
    end
  end

  return inspector:list_gets()
end

--------------------------------------------------------------------------------

local cat_positions = function(cat, positions)
  arguments(
      "function", cat,
      "table", positions
    )

  for i = 1, #positions do
    local pos = positions[i]

    if i > 1 then
      cat ", "
    end

    cat (pos.source or "?") ":" (pos.line or "?")
  end

  return cat
end

local check_globals = function(
    known_exports,
    allowed_requires,
    allowed_globals,
    checker,
    data_id,
    used_globals,
    additional_known_globals
  )
  arguments(
      "table", known_exports,
      "table", allowed_requires,
      "table", allowed_globals,
      "table", checker,
      "string", data_id,
      "table", used_globals,
      "table", additional_known_globals
    )

  -- TODO: Sort errors by line number?
  for name, positions in pairs(used_globals) do
    if
      not (
          known_exports[name]
       or allowed_requires[name]
       or allowed_globals[name]
       or additional_known_globals[name]
       )
    then
      local cat, concat = make_concatter()

      cat "bad " (data_id)
          ": handler accesses unknown global `" (name) "' at "
          cat_positions(cat, positions)

      checker:fail(concat())
    end

    if known_exports[name] and #known_exports[name] > 1 then
      -- TODO: Allow user to resolve ambiguity somehow!
      local cat, concat = make_concatter()

      cat "bad " (data_id)
          ": handler accesses ambiguous global `" (name) "' at "
          cat_positions(cat, positions)
          " could be " (table.concat(known_exports[name], " or "))

      checker:fail(concat())
    end
  end
end

--------------------------------------------------------------------------------

-- NOTE: This function accepts a list, and list_globals_in_handler returns map.
local classify_globals = function(
    known_exports,
    allowed_requires,
    allowed_globals,
    globals_list,
    known_globals
  )
  arguments(
      "table", known_exports,
      "table", allowed_requires,
      "table", allowed_globals,
      "table", globals_list,
      "table", known_globals
    )

  local aliases = { }
  local requires = { }
  local imports = { }

  for i = 1, #globals_list do
    local name = globals_list[i]

    -- WARNING: Handling in order of precedence

    local known_global = known_globals[name] -- TODO: Handle this!

    local export_file = known_exports[name]
    if not known_global and export_file then
      assert(#export_file == 1, "ambiguous global found")
      export_file = export_file[1]
      imports[export_file] = imports[export_file] or { }
      imports[export_file][name] = true
    end

    local require_name = allowed_requires[name]
    if not known_global and not export_file and require_name then
      -- Hack?
      assert(requires[require_name] == nil or requires[require_name] == name)

      requires[require_name] = name
    end

    -- TODO: Detect LJ2-only globals when run under plain Lua?
    local global_alias = allowed_globals[name]
    if
      not known_global
      and not export_file
      and not require_name
      and global_alias
    then
      aliases[name] = name
    end

    if not (known_global or export_file or require_name or global_alias) then
      error("can't classify global: `" .. name .. "'")
    end
  end

  return aliases, requires, imports
end

--------------------------------------------------------------------------------

local generate_globals_header = function(aliases, requires, imports)
  arguments(
      "table", aliases,
      "table", requires,
      "table", imports
    )

  local cat, concat = make_concatter()

  -- TODO: Support "table_sort = table.sort" somehow
  aliases = tsort_kv(aliases)
  for i = 1, #aliases do
    cat [[local ]] (aliases[i].v) [[ = ]] (aliases[i].k) "\n"
  end

  if next(aliases) ~= nil then
    cat "\n" (('-'):rep(80)) "\n" "\n"
  end

  requires = tsort_kv(requires)
  for i = 1, #requires do
    cat [[local ]] (requires[i].v) [[ = require ']] (requires[i].k) [[']] "\n"
  end

  if next(requires) ~= nil then
    cat "\n" (('-'):rep(80)) "\n" "\n"
  end

  -- TODO: Support "table_sort = table.sort" somehow
  imports = tsort_kv(imports)
  for i = 1, #imports do
    local filename, symbols = imports[i].k, tkeys(imports[i].v)
    table.sort(symbols)

    cat [[local ]] (symbols[1])
    for i = 2, #symbols do
      cat [[,]] "\n" [[      ]] (symbols[i])
    end

    cat "\n"
        [[      = import ']] (filename) [[']] "\n"
        [[      {]] "\n"

    for i = 1, #symbols - 1 do
      cat [[        ']] (symbols[i]) [[',]] "\n"
    end

    cat [[        ']] (symbols[#symbols]) [[']] "\n"

    cat [[      }]] "\n"
  end

  if next(imports) ~= nil then
    cat "\n" (('-'):rep(80)) "\n" "\n"
  end

  return concat()
end

--------------------------------------------------------------------------------

return
{
  list_globals_in_handler = list_globals_in_handler;
  check_globals = check_globals;
  classify_globals = classify_globals;
  generate_globals_header = generate_globals_header;
}
