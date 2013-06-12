--------------------------------------------------------------------------------
-- html_answer_render.lua: helpers for raw handlers
-- This file is a part of pk-admin library
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

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/html_answer_render", "HAR")

--------------------------------------------------------------------------------

local REGISTRATION_FAILURE =
{
  NO_MANDATORY_FIELD    = 1;
  PASSWORDS_DONT_MATCH  = 2;
  CAPTCHA_CHECK_FAILED  = 3;
  LOGIN_EXISTED         = 4;
  EMAIL_EXISTED         = 5;
  LOGIN_STOPPED         = 6;
  VALIDATE_EMAIL_FAILED = 7;
}

--------------------------------------------------------------------------------

local cat_cookie = function(cat, name, value)
  local date = os.date("!%a, %d-%Y-%b %H:%M:%S GMT", os.time() + 24*60*60)
  --local domain = ""
  --local path = "/"

  cat [[<META HTTP-EQUIV="SET-COOKIE" CONTENT="]] (name) "=" (value)
    ";expires=" (date)
    --";domain=" (domain)
    --";path=" (path)
    --";secure"
    '">'
end

--------------------------------------------------------------------------------

local render_login_answer_ok = function(static_url, uid, sid, username)
  --TODO: Move to config?
  local JS_URL = static_url .. "/js"

  local cat, concat = make_concatter()

  cat [[<html><head>]]

  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/cookies.js"></script>]] "\n"
  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/notify_user_logged_in.js"></script>]] "\n"

  cat [[<META HTTP-EQUIV="Refresh" CONTENT="0; URL=/">]]

  cat_cookie(cat, "uid", uid)
  cat_cookie(cat, "sid", sid)
  cat_cookie(cat, "username", username)

  cat [[</head><body onLoad=SetGlobalSessionCookies()></body></html>]]

  return concat()
end


local render_login_answer_unregistered = function(static_url)
  --TODO: Move to config?
  local JS_URL = static_url .. "/js"

  local cat, concat = make_concatter()

  cat [[<html><head>]]

  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/cookies.js"></script>]] "\n"
  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/notify_user_logged_in.js"></script>]] "\n"

  cat [[<META HTTP-EQUIV="Refresh" CONTENT="0; URL=/">]]

  cat_cookie(cat, "server_answer_error", "unregistered user")

  cat [[</head><body onLoad=SetGlobalSessionCookies()></body></html>]]
  return concat()
end

--------------------------------------------------------------------------------

local render_register_answer_failed = function(static_url, err_code)
  --TODO: Move to config?
  local JS_URL = static_url .. "/js"

  local cat, concat = make_concatter()

  cat [[<html><head>]]

  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/cookies.js"></script>]] "\n"
  cat [[<script type="text/javascript" src="]] (JS_URL) [[/core/notify_user_logged_in.js"></script>]] "\n"

  cat [[<META HTTP-EQUIV="Refresh" CONTENT="0; URL=/">]]

  cat_cookie(cat, "server_answer_error", "registration failed " .. err_code)

  cat [[</head><body onLoad=SetGlobalSessionCookies()></body></html>]]
  return concat()
end

--------------------------------------------------------------------------------

local render_index = function(
    static_url, use_debug_extjs,
    common_js, common_modules, topics, generated_topics
  )
  --TODO: Move to config?
  local JS_URL = static_url .. "/js"

  local EXTJS_ALL_SUFFIX = use_debug_extjs and "-debug" or ""

  local EXTJS_RESOURCES_URL = static_url .. "/extjs-resources"
  local EXTJS_UX_URL = static_url .. "/extjs-ux"
  local EXTJS_PLUGINS_URL = static_url .. "/extjs-plugins"
  local EXTJS_ADAPTER_BASE_URL = static_url .. "/extjs-adapter-ext/ext-base.js"
  local EXTJS_ALL_URL = static_url .. "/extjs-all/ext-all" .. EXTJS_ALL_SUFFIX .. ".js"

  local cat, concat = make_concatter()

  -------------------------- Render start of HTML ----------------------------

  cat [[<html>]]

  -------------------------- Render HEAD -------------------------------------

  cat [[<head>]]

  cat [[
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">

    <link rel="stylesheet" type="text/css" href="]] (EXTJS_RESOURCES_URL) [[/css/ext-all.css" />

    <link rel="stylesheet" type="text/css" href="]] (EXTJS_UX_URL) [[/gridfilters/css/GridFilters.css" />
    <link rel="stylesheet" type="text/css" href="]] (EXTJS_UX_URL) [[/gridfilters/css/RangeMenu.css" />

    <link rel="stylesheet" type="text/css" href="]] (static_url) [[/css/admin.css" />
    <link rel="stylesheet" type="text/css" href="]] (static_url) [[/css/icons.css" />

    <!-- reCaptcha -->
    <script type="text/javascript" src="http://www.google.com/recaptcha/api/js/recaptcha_ajax.js"></script>

    <script type="text/javascript" src="]] (EXTJS_ADAPTER_BASE_URL) [["></script>
    <script type="text/javascript" src="]] (EXTJS_ALL_URL) [["></script>

    <!-- extensions -->
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/menu/RangeMenu.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/menu/ListMenu.js"></script>

    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/GridFilters.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/Filter.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/StringFilter.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/DateFilter.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/ListFilter.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/NumericFilter.js"></script>
    <script type="text/javascript" src="]] (EXTJS_UX_URL) [[/gridfilters/filter/BooleanFilter.js"></script>

    <script type="text/javascript" src="]] (EXTJS_PLUGINS_URL) [[/ext.util.md5.js"></script>
  ]]

  for i = 1, #common_js do
    cat [[<script type="text/javascript" src="]] (JS_URL)
      "/" (common_js[i]) [[.js"></script>]] "\n"
  end

  for i = 1, #common_modules do
    cat [[<script type="text/javascript" src="]] (JS_URL)
      "/modules/" (common_modules[i]) [[.js"></script>]] "\n"
  end

  for i = 1, #topics do
    cat [[<script type="text/javascript" src="]] (JS_URL)
      "/modules/topics/" (topics[i]) [[.js"></script>]] "\n"
  end

  for i = 1, #generated_topics do
    cat [[<script type="text/javascript" src="]] (JS_URL)
      "/generated/modules/topics/" (generated_topics[i]) [[.js"></script>]] "\n"
  end

  cat [[</head>]]

  -------------------------- Render BODY -------------------------------------

  cat [[<body>]]

  cat [[
    <!-- Fields required for history management -->
    <form id="history-form" class="x-hidden">
        <input type="hidden" id="x-history-field" />
        <iframe id="x-history-frame"></iframe>
    </form>
  ]]

  cat [[
    <form id="auth-admin-form" action="/session/admin-get" method="POST">
        <input id="auth-admin-username" type="text" name="u" class="x-hidden">
        <input id="auth-admin-password" type="password" name="p" class="x-hidden">
        <input id="auth-admin-submit" type="submit" class="x-hidden">
    </form>
  ]]

  cat [[</body>]]

  -------------------------- Render end of HTML ------------------------------

  cat [[</html>]]

  return concat()
end

--------------------------------------------------------------------------------

return
{
  REGISTRATION_FAILURE = REGISTRATION_FAILURE;
  render_login_answer_ok = render_login_answer_ok;
  render_login_answer_unregistered = render_login_answer_unregistered;
  render_register_answer_failed = render_register_answer_failed;
  render_index = render_index;
}
