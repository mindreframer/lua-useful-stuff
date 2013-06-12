require "leslie"
require "luaunit"

local t = [[{% if name %}Hello my name is {{ name }}.{% else %}Unknown name{% endif %}]]
local tokens_result = {
  { type = leslie.parser.TOKEN_BLOCK, contents = "if name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "Hello my name is " },
  { type = leslie.parser.TOKEN_VAR, contents = "name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "." },
  { type = leslie.parser.TOKEN_BLOCK, contents = "else" },
  { type = leslie.parser.TOKEN_TEXT, contents = "Unknown name" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "endif" },
}
local nodelist_result = {
  leslie.tags.IfNode
}

local t2 = [[{% if name %}
    {# display this text if name is set #}
    Hello my name is {{ name }}.
{% else %}
    Unknown name
{% endif %}
]]

local tokens_result2 = {
  { type = leslie.parser.TOKEN_BLOCK, contents = "if name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "    Hello my name is " },
  { type = leslie.parser.TOKEN_VAR, contents = "name" },
  { type = leslie.parser.TOKEN_TEXT, contents = ".\n" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "else" },
  { type = leslie.parser.TOKEN_TEXT, contents = "    Unknown name\n" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "endif" },
}

local t3 = [[{ no comment }{# some comment #}{% if name %}Hello {{ name }}!{% endif %}]]

local tokens_result3 = {
  { type = leslie.parser.TOKEN_TEXT, contents = "{ no comment }" },
  { type = leslie.parser.TOKEN_COMMENT, contents = "some comment" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "if name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "Hello " },
  { type = leslie.parser.TOKEN_VAR, contents = "name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "!" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "endif" },
}

local t4 = [[{% comment %}{% if name %}Hello {{ name }}!{% else %}What's your name?{% endif %}{% endcomment %}]]
local t5 = [[{% comment %}{% if name %}Hello {{ name }}!{% else %}What's your name?{% endif %}]]

local t6 = [[List of names:
{% for name in names %}
    {{ forloop.counter }}. {{ name }}
{% endfor %}
{% if location %}
    My location is {{ location }}.
{% endif %}]]

local tokens_result6 = {
  { type = leslie.parser.TOKEN_TEXT, contents = "List of names:\n" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "for name in names" },
  { type = leslie.parser.TOKEN_TEXT, contents = "    " },
   { type = leslie.parser.TOKEN_VAR, contents = "forloop.counter" },
  { type = leslie.parser.TOKEN_TEXT, contents = ". " },
  { type = leslie.parser.TOKEN_VAR, contents = "name" },
  { type = leslie.parser.TOKEN_TEXT, contents = "\n" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "endfor" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "if location" },
  { type = leslie.parser.TOKEN_TEXT, contents = "    My location is " },
  { type = leslie.parser.TOKEN_VAR, contents = "location" },
  { type = leslie.parser.TOKEN_TEXT, contents = ".\n" },
  { type = leslie.parser.TOKEN_BLOCK, contents = "endif" },
}

TestToken = {}

function TestToken:setUp()
  self.token = leslie.parser.Token(leslie.parser.TOKEN_TEXT, "Hello my name is ")
end

function TestToken:test_initialize()
  assertEquals(self.token.token_type, leslie.parser.TOKEN_TEXT)
  assertEquals(self.token.contents, "Hello my name is ")
end

TestLexer = {}

function TestLexer:setUp()
  self.lexer = leslie.parser.Lexer()
end

function TestLexer:test_tokenize()
  local tokens = self.lexer:tokenize(t)

  assertEquals(#tokens, #tokens_result)

  for i, token in ipairs(tokens) do
    assertEquals(token.token_type, tokens_result[i].type)
    assertEquals(token.contents, tokens_result[i].contents)
  end
end

function TestLexer:test_tokenize_comments()
  local tokens = self.lexer:tokenize("{ no comment }{# some comment #}")

  assertEquals(#tokens, 2)
  assertEquals(tokens[1].contents, "{ no comment }")
  assertEquals(tokens[1].token_type, leslie.parser.TOKEN_TEXT)
end

function TestLexer:test_tokenize_comments2()
  local tokens = self.lexer:tokenize(t3)

  assertEquals(#tokens, #tokens_result3)

  for i, token in ipairs(tokens) do
    assertEquals(token.token_type, tokens_result3[i].type)
    assertEquals(token.contents, tokens_result3[i].contents)
  end
end

function TestLexer:test_whitespace_trim()
  local tokens = self.lexer:tokenize(t6)

  assertEquals(#tokens, #tokens_result6)

  for i, token in ipairs(tokens) do
    assertEquals(token.token_type, tokens_result6[i].type)
    assertEquals(token.contents, tokens_result6[i].contents)
  end
end

TestLexer__future = {}

function TestLexer__future:setUp()
  self.lexer = leslie.parser.Lexer()
end


function TestLexer__future:test_tokenize()
  local tokens = self.lexer:tokenize(t2)

  assertEquals(#tokens, #tokens_result2)

  for i, token in ipairs(tokens) do
    assertEquals(token.token_type, tokens_result2[i].type)
    assertEquals(token.contents, tokens_result2[i].contents)
  end
end

-- test disable
TestLexer__future = nil

TestParser = {}

function TestParser:setUp()
  local lex = leslie.parser.Lexer()
  self.parser = leslie.parser.Parser(lex:tokenize(t))
end

function TestParser:test_parse()
  local nodelist = self.parser:parse()

  assertEquals(#nodelist.nodes, 1)

  for i, node in ipairs(nodelist.nodes) do
    assertEquals(node:instanceof(nodelist_result[i]), true)
  end
end

function TestParser:test_delete_first_token()
  local size = #self.parser.tokens

  self.parser:delete_first_token()
  assertEquals(#self.parser.tokens, size - 1)
end

function TestParser:test_prepend_token()
  local size = #self.parser.tokens
  local token = leslie.parser.Token(leslie.parser.TOKEN_TEXT, "Hello")

  self.parser:prepend_token(token)

  assertEquals(#self.parser.tokens, size + 1)
end

function TestParser:test_next_token()
  local size = #self.parser.tokens
  local token = leslie.parser.Token(leslie.parser.TOKEN_TEXT, "Hello")

  self.parser:prepend_token(token)

  local next = self.parser:next_token()

  assertEquals(next, token)
  assertEquals(next.contents, "Hello")
  assertEquals(next.token_type, leslie.parser.TOKEN_TEXT)
  assertEquals(#self.parser.tokens, size)
end

TestParser2 = {}

function TestParser2:setUp()
  self.lex = leslie.parser.Lexer()
  self.parser = leslie.parser.Parser(self.lex:tokenize(t4))
end

function TestParser2:test_skip_past()
  local nl, err = pcall(function() self.parser:parse() end)

  assertEquals(err, nil)
end

function TestParser2:test_skip_past_error()
  self.parser.tokens = self.lex:tokenize(t5)
  local nl, err = pcall(function() self.parser:parse() end)

  assertEquals(err ~= nil, true)
end

TestNodeList = {}

function TestNodeList:setUp()
  local lex = leslie.parser.Lexer()
  local parser = leslie.parser.Parser(lex:tokenize(t))
  self.nodelist = parser:parse()
end

function TestNodeList:test_nodelist()
  assertEquals(type(self.nodelist.nodes), "table")
  assertEquals(self.nodelist.class ~= nil, true)
  assertEquals(self.nodelist:instanceof(leslie.parser.NodeList), true)
end

function TestNodeList:test_extend()
  local size = #self.nodelist.nodes
  self.nodelist:extend(leslie.parser.Node())
  assertEquals(#self.nodelist.nodes, size + 1)
end

function TestNodeList:test_render()
  local c = leslie.Context({ name = "Leslie"})
  local c2 = leslie.Context()

  assertEquals(self.nodelist:render(c), "Hello my name is Leslie.")
  assertEquals(self.nodelist:render(c2), "Unknown name")
end

TestContext = {}

function TestContext:test_initialize()
  local t = { name = "Leslie" }
  local c = leslie.Context()
  local c2 = leslie.Context(t)

  assertEquals(#c.context, 0)
  assertEquals(c2.context, t)
end

function TestContext:test_evaluate()
  local c = leslie.Context({ name = "Leslie" })

  assertEquals(c:evaluate("name"), "Leslie")
end

function TestContext:test_evaluate2()
  local c = leslie.Context({ user = { name = "Leslie" }})

  assertEquals(c:evaluate("user.name"), "Leslie")
end

function TestContext:test_evaluate3()
  local c = leslie.Context({ user = { name = "Leslie" }})

  assertEquals(c:evaluate("\"Leslie\""), "Leslie")
end

function TestContext:test_evaluate4()
  local c = leslie.Context({ user = { name = "Leslie" }})

  assertEquals(c:evaluate("'Leslie'"), "Leslie")
end

function TestContext:test_evaluate5_empty()
  local c = leslie.Context({ user = { name = "Leslie" }})

  assertEquals(c:evaluate("user.name.first"), "")
end

function TestContext:test_evaluate6_empty()
  local c = leslie.Context({ user = { name = "Leslie" }})

  assertEquals(c:evaluate("name"), nil)
end

function TestContext:test_filter()
  local c = leslie.Context({ users = {{ name = "Leslie" }}})
  local list = c:filter("users")

  assertEquals(list.context[1].name, "Leslie")
end

function TestContext:test_filter2()
  local c = leslie.Context({ users = { top = {{ user = { name = "Leslie" }}}}})
  local list = c:filter("users.top")

  assertEquals(list.context[1].user.name, "Leslie")
end

TestNode = {}

function TestNode:test_render()
  local n = leslie.parser.Node()

  assertEquals(n:render(), "")
end

TestTextNode = {}

function TestTextNode:setUp()
  self.node = leslie.parser.TextNode(" Leslie ")
end

function TestTextNode:test_initialize()
  assertEquals(self.node.str, " Leslie ")
end

function TestTextNode:test_render()
  assertEquals(self.node:render(), " Leslie ")
end

TestVariableNode = {}

function TestVariableNode:setUp()
  self.node = leslie.parser.VariableNode("user.name")
end

function TestVariableNode:test_initialize()
  assertEquals(self.node.filter_expression, "user.name")
end

function TestVariableNode:test_render()
  local c = leslie.Context({ user = { name = "Leslie"}})

  assertEquals(self.node:render(c), "Leslie")
end

function TestVariableNode:test_render_booltype()
  local c = leslie.Context({ user = { name = true }})

  assertEquals(self.node:render(c), "true")
  c.context.user.name = false
  assertEquals(self.node:render(c), "false")
end

function TestVariableNode:test_render_numbertype()
  local c = leslie.Context({ user = { name = 0 }})

  assertEquals(self.node:render(c), "0")
  c.context.user.name = 3
  assertEquals(self.node:render(c), "3")
end

function TestVariableNode:test_render_empty()
  local c = leslie.Context({ user = {}})

  assertEquals(self.node:render(c), "nil")
end

TestIfNode = {}

function TestIfNode:setUp()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser()
  p.tokens = lex:tokenize("Hello {{ user.name }}!")

  local nl_true = p:parse()
  p.tokens = lex:tokenize("Hello what's your name?")

  local nl_false = p:parse()
  local cond = "user.name"

  self.node = leslie.tags.IfNode(nl_true, nl_false, cond)
end

function TestIfNode:test_initialize()
  assertEquals(self.node.nodelist_true:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.nodelist_false:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.cond_expression, "user.name")
end

function TestIfNode:test_render_true()
  local c = leslie.Context({ user = { name = "Leslie"}})

  assertEquals(self.node:render(c), "Hello Leslie!")
end

function TestIfNode:test_render_false()
  local c = leslie.Context({ user = { name = nil }})

  assertEquals(self.node:render(c), "Hello what's your name?")
end

TestIfEqualNode = {}

function TestIfEqualNode:setUp()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser()
  p.tokens = lex:tokenize("Hello {{ user1.name }} and {{ user2.name }}!")

  local nl_true = p:parse()
  p.tokens = lex:tokenize("Who is {{ user1.name }} and who is {{ user2.name }}?")

  local nl_false = p:parse()
  local var = "user1.name"
  local var2 = "user2.name"

  self.node = leslie.tags.IfEqualNode(nl_true, nl_false, var, var2, 0)
end

function TestIfEqualNode:test_initialize()
  assertEquals(self.node.nodelist_true:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.nodelist_false:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.var, "user1.name")
  assertEquals(self.node.var2, "user2.name")
  assertEquals(self.node.mode, 0)
end

function TestIfEqualNode:test_render_true()
  local c = leslie.Context({ user1 = { name = "Leslie"}, user2 = { name = "Leslie" }})

  assertEquals(self.node:render(c), "Hello Leslie and Leslie!")
end

function TestIfEqualNode:test_render_false()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Django"}})

  assertEquals(self.node:render(c), "Who is Leslie and who is Django?")
end

function TestIfEqualNode:test_render_true2()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Django"}})

  self.node.var2 = "\"Leslie\""
  assertEquals(self.node:render(c), "Hello Leslie and Django!")
  self.node.var = "user2.name"
  assertEquals(self.node:render(c), "Who is Leslie and who is Django?")
end

function TestIfEqualNode:test_render_false2()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Django"}})

  self.node.var = "user2.name"
  self.node.var2 = "\"Leslie\""

  assertEquals(self.node:render(c), "Who is Leslie and who is Django?")
end

TestIfNotEqualNode = {}

function TestIfNotEqualNode:setUp()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser()
  p.tokens = lex:tokenize("Hello {{ user1.name }} and {{ user2.name }}!")

  local nl_true = p:parse()
  p.tokens = lex:tokenize("Who is {{ user1.name }} and who is {{ user2.name }}?")

  local nl_false = p:parse()
  local var = "user1.name"
  local var2 = "user2.name"

  self.node = leslie.tags.IfEqualNode(nl_true, nl_false, var, var2, 1)
end

function TestIfNotEqualNode:test_initialize()
  assertEquals(self.node.nodelist_true:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.nodelist_false:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.var, "user1.name")
  assertEquals(self.node.var2, "user2.name")
  assertEquals(self.node.mode, 1)
end

function TestIfNotEqualNode:test_render_false()
  local c = leslie.Context({ user1 = { name = "Leslie"}, user2 = { name = "Leslie" }})

  assertEquals(self.node:render(c), "Who is Leslie and who is Leslie?")
end

function TestIfNotEqualNode:test_render_true()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Django"}})

  assertEquals(self.node:render(c), "Hello Leslie and Django!")
end

function TestIfNotEqualNode:test_render_false2()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Leslie"}})

  self.node.var2 = "\"Leslie\""

  assertEquals(self.node:render(c), "Who is Leslie and who is Leslie?")
end

function TestIfNotEqualNode:test_render_true2()
  local c = leslie.Context({ user1 = { name = "Leslie" }, user2 = { name = "Django"}})

  self.node.var2 = "\"Django\""

  assertEquals(self.node:render(c), "Hello Leslie and Django!")
end

TestForNode = {}

function TestForNode:setUp()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser()
  p.tokens = lex:tokenize("{{ name }}\n")

  local nl = p:parse()
  p.tokens = lex:tokenize("no items")

  local nl_empty = p:parse()
  p.tokens = lex:tokenize("{% for char in name.chars %}{{ forloop.parentloop.counter }}.{{ forloop.counter }}.{{ char }}.{% endfor %}\n")
  self.nl_subloop = p:parse()
  p.tokens = lex:tokenize("x={{ x }}, y={{ y }};")
  self.nl_argloop = p:parse()
  p.tokens = lex:tokenize("{% for a, b, c in survey.questions %}{% endfor %}\n")
  self.nl_unpack_forloop = p:parse()

  self.node = leslie.tags.ForNode(nl, nl_empty, "names", {"name"})
end

function TestForNode:test_initialize()
  assertEquals(self.node.nodelist:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.nodelist_empty:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.filter_expression, "names")
  assertEquals(self.node.unpack_list[1], "name")
end

function TestForNode:test_render()
  local c = leslie.Context({ names = { "Leslie", "leslie", "LESLIE" }})

  assertEquals(self.node:render(c), "Leslie\nleslie\nLESLIE\n")
end

function TestForNode:test_render_empty()
  local c = leslie.Context({ names = nil })

  assertEquals(self.node:render(c), "no items")
end

function TestForNode:test_unpack_list_parse()
  local fornode = self.nl_unpack_forloop.nodes[1]

  assertEquals(#fornode.unpack_list, 3)

  assertEquals(fornode.unpack_list[1], "a")
  assertEquals(fornode.unpack_list[2], "b")
  assertEquals(fornode.unpack_list[3], "c")
end

function TestForNode:test_args()
  local c = leslie.Context({ points = { {1, 2}, {4, 2}, {6, 9} }})
  self.node.nodelist = self.nl_argloop
  self.node.filter_expression = "points"
  self.node.unpack_list = {"x", "y"}

  assertEquals(self.node:render(c), "x=1, y=2;x=4, y=2;x=6, y=9;")
end

function TestForNode:test_loopvars()
  local c = leslie.Context({
    names = {
      { chars = {"L","e","s","l","i","e"} },
      { chars = {"L","E","S","L","I","E"} }
    }
  })
  local result = "1.1.L.1.2.e.1.3.s.1.4.l.1.5.i.1.6.e.2.1.L.2.2.E.2.3.S.2.4.L.2.5.I.2.6.E."
  self.node.nodelist = self.nl_subloop
  self.node.filter_expression = "names"
  self.node.unpack_list = {"name"}

  assertEquals(self.node:render(c), result)
end

TestWithNode = {}

function TestWithNode:setUp()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser(lex:tokenize("Hello {{ user.name }}!"))
  local nl = p:parse()

  self.node = leslie.tags.WithNode(nl, "users.leslie", "user")
end

function TestWithNode:test_initialize()
  assertEquals(self.node.nodelist:instanceof(leslie.parser.NodeList), true)
  assertEquals(self.node.filter_expression, "users.leslie")
  assertEquals(self.node.alias, "user")
end

function TestWithNode:test_render()
  local c = leslie.Context({ users = { leslie = { name = "Leslie" }}})

  assertEquals(self.node:render(c), "Hello Leslie!")
end

TestFirstOfNode = {}

function TestFirstOfNode:setUp()
  self.vars = { "name", "name2", "\"default\"" }
  self.node = leslie.tags.FirstOfNode(self.vars)
end

function TestFirstOfNode:test_initialize()
  assertEquals(self.node.vars, self.vars)
end

function TestFirstOfNode:test_render()
  local c = leslie.Context({ name = "Leslie" })

  assertEquals(self.node:render(c), "Leslie")
end

function TestFirstOfNode:test_render2()
  local c = leslie.Context({ name = nil })

  assertEquals(self.node:render(c), "default")
end

function TestFirstOfNode:test_render3()
  local c = leslie.Context({ name = "", name2 = "LESLIE" })

  assertEquals(self.node:render(c), "LESLIE")
end

function TestFirstOfNode:test_render4()
  local c = leslie.Context({ name = "", name2 = 0 })

  self.node.vars[3] = "'default'"

  assertEquals(self.node:render(c), "default")
end

function TestFirstOfNode:test_render5()
  local c = leslie.Context({ name = false, name2 = 0 })

  self.node.vars[3] = "'default'"

  assertEquals(self.node:render(c), "default")
end

function TestFirstOfNode:test_render6()
  local c = leslie.Context({ name = true, name2 = 0 })

  self.node.vars[3] = "'default'"

  assertEquals(self.node:render(c), "true")
end

TestCommentNode = {}

function TestCommentNode:test_render()
  local node = leslie.tags.CommentNode("")
  local c = leslie.Context({ name = "Leslie" })

  assertEquals(node:render(c), "")
end

TestExtendsNode = {}

function TestExtendsNode:setUp() end

function TestExtendsNode:test_render()
  local t = leslie.Template([[{% extends "base.txt" %}{% block meta %}Author: Gregor Mazovec{% endblock %}]])
  assertEquals(t:render({title="Leslie template"}), "Leslie template\nAuthor: Gregor Mazovec")
end

function TestExtendsNode:test_render2()
  local t = leslie.Template([[{% extends base %}{% block head %}{{ title }}{% endblock %}]])
  assertEquals(t:render({title="Leslie template", base="base.txt"}), "Leslie template")
end

TestBlockNode = {}

function TestBlockNode:setUp() end

function TestBlockNode:test_render()
  local t = leslie.Template([[{% block test %}Leslie template{% endblock %}]])
  assertEquals(t:render({}), "Leslie template")
end

function TestBlockNode:test_render2()
  local lex = leslie.parser.Lexer()
  local p = leslie.parser.Parser(lex:tokenize("{{ name }} template"))
  local node = leslie.tags.BlockNode("test", p:parse())
  assertEquals(node:render(leslie.Context{name="Leslie"}), "Leslie template")
end

TestIncludeNode = {}

function TestIncludeNode:setUp() end

function TestIncludeNode:test_render()
  local t = leslie.Template([[{% include "template.txt" %}]])
  assertEquals(t:render({name="Leslie"}), "Hello Leslie!\n") 
end

function TestIncludeNode:test_render2()
  local t = leslie.Template([[{% include template %}]])
  assertEquals(t:render({name="Leslie", template="template.txt"}), "Hello Leslie!\n") 
end

TestTemplateTagNode = {}

function TestTemplateTagNode:setUp() end

function TestTemplateTagNode:test_tag1()
  local t = leslie.Template("{% templatetag openblock %}")
  assertEquals(t:render({}), leslie.parser.BLOCK_TAG_START)
end

function TestTemplateTagNode:test_tag2()
  local t = leslie.Template("{% templatetag closeblock %}")
  assertEquals(t:render({}), leslie.parser.BLOCK_TAG_END)
end

function TestTemplateTagNode:test_tag3()
  local t = leslie.Template("{% templatetag openvariable %}")
  assertEquals(t:render({}), leslie.parser.VARIABLE_TAG_START)
end

function TestTemplateTagNode:test_tag4()
  local t = leslie.Template("{% templatetag closevariable %}")
  assertEquals(t:render({}), leslie.parser.VARIABLE_TAG_END)
end

function TestTemplateTagNode:test_tag5()
  local t = leslie.Template("{% templatetag openbrace %}")
  assertEquals(t:render({}), leslie.parser.SINGLE_BRACE_START)
end

function TestTemplateTagNode:test_tag6()
  local t = leslie.Template("{% templatetag closebrace %}")
  assertEquals(t:render({}), leslie.parser.SINGLE_BRACE_END)
end

function TestTemplateTagNode:test_tag7()
  local t = leslie.Template("{% templatetag opencomment %}")
  assertEquals(t:render({}), leslie.parser.COMMENT_TAG_START)
end

function TestTemplateTagNode:test_tag8()
  local t = leslie.Template("{% templatetag closecomment %}")
  assertEquals(t:render({}), leslie.parser.COMMENT_TAG_END)
end

TestTemplate = {}

function TestTemplate:setUp()
  self.template = leslie.Template("Hello {{ name }}!")
end

function TestTemplate:test_initialize()
  assertEquals(self.template.nodelist:instanceof(leslie.parser.NodeList), true)
end

function TestTemplate:test_render()
  local c = leslie.Context({ name = "Leslie" })

  assertEquals(self.template:render(c), "Hello Leslie!")
end

TestTemplate2 = {}

function TestTemplate2:setUp()
  self.template = leslie.Template(t6)
end

function TestTemplate2:test_render()
  local c = leslie.Context({ names = { "Leslie", "Django" } })

  assertEquals(self.template:render(c), "List of names:\n    1. Leslie\n    2. Django\n")
end

function TestTemplate2:test_render()
  local c = leslie.Context({ names = { "Leslie", "Django" }, location = "nowhere" })

  assertEquals(self.template:render(c), "List of names:\n    1. Leslie\n    2. Django\n    My location is nowhere.\n")
end

TestConditions = {}

function TestConditions:test_basic()
  local t = leslie.Template("{% for c in cond %}{% if c %}TRUE{% else %}FALSE{% endif %} {% endfor %}")
  local c = leslie.Context({ cond = { 0, "0", false, true, ""}})

  assertEquals(t:render(c), "FALSE TRUE FALSE TRUE FALSE ")
end

function TestConditions:test_equal()
  local t = leslie.Template("{% for cond in conditions %}{% ifequal cond.a cond.b %}TRUE{% else %}FALSE{% endifequal %} {% endfor %}")
  local c = leslie.Context({ conditions = {
	{ a = 0, b = "0" },
	{ a = 0, b = "" },
	{ a = 0, b = false },
	{ a = 0, b = true },
	{ a = "0", b = "" },
	{ a = "0", b = false },
	{ a = "0", b = true },
	{ a = "", b = false },
	{ a = "", b = true },
        { a = "false", b = false },
  }})

  assertEquals(t:render(c), "FALSE FALSE TRUE FALSE FALSE FALSE FALSE FALSE FALSE FALSE ")
end

function test_loader()
  local t = leslie.loader("template.txt")
  local c = leslie.Context({ name = "Leslie" })

  assertEquals(t:instanceof(leslie.Template), true)
  assertEquals(t:render(c), "Hello Leslie!\n")
end

function test_register_tag()
  local t, err = pcall(function() return leslie.Template([[{% custom %}]]) end)
  
  assertEquals(not err, false)
end

function test_register_tag2()
  
  leslie.parser.register_tag("custom", function(parser, token)
    return leslie.parser.TextNode("CUSTOM TAG")
  end)
  local t = leslie.Template([[{% custom %}]])
  
  assertEquals(t:render(leslie.Context({})), "CUSTOM TAG")
end

function test_scope()
  local t = leslie.Template([[{% with some.var_withlongname as local %}{{ local }} and {{ global }}{% endwith %}]])
  local c = leslie.Context({ global = "Global", some = { var_withlongname = "Local" } })

  assertEquals(t:render(c), "Local and Global")
end

function test_scope2()
  local t = leslie.Template([[{% for name in names %}{{ forloop.counter }}.{{ global }}: {{ name }}{% endfor %}]])
  local c = leslie.Context({ global = "name", names = { "Leslie" } })

  assertEquals(t:render(c), "1.name: Leslie")
end

function test_ssi_include()
  local r, err = pcall(function() return leslie.Template("{% ssi template.txt %}") end)
  assertEquals(not err, false)
end

function test_ssi_include2()
  leslie.ALLOWED_INCLUDE_ROOTS = true
  local r, err = pcall(function() return leslie.Template("{% ssi template.txt %}") end)
  assertEquals(not err, false)
end

function test_ssi_include3()
  local r, err = pcall(function() return leslie.Template("{% ssi /home/leslie/../template.txt %}") end)
  assertEquals(not err, false)
end

TestFunctions = wrapFunctions(
  "test_loader",
  "test_register_tag",
  "test_register_tag2",
  "test_scope",
  "test_scope2",
  "test_ssi_include",
  "test_ssi_include2",
  "test_ssi_include3"
)

LuaUnit:run()
