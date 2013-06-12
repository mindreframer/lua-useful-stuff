require "leslie.settings"
require "leslie.class-leslie0"
require "leslie.utils"

module("leslie.tags", package.seeall)

local tags_map = {
    openblock = leslie.parser.BLOCK_TAG_START,
    closeblock = leslie.parser.BLOCK_TAG_END,
    openvariable = leslie.parser.VARIABLE_TAG_START,
    closevariable = leslie.parser.VARIABLE_TAG_END,
    openbrace = leslie.parser.SINGLE_BRACE_START,
    closebrace = leslie.parser.SINGLE_BRACE_END,
    opencomment = leslie.parser.COMMENT_TAG_START,
    closecomment = leslie.parser.COMMENT_TAG_END
}

class("IfNode", _M) (leslie.parser.Node)

---
function IfNode:initialize(nodelist_true, nodelist_false, cond_expression)
  self.nodelist_true = nodelist_true
  self.nodelist_false = nodelist_false
  self.cond_expression = cond_expression
end

---
function IfNode:render(context)
  local cond_value = context:evaluate(self.cond_expression)

  if cond_value and cond_value ~= "" and cond_value ~= 0 then
    do return self.nodelist_true:render(context) end
  end

  return self.nodelist_false:render(context)
end

class("ForNode", _M) (leslie.parser.Node)

---
function ForNode:initialize(nodelist, nodelist_empty, filter_expression, unpack_list)
  self.nodelist = nodelist
  self.nodelist_empty = nodelist_empty
  self.filter_expression = filter_expression
  self.unpack_list = unpack_list
end

---
function ForNode:render(context)
  local bits = {}
  local for_context = context:filter(self.filter_expression)

  if #for_context.context == 0 then
    do return self.nodelist_empty:render(context) end
  end

  local unpack_mode = (#self.unpack_list > 1) and type(for_context.context[1]) == "table"
  local forloop_vars = {}
  local loops = #for_context.context

  if context.context.forloop ~= nil then
    forloop_vars.parentloop = context.context.forloop
  end
  -- todo: loop Context generator
  for i, loop_context in ipairs(for_context.context) do
    forloop_vars.counter = i
    forloop_vars.counter0 = i -1
    forloop_vars.revcounter = loops - i + 1
    forloop_vars.revcounter0 = loops - i
    forloop_vars.first = (i == 1)
    forloop_vars.last = (i == loops)
    
    context.context.forloop = forloop_vars

    if unpack_mode then
      for i, alias in ipairs(self.unpack_list) do
        context.context[alias] = loop_context[i]
      end
    else
      context.context[self.unpack_list[1]] = loop_context
    end

    table.insert(bits, self.nodelist:render(context))
  end

  return table.concat(bits)
end

class("CommentNode", _M) (leslie.parser.Node)

class("FilterNode", _M) (leslie.parser.Node)

---
function FilterNode:initialize(nodelist, filters)
  self.nodelist = nodelist
  self.filters = filters
end

function FilterNode:render(context)
  local s = self.nodelist:render(context)
  
  for _, filter in ipairs(self.filters) do
    s = filter[1](s, filter[2])
  end
  
  return s
end

class("FirstOfNode", _M) (leslie.parser.Node)

---
function FirstOfNode:initialize(vars)
  self.vars = vars
end

---
function FirstOfNode:render(context)
  local value

  while self.vars[1] do
    value = context:evaluate(self.vars[1])
    if value and value ~= "" and value ~= 0 then
      do return tostring(value) end
    end
    table.remove(self.vars, 1)
  end

  return ""
end

class("IfEqualNode", _M) (leslie.parser.Node)

---
function IfEqualNode:initialize(nodelist_true, nodelist_false, var, var2, mode)
  self.nodelist_true = nodelist_true
  self.nodelist_false = nodelist_false
  self.var = var
  self.var2 = var2
  self.mode = mode
end

---
function IfEqualNode:render(context)
  local var_value = context:evaluate(self.var)
  local var2_value = context:evaluate(self.var2)

  local equal = var_value == var2_value or (
          var_value == false and var2_value == 0 or
          var_value == 0 and var2_value == false
        )

  if self.mode == 0 and equal or
    self.mode == 1 and not equal then
    do return self.nodelist_true:render(context) end
  end

  return self.nodelist_false:render(context)
end

class("NowNode", _M) (leslie.parser.Node)

---
function NowNode:initialize(format)
  self.format = leslie.utils.date_format_convert(format)
end

---
function NowNode:render()
  return os.date(self.format, os.time())
end

class("WithNode", _M) (leslie.parser.Node)

---
function WithNode:initialize(nodelist, filter_expression, alias)
  self.nodelist = nodelist
  self.filter_expression = filter_expression
  self.alias = alias
end

---
function WithNode:render(context)
  local with_context = context:filter(self.filter_expression)  
  context.context[self.alias] = with_context.context

  return self.nodelist:render(context)
end

---
function do_if(parser, token)
  local nodelist_true = parser:parse({"else", "endif"})
  local nodelist_false

  if parser:next_token():split_contents()[1] == "else" then
    nodelist_false = parser:parse({"endif"})
    parser:delete_first_token()
  else
    nodelist_false = leslie.parser.NodeList({})
  end

  local args = token:split_contents()

  if #args > 2 then
    error("if command: to many arguments")
  end

  return IfNode(nodelist_true, nodelist_false, args[2])
end

---
function do_for(parser, token)

  local args = token:split_contents()
  local argc = #args
  local unpack_list = {}

  if args[argc - 1] ~= "in" then
    error("for command: invalid arguments")
  end

  if argc > 4 then
    local arg
    for i=2, argc - 2 do
      arg = args[i]
      if arg:sub(-1) == "," then
        arg = arg:sub(1, -2)
      end
      table.insert(unpack_list, arg)
    end
  else
    unpack_list[1] = args[2]
  end

  local nodelist = parser:parse({"empty", "endfor"})
  local nodelist_empty = leslie.parser.NodeList()

  if parser:next_token():split_contents()[1] == "empty" then
    nodelist_empty = parser:parse({"endfor"})
    parser:delete_first_token()
  end

  return ForNode(nodelist, nodelist_empty, args[argc], unpack_list)
end

---
function do_comment(parser, token)
  parser:skip_past("endcomment")

  return CommentNode()
end

---
function do_firstof(parser, token)
  local args = token:split_contents()

  table.remove(args, 1)

  return FirstOfNode(args)
end

---
function do_ifequal(parser, token)
  local nodelist_true = parser:parse({"else", "endifequal"})
  local nodelist_false

  if parser:next_token():split_contents()[1] == "else" then
    nodelist_false = parser:parse({"endifequal"})
    parser:delete_first_token()
  else
    nodelist_false = leslie.parser.NodeList({})
  end

  local args = token:split_contents()

  if #args > 3 then
    error("ifequal command: to many arguments")
  end

  return IfEqualNode(nodelist_true, nodelist_false, args[2], args[3], 0)
end

---
function do_ifnotequal(parser, token)
  local nodelist_true = parser:parse({"else", "endifnotequal"})
  local nodelist_false

  if parser:next_token():split_contents()[1] == "else" then
    nodelist_false = parser:parse({"endifnotequal"})
    parser:delete_first_token()
  else
    nodelist_false = leslie.parser.NodeList({})
  end

  local args = token:split_contents()

  if #args > 3 then
    error("ifequal command: to many arguments")
  end

  return IfEqualNode(nodelist_true, nodelist_false, args[2], args[3], 1)
end

---
function do_with(parser, token)
  local args = token:split_contents()

  if #args > 4 then
    error("if command: to many arguments")
  elseif args[3] ~= "as" then
    error("with command: invalid arguments")
  end

  local nodelist = parser:parse({"endwith"})
  parser:delete_first_token()

  return WithNode(nodelist, args[2], args[4])
end

---
function do_templatetag(parser, token)
  local args = token:split_contents()
  assert(tags_map[args[2]], "Unknown template tag name")

  return leslie.parser.TextNode(tags_map[args[2]])
end

---
function do_now(parser, token)
  local args = token:split_contents()
  
  return NowNode(args[2] or leslie.settings.DATE_FORMAT)
end

---
function do_filter(parser, token)
  local args = token:split_contents()
  
  assert(args[2], "Bad argument")

  local filters = {}
  local nodelist = parser:parse({"endfilter"})
  
  parser:delete_first_token()
  
  for i, filter in ipairs(leslie.utils.split(args[2], leslie.parser.FILTER_SEPARATOR)) do
    filter = leslie.utils.split(filter, leslie.parser.FILTER_ARGUMENT_SEPARATOR, true)
    assert(parser.filters[filter[1]], "filter '" .. filter[1] .. "' unknown.")
    filter[1] = parser.filters[filter[1]]
    table.insert(filters, filter)
  end
  
  return FilterNode(nodelist, filters)
end

local register_tag = leslie.parser.register_tag

-- register builtin tags
register_tag("if")
register_tag("for")
register_tag("comment")
register_tag("firstof")
register_tag("ifequal")
register_tag("ifnotequal")
register_tag("with")
register_tag("templatetag")
register_tag("now")
register_tag("filter")
