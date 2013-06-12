require "leslie.class-leslie0"
require "leslie.lexer"

module("leslie.parser", package.seeall)

FILTER_SEPARATOR = '|'
FILTER_ARGUMENT_SEPARATOR = ':'
VARIABLE_ATTRIBUTE_SEPARATOR = "."

local registered_tags = {}
local registered_filters = {}

---
function register_tag(name, func)
  if not func then
	  func = leslie.tags["do_".. tostring(name)]
  end
    
  assert(func, "Undefined tag function ".. name)
  assert(type(func) == "function", "Invalid tag function ".. name)

  registered_tags[tostring(name)] = func
end

---
function register_filter(name, func)
  if not func then
	  func = leslie.filters[tostring(name)]
  end
    
  assert(func, "Undefined filter function ".. name)
  assert(type(func) == "function", "Invalid filter function ".. name)

  registered_filters[tostring(name)] = func
end

---
local function nodelist_iterator(nodelist, type)  
  for i, node in ipairs(nodelist.nodes) do
    if not type or node:instanceof(type) then
      coroutine.yield(i, node, nodelist)
      if node.nodelist then
        nodelist_iterator(node.nodelist, type)
      end
    end
  end
end

---
local function findByType(nodelist, type)
  assert(type, "Node type not specified")
  
  return coroutine.wrap(function()
    nodelist_iterator(nodelist, type)
  end)
end

class("Node", _M)

---
function Node:render()
  return ""
end

class("TextNode", _M) (Node)

---
function TextNode:initialize(str)
  self.str = str
end

---
function TextNode:render(context)
  return self.str
end

class("VariableNode", _M) (Node)

---
function VariableNode:initialize(filter_expression)
  local bits = leslie.utils.split(filter_expression, FILTER_SEPARATOR, true)
  local filter
  self.var_name = bits[1]
  self.filter_expressions = {}
  
  for i=2, #bits do
    filter = leslie.utils.split(bits[i], FILTER_ARGUMENT_SEPARATOR, true)
    assert(registered_filters[filter[1]], "filter '" .. filter[1] .. "' unknown.")
    filter[1] = registered_filters[filter[1]]
    table.insert(self.filter_expressions, filter)
  end
end

---
function VariableNode:render(context)
  local s = context:evaluate(self.var_name)

  for _, filter in ipairs(self.filter_expressions) do
    s = filter[1](s, filter[2])
  end
  
  return tostring(s)
end

class("NodeList", _M)

---
function NodeList:initialize()
  self.nodes = {}
end

---
function NodeList:findByType(type)
  return findByType(self, type)
end

---
function NodeList:extend(node)
  table.insert(self.nodes, node)
end

---
function NodeList:render(context)

  local bits = {}

  for i, node in ipairs(self.nodes) do
    data = node:render(context)
    table.insert(bits, data)
  end

  return table.concat(bits)
end

class("Parser", _M)

---
function Parser:initialize(tokens)
  self.tokens = tokens
  self.tags = registered_tags
  self.filters = registered_filters
end

---
function Parser:parse(parse_until)

  local nodelist = NodeList()

  if parse_until == nil then
    parse_until = {}
  end

  while self.tokens[1] do
    token = self:next_token()
    if token.token_type == TOKEN_TEXT then
      local node = TextNode(token.contents)
      nodelist:extend(node)
    elseif token.token_type == TOKEN_VAR then
      local node = VariableNode(token.contents)
      nodelist:extend(node)
    elseif token.token_type == TOKEN_BLOCK then
      local command = token:split_contents()[1]
      for _, until_command in ipairs(parse_until) do
        if command == until_command then
          self:prepend_token(token)
          do return nodelist end
        end
      end

      local compile_func = self.tags[command]
      assert(compile_func, "tag '" .. command .. "' unknown.")
      local node = compile_func(self, token)
      nodelist:extend(node)
    end
  end

  return nodelist
end

---
function Parser:skip_past(end_tag)
  while self.tokens[1] do
    token = self:next_token()
    if token.token_type == TOKEN_BLOCK and token.contents == end_tag then
      do return end
    end
  end
  error("End tag " .. end_tag .. " not found")
end

---
function Parser:next_token()
  return table.remove(self.tokens, 1)
end

---
function Parser:prepend_token(token)
  table.insert(self.tokens, 1, token)
end

---
function Parser:delete_first_token()
  table.remove(self.tokens, 1)
end
