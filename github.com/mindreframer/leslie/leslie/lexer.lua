require "leslie.class-leslie0"
require "leslie.utils"

module("leslie.parser", package.seeall)

TOKEN_TEXT = 0
TOKEN_VAR = 1
TOKEN_BLOCK = 2
TOKEN_COMMENT = 3

BLOCK_TAG_START = '{%'
BLOCK_TAG_END = '%}'
VARIABLE_TAG_START = '{{'
VARIABLE_TAG_END = '}}'
COMMENT_TAG_START = '{#'
COMMENT_TAG_END = '#}'
SINGLE_BRACE_START = '{'
SINGLE_BRACE_END = '}'

class("Token", _M)

---
function Token:initialize(token_type, contents)
  self.token_type, self.contents = token_type, contents
end

---
function Token:split_contents()
  return leslie.utils.smart_split(self.contents)
end

class("Lexer", _M)

---
function Lexer:gen()

  local pos = 0
  local last = 1
  local intag = false
  local size = #self.template

  local getnextchar = self.template:gmatch(".")

  for char in getnextchar do
    pos = pos + 1
    if intag then
      if char == "#" then
        local nextchar = getnextchar()
        pos = pos + 1
        -- comment token
        if nextchar == SINGLE_BRACE_END then
          local contents = leslie.utils.strip(self.template:sub(last+2, pos-2))
          coroutine.yield(contents, TOKEN_COMMENT)
          intag = false
          last = pos + 1
        end
      elseif char == SINGLE_BRACE_END then
        local nextchar = getnextchar()
        pos = pos + 1
        -- variable token
        if nextchar == SINGLE_BRACE_END then
          local contents = leslie.utils.strip(self.template:sub(last+2, pos-2))
          coroutine.yield(contents, TOKEN_VAR)
          intag = false
          last = pos + 1
        end
      elseif char == "%" then
        local nextchar = getnextchar()
        pos = pos + 1
        -- block token
        if nextchar == SINGLE_BRACE_END then
          local contents = leslie.utils.strip(self.template:sub(last+2, pos-2))
          coroutine.yield(contents, TOKEN_BLOCK)
          intag = false
          if self.template:sub(pos+1, pos+1) == "\n" then
            last = pos + 2
          else
            last = pos + 1
          end
        end
      end
    else
      if char == SINGLE_BRACE_START then
        local nextchar = getnextchar()
        pos = pos + 1
        -- text token
        if nextchar == SINGLE_BRACE_START or nextchar == "%" or nextchar == "#" then
          if pos > 2 and last < pos-1 then
            coroutine.yield(self.template:sub(last, pos-2), TOKEN_TEXT)
          end
          intag = true
          last = pos - 1
        end
      elseif pos == size then
        coroutine.yield(self.template:sub(last, pos), TOKEN_TEXT)
        intag = false
        last = pos - 1
      end
    end
  end
end

---
function Lexer:tokenize(template)

  self.template = template

  local iter = coroutine.wrap(function()
    self:gen()
  end)

  local tokens = {}
  local token

  for contents, token_type, status in iter do
    token = Token(token_type, contents)
    table.insert(tokens, token)
  end

  return tokens
end
