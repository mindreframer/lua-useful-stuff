--------------------------------------------------------------------------------
-- apigen/apidoc.lua: documentation-related utilities
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "apigen/apidoc", "ADC"
        )

--------------------------------------------------------------------------------

local assert, error, setmetatable = assert, error, setmetatable
local os_date = os.date

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

local fill_curly_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'fill_curly_placeholders'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

--------------------------------------------------------------------------------

-- TODO: All section layouts should be configurable via doc:set_layout(name)
--       command from schema itself (that is, "type", "err", "url" etc.)

-- TODO: generate better error messages on bad placeholders

-- TODO: Generalize more. Allow all templates to be configured from outside.
local fill_apidoc_placeholders
do
  local self_key = unique_object()

  local title_prefix_cache = setmetatable(
      { },
      {
        __index = function(t, k)
          local v = ("#"):rep(k) .. " "
          t[k] = v
          return v
        end;
      }
    )

  local wrap_handler = function(cacheable, handler)
    arguments(
        "boolean", cacheable,
        "function", handler
      )
    return
    {
      cacheable = cacheable;
      handler = handler
    }
  end

  local noncacheable = function(handler)
    return wrap_handler(false, handler)
  end

  local cacheable = function(handler)
    return wrap_handler(true, handler)
  end

  local header_handler = function(level)
    local title_prefix = title_prefix_cache[level]
    return cacheable(function(self, title)
      return title_prefix .. title
    end)
  end

  local ref_handler = function(ref_kind)
    return cacheable(function(self, ref_name)
      return self:get_ref_text(ref_kind, ref_name)
    end)
  end

  local impl_handler = function(impl_kind)
    return cacheable(function(self, impl_name)
      return self:get_impl_text(impl_kind, impl_name)
    end)
  end

  local handlers =
  {
    ["h1"] = header_handler(1);
    ["h2"] = header_handler(2);
    ["h3"] = header_handler(3);
    ["h4"] = header_handler(4);
    ["h5"] = header_handler(5);
    --
    ["VERSION"] = cacheable(function(self, version_id)
      -- Asterisk means we exclude this header from TOC
      return [[\subsubsection*{Версия ]] .. version_id .. [[}]]
    end);
    --
    ["/"] = ref_handler("url");
    ["@/"] = impl_handler("url");
    --
    ["T"] = ref_handler("type");
    ["@T"] = impl_handler("type");
    --
    ["E"] = ref_handler("event");
    ["@E"] = impl_handler("event");
    --
    ["!"] = ref_handler("err");
    -- @! is not used
    --
    ["fmt"] = impl_handler("fmt"); -- For internal use
  }

  local mt =
  {
    __index = function(t, k)
      local fn, args = k:match("^(.-):(.+)$")
      if not (fn and args) then
        log_error("unknown placeholder:", k)
        return nil
      end

      local handler_info = handlers[fn]
      if not handler_info then
        log_error("unknown function:", fn, "in placeholder", k)
        return nil
      end

      local v = handler_info.handler(t[self_key], args)
      if handler_info.cacheable then
        t[k] = v
      end

      return v
    end;
  }

  local make_placeholders_manager
  do
    local get_ref_text = function(self, kind, name)
      method_arguments(
          self,
          "string", kind,
          "string", name
        )
      -- TODO: Add actual link

      if kind == "url" then
        return [[\textbf{/]] .. name .. [[}]]
      elseif kind == "type" then
        return [[\textit{]] .. name .. [[}]]
      elseif kind == "event" then
        return [[\verb!]] .. name .. [[!]]
      elseif kind == "err" then
        return [[\verb!]] .. name .. [[!\index{Ошибки!]] .. name .. [[}]]
      end

      error("unknown ref kind " .. kind)
    end

    local get_impl_text = function(self, kind, name)
      method_arguments(
          self,
          "string", kind,
          "string", name
        )

      spam("get_impl_text", kind, name)

      local cat_group = assert(self.ordered_named_cat_managers_[kind])

      local impl_text
      if name == "*" then
        impl_text = cat_group:concat_all()
      else
        impl_text = cat_group:named_concat(name)
      end

      return fill_curly_placeholders(impl_text, assert(self.dict_))
    end

    local set_dict = function(self, dict)
      method_arguments(
          self,
          "table", dict
        )
      self.dict_ = dict
    end

    make_placeholders_manager = function(ordered_named_cat_managers)
      arguments(
          "table", ordered_named_cat_managers
        )

      return
      {
        get_ref_text = get_ref_text;
        get_impl_text = get_impl_text;
        --
        set_dict = set_dict;
        --
        ordered_named_cat_managers_ = ordered_named_cat_managers;
        dict_ = nil;
      }
    end
  end

  fill_apidoc_placeholders = function(
      ordered_named_cat_managers,
      version,
      template
    )
    arguments(
        "table", ordered_named_cat_managers,
        "string", version,
        "string", template
      )

    local manager = make_placeholders_manager(ordered_named_cat_managers)

    -- Assuming markdown-LaTeX-pdf chain
    local dict = setmetatable(
        {
          ["version"] = version;
          ["generation_date"] = os_date();
          ["endofsection"] = [[\newpage]] .. "\n";
          ["index"] = [[\tableofcontents]];
          --
          [self_key] = manager;
        },
        mt
      )

    -- TODO: Hack.
    manager:set_dict(dict)

    return fill_curly_placeholders(template, dict)
  end
end

--------------------------------------------------------------------------------

return
{
  fill_apidoc_placeholders = fill_apidoc_placeholders;
}
