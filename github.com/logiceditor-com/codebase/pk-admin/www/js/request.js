PK.make_admin_request_url = function(suffix)
{
  return "/json/" + suffix;
};

PK.make_admin_request_params = function(params)
{
  var request_params = params;
  request_params["u"] = Ext.state.Manager.get("uid");
  request_params["s"] = Ext.state.Manager.get("sid");
  return params;
};


PK.on_request_failure = function(url, error)
{
  switch(error)
  {
    case 404:
      CRITICAL_ERROR(
          I18N('Server doesn\'t support command: ') + url
        );
      break;

    default:
      CRITICAL_ERROR(
          I18N('Sorry, please try again. Server error: ') + error
        );
  }
};

PK.on_server_error = function(error_id)
{
  switch (error_id)
  {
    case "BAD_INPUT":
      CRITICAL_ERROR(I18N('Invalid server request parameters'));
      break;
    case "UNAUTHORIZED": // Note: Impossible for admin system
      CRITICAL_ERROR(I18N('This user is not authorized'));
      break;
    case "UNREGISTERED":
      CRITICAL_ERROR(I18N('Invalid combination of user name / password'));
      break;
    case "SESSION_EXPIRED":
      CRITICAL_ERROR(I18N('Session expired. Re-login, please.'));
      PK.navigation.go_to_topic("admin-login", undefined, true);
      break;
    case "DUPLICATE_WEBSITE_URL":
      CRITICAL_ERROR(I18N('Duplicated url of website'));
      break;
    default:
      CRITICAL_ERROR(I18N('Sorry, please try again. Server error: ') + error_id);
  }
};

PK.make_common_proxy_request_error_handler = function(on_no_items)
{
  return function(proxy, type, action, response, arg)
  {
    if(type == 'response')
    {
      if(arg.status !== 200)
        PK.on_request_failure(response.url, arg.status);
      else
      {
        var json = Ext.decode(arg.responseText);
        if(json)
        {
          if(json.error)
          {
            PK.on_server_error(json.error.id);
          }
          else if(json.result && json.result.total == 0)
          {
            on_no_items();
          }
          else
          {
            CRITICAL_ERROR(
                I18N('Server answer format is invalid') + ': ' + arg.responseText
              );
          }
        }
        else
        {
          CRITICAL_ERROR(
              I18N('Server answer format is invalid') + ': ' + arg.responseText
            );
        }
      }
    }
    else if(type == 'remove')
    {
      CRITICAL_ERROR(
          I18N('Server is OK, but request returned an error')
        );
    }
  };
};

PK.common_proxy_request_error_handler = PK.make_common_proxy_request_error_handler(
    function() { LOG('No items'); }
  );


PK.do_request = function(params)
{
  // TODO: Must render 'waitMsg' somehow
  Ext.Ajax.request({
    url: params.url,
    method: 'POST',
    params: params.params,

    failure:function(response,options)
    {
      PK.on_request_failure(params.url, response.status);
    },

    success:function(srv_raw_response,options)
    {
      var response = Ext.util.JSON.decode(srv_raw_response.responseText);
      if(response)
      {
        if(response.result /*&& response.result.count == 1*/)
        {
          if(params.on_success)
            params.on_success(response.result)
        }
        else
        {
          if(response.error)
          {
            if(params.on_error)
              params.on_error(response.error)
            else
              PK.on_server_error(response.error.id)
          }
          else
          {
            CRITICAL_ERROR(
                I18N('Sorry, please try again. Unknown server error.')
                + ' ' + srv_raw_response.responseText
              );
          }
        }
      }
      else
      {
        CRITICAL_ERROR(
            I18N('Server answer format is invalid')
            + ': ' + srv_raw_response.responseText
          );
      }
    }
  });
}
