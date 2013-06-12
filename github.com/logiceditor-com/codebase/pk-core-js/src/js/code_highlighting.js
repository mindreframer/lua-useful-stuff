//------------------------------------------------------------------------------
// code_highlighting.js: Code highlighting module
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.code_highlighting = new function()
{
  if (!window.hljs)
  {
    this.highlight = function(code_text)
    {
      return '<pre>' + PK.entityify_and_escape_quotes(code_text) + '</pre>'
    }
    return
  }

  hljs.initHighlightingOnLoad()

  this.highlight = function(code_text, lang)
  {
    if (lang === undefined)
    {
      lang = "lua"
    }

    var escaped_code_text = PK.entityify_and_escape_quotes(code_text)

    var viewDiv = document.getElementById("highlight-view");
    if(!viewDiv)
    {
      CRITICAL_ERROR("No 'highlight-view' div necessary for code highlighting!")
      return '<pre>' + escaped_code_text + '</pre>'
    }

    viewDiv.innerHTML = '<pre><code class="' + lang + '">' + escaped_code_text + "</code></pre>"
    hljs.highlightBlock(viewDiv.firstChild.firstChild)

    var result = viewDiv.innerHTML
    viewDiv.innerHTML = ""

    return result
  }
};
