//------------------------------------------------------------------------------
// ajax_request_helper.js: Ajax request helper
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace("Ajax");

PKEngine.Ajax.PRINT_RECEIVED_DATA = false;

PKEngine.Ajax.do_request = function(url, type, post_data, event_maker, on_error, on_server_conn_error)
{
  //console.log("Ajax url:", url)
  //console.log(window.printStackTrace().join("\n"))

  on_error = on_error || PKEngine.Ajax.default_error_handler;

  $.ajax(
      url,
      {
          'type' : type,
          'data' : post_data,
          //'dataType' : "json", // TODO: Hack (non-working, BTW), to be removed
          'success' : function(data_in, textStatus, jqXHR)
          {
            if (PKEngine.Ajax.PRINT_RECEIVED_DATA)
            {
              console.log("[Ajax.do_request]: " + url, PK.clone(data_in), textStatus, jqXHR)
            }

//             assert(
//                 typeof(data_in) == "object",
//                 I18N('Invalid format of server response for request "${1}"', url)
//               )
            // TODO: Hack, to be removed
            var data;
            try
            {
              data = (typeof(data_in) == "string") ? JSON.parse(data_in) : data_in;
            }
            catch (ex)
            {
              CRITICAL_ERROR(I18N('Unable to parse server response for request "${1}"', url));
              return;
            }

            if(data)
            {
              if(event_maker)
              {
                PKEngine.EventQueue.push(event_maker(data));
              }
            }
            else
            {
              on_error(url, textStatus, jqXHR);
            }
          },
          'error' : function(jqXHR, textStatus, errorThrown)
          {
            if (
                 textStatus == "timeout"
                 || (jqXHR.readyState == 0 && jqXHR.responseText == "")
                 || jqXHR.status == 500 || jqXHR.status == 502
                 || jqXHR.status == 503 || jqXHR.status == 504
               )
            {
              LOG("ServerConnectionError = " + JSON.stringify(jqXHR));
              if (on_server_conn_error)
              {
                on_server_conn_error();
              }
              return;
            }
            on_error(url, textStatus, jqXHR);
          }
      }
    );
}

PKEngine.Ajax.default_error_handler = function(name, textStatus, jqXHR)
{
  var loc_text_status = I18N("Ajax error NULL")
  switch (textStatus)
  {
    case 'timeout'     : loc_text_status = I18N("Ajax error TIMEOUT"); break;
    case 'error'       : loc_text_status = I18N("Ajax ERROR"); break;
    case 'abort'       : loc_text_status = I18N("Ajax error ABORT"); break;
    case 'parsererror' : loc_text_status = I18N("Ajax error PARSERERROR"); break;
  }

  CRITICAL_ERROR(
      I18N("Bad server answer!") + "<br>"
      + I18N("Request URL: ${1}", name) + "<br>"
      + I18N("Text error: ${1}", loc_text_status) + "<br>"
      + I18N("Response status: ${1}", jqXHR.status) + "<br>"
      + I18N("Response text: ${1}", jqXHR.responseText)
    );
};


PKEngine.Ajax.on_soft_error_received = function(name, error)
{
  assert(error)

  var error_text = error.id ? String(error.id) : JSON.stringify(error)

  CRITICAL_ERROR(
      I18N("Bad server answer!") + "<br>"
      + I18N("Request URL: ${1}", name) + "<br>"
      + I18N("Text error: ${1}", error_text) + "<br>"
    );
};
