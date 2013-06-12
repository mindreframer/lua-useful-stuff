require "leslie.class-leslie0"

module("leslie.tags", package.seeall)

local function check_include_path(path)

  if #leslie.settings.ALLOWED_INCLUDE_ROOTS == 0 then
    error("SSI include ".. path .." not allowed")
  end
  
  if path:sub(1, 1) ~= "/" and path:sub(3, 3) ~= "/" then
    error("Path must be specified using an absolute path")
  end
  
  if path:match("%.%./") or path:match("%./") then
    error("Path must be specified using an absolute path")
  end
  
  for _, root in ipairs(leslie.settings.ALLOWED_INCLUDE_ROOTS) do
    if path:find(root) ~= 1 then
      error("SSI include ".. path .." not allowed")
    end
  end
  
  return true
end

class("BlockNode", _M) (leslie.parser.Node)

---
function BlockNode:initialize(name, nodelist)
  self.name = name
  self.nodelist = nodelist
end

---
function BlockNode:render(context)
  return self.nodelist:render(context)
end

class("ExtendsNode", _M) (leslie.parser.Node)

---
function ExtendsNode:initialize(nodelist, parent_name)
  self.nodelist = nodelist
  self.name = parent_name
  self.blocks = {}

  for pos, node in nodelist:findByType(BlockNode) do
    self.blocks[node.name] = node
  end
end

---
function ExtendsNode:render(context)
  local name = context:evaluate(self.name)
  local template = leslie.loader(name)

  for pos, node, parent in template.nodelist:findByType(BlockNode) do
    if self.blocks[node.name] then
      parent.nodes[pos] = self.blocks[node.name]
    end
    self.blocks[node.name] = node
  end

  return template:render(context)
end

class("IncludeNode", _M) (leslie.parser.Node)

---
function IncludeNode:initialize(template_name)
  self.template_name = template_name
end

---
function IncludeNode:render(context)
  local name = context:evaluate(self.template_name)

  return leslie.loader(name):render(context)
end

---
function do_block(parser, token)
  local args = token:split_contents()
  local nodelist = parser:parse({"endblock"})
  local block_name = args[2]
  
  parser:delete_first_token()

  return BlockNode(block_name, nodelist)
end

---
function do_extends(parser, token)
  local args = token:split_contents()
     
  return ExtendsNode(parser:parse(), args[2])
end

---
function do_include(parser, token)
  local args = token:split_contents()
    
  return IncludeNode(args[2])
end

---
function do_ssi(parser, token)
  local args = token:split_contents()
  local template_path = args[2]
  
  check_include_path(template_path)
  
  if args[3] == "parsed" then
    do return leslie.loader(template_path) end
  else
    local file, err = io.open(template_path, "r")

    if err then
      error("SSI include " .. template_path .. " not found")
    end
    
    do return leslie.parser.TextNode(file:read("*a")) end
  end
end

local register_tag = leslie.parser.register_tag

register_tag("block")
register_tag("extends")
register_tag("include")
register_tag("ssi")
