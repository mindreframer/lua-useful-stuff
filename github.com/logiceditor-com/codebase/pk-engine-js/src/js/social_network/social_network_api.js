//------------------------------------------------------------------------------
// social_network_api.js: Universal API for work with social networks
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.SocialNetAPI = new function()
{
  this.UNSUPPORTED_API_METHOD = function()
  {
    LOG(I18N('Called unsupported social network API method!'))
    if(window.console && console.log)
    {
      console.log(I18N('Called unsupported social network API method!'))
    }
    return false
  }

  this.NETWORK_TYPE =
  {
    AUTHLESS: 200, // Without authorization - only for test servers

    VK: 210, // vkontakte
    MM: 220, // moimir
    OK: 240, // odnoklassniki

    VK_EXTERNAL: 310 // vkontakte
  }

  this.NETWORK_NAMES = {}
  {
    this.NETWORK_NAMES[this.NETWORK_TYPE.AUTHLESS] = 'authless'

    this.NETWORK_NAMES[this.NETWORK_TYPE.VK] = 'vkontakte'
    this.NETWORK_NAMES[this.NETWORK_TYPE.MM] = 'moimir'
    this.NETWORK_NAMES[this.NETWORK_TYPE.OK] = 'odnoklassniki'
  }

  this.NETWORK_ID_BY_NAME = PK.swap_keys_and_values(this.NETWORK_NAMES);

  //----------------------------------------------------------------------------

  this.api =
  {
    /*
      init (social_network_config, query_params, callback)
      login (callback)

      get_currency_name ()
      get_app_id ()
      get_billing_app_id ()

      // social:getters
      get_uid ()
      get_friends (with_app, without_app) returns false or [ {uid, photo, first_name, last_name} ]
      get_profiles (uids, callback)

      // billing
      get_balance ()
      payment (id, service_name, price, callbacks)

      // social:action
      invite (uid)
      wallPost (uid, msg, image_name, post_id, link)
    */
    has_method: function(name) { return false }
  }

  this.init = function(
      query_params, social_net_config, autodetect_social_net, social_network_name, callback
    )
  {
    var social_network_type, api

    if(social_network_name)
    {
      if (!this.NETWORK_ID_BY_NAME[social_network_name])
      {
        CRITICAL_ERROR(I18N('Unknown social net: ${1}', social_network_name))
      }
      else
      {
        if (this.NETWORK_ID_BY_NAME[social_network_name] == this.NETWORK_TYPE.AUTHLESS)
        {
          social_network_type = this.NETWORK_TYPE.AUTHLESS
          api = PKEngine.SocialNetAPIImpl.Authless
        }
        else if (this.NETWORK_ID_BY_NAME[social_network_name] == this.NETWORK_TYPE.VK)
        {
          // Note: this is used to search in social_net_config
          social_network_type = this.NETWORK_TYPE.VK

          api = PKEngine.SocialNetAPIImpl.VK_External
        }
        else if (this.NETWORK_ID_BY_NAME[social_network_name] == this.NETWORK_TYPE.MM)
        {
          social_network_type = this.NETWORK_TYPE.MM
          api = PKEngine.SocialNetAPIImpl.MM_External
        }
        else if (this.NETWORK_ID_BY_NAME[social_network_name] == this.NETWORK_TYPE.OK)
        {
          CRITICAL_ERROR(I18N("TODO: 'odnoklassniki' are not supported yet!"))
        }
      }
    }
    else if (autodetect_social_net)
    {
      // Next code cannot be called for external authorization purpose

      if (window.VK)
      {
        social_network_type = this.NETWORK_TYPE.VK
        api = PKEngine.SocialNetAPIImpl.VK_Internal
      }
      else if(window.mailru)
      {
        social_network_type = this.NETWORK_TYPE.MM
        api = PKEngine.SocialNetAPIImpl.MM_Internal
      }
      else if (window.FAPI)
      {
        social_network_type = this.NETWORK_TYPE.OK
        api = PKEngine.SocialNetAPIImpl.OK_Internal
      }
    }
    else
    {
      CRITICAL_ERROR(I18N("Invalid parameters for PKEngine.SocialNetAPI.init() call!"))
    }

    assert(social_network_type, I18N("Failed to set social net api!"))

    this.api = api
    this.api.init(
        social_net_config[this.NETWORK_NAMES[social_network_type]],
        query_params,
        callback
      )
  }
}


//------------------------------------------------------------------------------
// authless
//------------------------------------------------------------------------------

PKEngine.check_namespace('SocialNetAPIImpl')

PKEngine.SocialNetAPIImpl.Authless = new function()
{
  var id_

  this.init = function(social_network_config, query_params, callback)
  {
    if (query_params.dbg_authless_uid && query_params.dbg_authless_uid != 'random')
    {
      id_ = query_params.dbg_authless_uid
    }
    else
    {
      id_ = PK.Math.random_int(0, 1000000000)
    }

    callback()
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    callback({
        id: id_,
        session: "<authless session>",
        networkID: PKEngine.SocialNetAPI.NETWORK_TYPE.AUTHLESS
      })
    return true
  }

  //TODO: Implement supported methods
  this.get_currency_name = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_billing_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_uid = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD

  this.get_friends = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  //this.get_friends = function(with_app, without_app, callback)
  //{
  //  callback([{ uid: "223", photo: "ph223", first_name: "a", last_name: "b" }])
  //}

  this.get_profiles = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_balance = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.payment = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.invite = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.wallPost = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
}


//------------------------------------------------------------------------------
// vkontakte
//------------------------------------------------------------------------------

PKEngine.check_namespace('SocialNetAPIImpl')

PKEngine.SocialNetAPIImpl.VK_Internal = new function()
{
  var test_mode_;
  var app_id_;
  var viewer_id_;
  var sid_;
  var images_;
  var auth_key_;
  var billing_app_id_;

  var balance_change_handler_;

  var ensure_vk_api_answer_is_ok_ = function(name, data)
  {
    if (data.error)
    {
      LOG(I18N('${1} returned error:', name) + JSON.stringify(data.error,null,4))
      if(window.console && console.log)
      {
        console.log(I18N('${1} returned error:', name), data.error)
      }
      return false
    }

    if (data.response === undefined)
    {
      LOG(I18N('${1} returned bad answer:', name) + JSON.stringify(data,null,4))
      if(window.console && console.log)
      {
        console.log(I18N('${1} returned bad answer:', name), data)
      }
      return false
    }

    return true
  }

  var on_balance_changed_ = function(balance)
  {
    if (balance_change_handler_)
    {
      var remove_handler = balance_change_handler_(balance)
      if (remove_handler)
        balance_change_handler_ = false
    }
  }

  this.init = function(social_network_config, query_params, callback)
  {
    test_mode_ = social_network_config.test_mode
    app_id_ = social_network_config.apiId
    images_ = social_network_config.images
    viewer_id_ = query_params['viewer_id']
    sid_ = query_params['sid']
    auth_key_ = assert(query_params['auth_key'], I18N("No auth key provided"))
    billing_app_id_ = social_network_config.billing_app_id

    VK.addCallback("onBalanceChanged", on_balance_changed_)
    VK.init(callback)
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    callback({
        id: viewer_id_,
        session: auth_key_, // Note: Could be 'sid_', but be must give auth_key here
        networkID:  PKEngine.SocialNetAPI.NETWORK_TYPE.VK
      })
    return true
  }

  this.get_currency_name = function() { return "votes" }

  this.get_app_id = function() { return app_id_ }
  this.get_billing_app_id = function() { return billing_app_id_ }
  this.get_uid = function() { return viewer_id_ }

  this.get_friends = function(with_app, without_app, callback)
  {
    //console.log("[VK_Internal.get_friends]", with_app, without_app)

    if (with_app === undefined) with_app = true
    if (without_app === undefined) without_app = true

    if(!with_app && !without_app)
      return false

    //console.log("[VK_Internal.get_friends]")
    VK.api("friends.get", { fields:'photo', test_mode: test_mode_ }, function(data)
      {
        //console.log("[friends.get callback]", PK.clone(data))
        if (!ensure_vk_api_answer_is_ok_("friends.get", data)) { callback(false); return }

        // Return all if requested
        if (with_app && without_app)
        {
          //console.log("[friends.get callback] cb for all", data.response)

          // Note: Must convert uids to strings by function's contract
          if (data && data.response)
          {
            for(var i = 0; i < data.response.length; i++)
              data.response[i].uid = String(data.response[i].uid);
          }

          callback(data.response)
          return
        }

        //console.log("[friends.get only without app]")
        VK.api("friends.getAppUsers", { test_mode: test_mode_ }, function(data_app_users)
          {
            //console.log("[friends.getAppUsers data_app_users]", PK.clone(data_app_users))
            if (!ensure_vk_api_answer_is_ok_("friends.getAppUsers", data_app_users)) { callback(false); return }

            // Filter out users with app

            var users_with_app = {}
            for (var i = 0; i < data_app_users.response.length; i++)
            {
              users_with_app[data_app_users.response[i]] = true
            }

            var result = []
            for (var i = 0; i < data.response.length; i++)
            {
              if (
                with_app && users_with_app[data.response[i].uid]
                || without_app && !users_with_app[data.response[i].uid]
              )
                result.push(data.response[i])
            }

            //console.log("[friends.get callback] cb for only without app", PK.clone(users_with_app), PK.clone(result))

            // Note: Must convert uids to strings by function's contract
            if (result)
            {
              for(var i = 0; i < result.length; i++)
                result[i].uid = String(result[i].uid);
            }

            callback(result)
          })
      })

    return true
  }

  this.get_profiles = function(uids, callback)
  {
    VK.api("getProfiles", { uids: uids.join(","), fields:'photo', test_mode: test_mode_ }, function(data)
      {
        if (!ensure_vk_api_answer_is_ok_("getProfiles", data)) { callback(false); return }
        callback(data.response)
      })
    return true
  }

  this.get_balance = function(callback)
  {
    VK.api("getUserBalance", { test_mode: test_mode_ }, function(data)
      {
        if (!ensure_vk_api_answer_is_ok_("getUserBalance", data)) { callback(false); return }
        callback(data.response)
      })
  }

  this.payment = function(id, service_name, price, callbacks)
  {
    balance_change_handler_ = callbacks.vkontakte
    VK.callMethod('showPaymentBox', price)
    return true
  }

  this.invite = function()
  {
    VK.callMethod('showInviteBox')
    return true
  }

  this.wallPost = function(uid, msg, image_name, post_id, link)
  {
    var photo_id
    if (image_name)
    {
      photo_id = assert(images_[image_name], I18N("Invalid picture name: ${1}", String(image_name)))
    }

    if (photo_id)
    {
      VK.api(
          'wall.savePost',
          { wall_id: uid, message: msg, photo_id: photo_id, post_id: post_id, test_mode: test_mode_ },
          function(data)
          {
            if (!ensure_vk_api_answer_is_ok_("wall.savePost", data)) { return }

            VK.callMethod('saveWallPost', data.response.post_hash)
          }
        )
      return true
    }

    var attachment = ""

    if  (photo_id)
      attachment += (attachment == "") ? "photo" + photo_id : ",photo" + photo_id

    if (link)
      attachment += (attachment == "") ? link : "," + link

    if (attachment == "")
      attachment = undefined

    VK.api(
        "wall.post",
        { owner_id: uid, message: msg,  attachment: attachment, test_mode: test_mode_ },
        function(data)
        {
          if (!ensure_vk_api_answer_is_ok_("wall.post", data)) { return }
        }
      )

    return true
  }
}


PKEngine.SocialNetAPIImpl.VK_External = new function()
{
  var test_mode_;
  var app_id_;
  var uid_;
  var open_id_app_id_;
  var access_token_;
  var images_;
  var redirect_url_;
  var billing_app_id_;


//   var ensure_vk_api_answer_is_ok_ = function(name, data)
//   {
//     if (data.error)
//     {
//       LOG(I18N('${1} returned error:', name) + JSON.stringify(data.error,null,4))
//       if(window.console && console.log)
//       {
//         console.log(I18N('${1} returned error:', name), data.error)
//       }
//       return false
//     }
//
//     if (!data.response)
//     {
//       LOG(I18N('${1} returned bad answer:', name) + JSON.stringify(data,null,4))
//       if(window.console && console.log)
//       {
//         console.log(I18N('${1} returned bad answer:', name), data)
//       }
//       return false
//     }
//
//     return true
//   }

  this.init = function(social_network_config, query_params, callback)
  {
    //console.log("VK_External.init")

    // This code cannot be called for internal authorization purpose
    assert(social_network_config.apiId, I18N('Cant authorize user: No apiId!'))

    test_mode_ = social_network_config.test_mode
    app_id_ = social_network_config.apiId
    open_id_app_id_ = social_network_config.openIdAppId
    images_ = social_network_config.images
    billing_app_id_ = social_network_config.billing_app_id
    redirect_url_ = social_network_config.redirectUrl

    // NOTE: read hash params from vk.com
    var vk_hash = window.location.hash.substring(1)
    //console.log('[PKEngine.SocialNetAPIImpl.VK_External.init] hash params from vk.com', vk_hash)

    if (vk_hash)
    {
      var params_array = vk_hash.split('&')
      //console.log('[PKEngine.SocialNetAPIImpl.VK_External.init] hash params array from vk.com', params_array)

      if (params_array.length > 0)
      {
        for (var i = 0; i < params_array.length; i++)
        {
          var param = params_array[i].split('=')
          if (param.length > 0)
          {
            switch(param[0])
            {
              case 'access_token':
                access_token_ = param[1]
                //console.log('[PKEngine.SocialNetAPIImpl.VK_External.init] access_token', access_token_)
                break;
              case 'user_id':
                uid_ = param[1]
                //console.log('[PKEngine.SocialNetAPIImpl.VK_External.init] user_id', uid_)
                break;
            }
          }
        }
      }
    }

    callback()
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    //console.log('[PKEngine.SocialNetAPIImpl.VK_External.login] OAuth login');

    if (uid_ && access_token_)
    {
      callback({
          id: uid_,
          session: access_token_,
          networkID:  PKEngine.SocialNetAPI.NETWORK_TYPE.VK_EXTERNAL
        })
    }
    else
    {
      //console.log('[PKEngine.SocialNetAPIImpl.VK_External.login] redirect to http://oauth.vkontakte.ru/authorize');

      window.location =
        'http://oauth.vkontakte.ru/authorize?client_id=' + open_id_app_id_
        + '&scope=notify,friends,photos,wall,offline'
        + '&display=page'
        + '&redirect_uri=' + redirect_url_
        + '&response_type=token';
    }

    return true
  }

  // Note: currency is not 'votes', since VK used for user authorization only!
  this.get_currency_name = function() { return "rubles" }

  this.get_app_id = function() { return app_id_ }
  this.get_billing_app_id = function() { return billing_app_id_ }
  this.get_uid = function() { return uid_ }

  this.get_friends = function(with_app, without_app, callback)
  {
    // TODO: Ticket #3362: Implement using VK Open API
    callback(false);
    return;

//     //console.log("[VK_External.get_friends]", with_app, without_app)
//
//     if (with_app === undefined) with_app = true
//     if (without_app === undefined) without_app = true
//
//     if(!with_app && !without_app)
//       return false
//
//     console.log("[VK_External.get_friends] all or only without app")
//     VK.api("friends.get", { fields:'photo', test_mode: test_mode_ }, function(data)
//       {
//         console.log("[friends.get callback]", data)
//         if (!ensure_vk_api_answer_is_ok_("friends.get", data)) { callback(false); return }
//
//         // Return all if requested
//         console.log("[friends.get callback] cb for all", data.response)
//
//         // Note: Must convert uids to strings by function's contract
//         if (data && data.response)
//         {
//           for(var i = 0; i < data.response.length; i++)
//             data.response[i].uid = String(data.response[i].uid);
//         }
//
//         callback(data.response)
//         return
//       })
//     return true
  }

  this.get_profiles = function(uids, callback)
  {
    // TODO: Ticket #3362: Implement using VK Open API
    callback(false);
    return;

//     VK.api("getProfiles", { uids: uids.join(","), fields:'photo', test_mode: test_mode_ }, function(data)
//       {
//         if (!ensure_vk_api_answer_is_ok_("getProfiles", data)) { callback(false); return }
//         callback(data.response)
//       })
  }

  // Not supported
  this.get_balance = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.payment = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.invite = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD

  this.wallPost = function(uid, msg, image_name, post_id, link)
  {
    // TODO: Ticket #3362: Implement using VK Open API
    return;

//     var photo_id
//     if (image_name)
//     {
//       photo_id = assert(images_[image_name], I18N("Invalid picture name: ${1}", String(image_name)))
//     }
//
//     if (photo_id)
//     {
//       VK.api(
//           'wall.savePost',
//           { wall_id: uid, message: msg, photo_id: photo_id, post_id: post_id, test_mode: test_mode_ },
//           function(data)
//           {
//             if (!ensure_vk_api_answer_is_ok_("wall.savePost", data)) { return }
//
//             VK.callMethod('saveWallPost', data.response.post_hash)
//           }
//         )
//       return true
//     }
//
//     var attachment = ""
//
//     if  (photo_id)
//       attachment += (attachment == "") ? "photo" + photo_id : ",photo" + photo_id
//
//     if (link)
//       attachment += (attachment == "") ? link : "," + link
//
//     if (attachment == "")
//       attachment = undefined
//
//     VK.api(
//         "wall.post",
//         { owner_id: uid, message: msg,  attachment: attachment, test_mode: test_mode_ },
//         function(data)
//         {
//           if (!ensure_vk_api_answer_is_ok_("wall.post", data)) { return }
//         }
//       )
//
//     return true
  }
}


//------------------------------------------------------------------------------
// moimir
//------------------------------------------------------------------------------


PKEngine.check_namespace('SocialNetAPIImpl')

PKEngine.SocialNetAPIImpl.MM_Internal = new function()
{
  var vid_, session_key_

  this.init = function(social_network_config, query_params, callback)
  {
    assert(social_network_config.private_key, I18N('Cant authorize user: No private_key!'))

    vid_ = query_params['vid']
    session_key_ = query_params['session_key']

    mailru.loader.require('api', function() {
        mailru.app.init(social_network_config.private_key)
        callback()
      })
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    callback({
        id: vid_, session: session_key_,
        networkID: PKEngine.SocialNetAPI.NETWORK_TYPE.MM
      })
    return true
  }

  //TODO: Implement
  this.get_currency_name = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_billing_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_uid = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_friends = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_profiles = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_balance = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD

  this.payment = function(id, service_name, price, callbacks)
  {
    //console.log('trypay', id, service_name, price, mailru.app.payments.showDialog)
    mailru.app.payments.showDialog({ service_id: id, service_name: service_name, mailiki_price: price })
    return true
  }

  this.invite = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD

  this.wallPost = function(uid, msg, image_name, post_id, link)
  {
    // TODO: Use link
    mailru.common.guestbook.post({ uid: uid, title: 'HB', text: msg })
    return true
  }
}


PKEngine.SocialNetAPIImpl.MM_External = new function()
{
  this.init = function(social_network_config, query_params, callback)
  {
    assert(social_network_config.app_id, I18N('Cant authorize user: No apiId!'))
    assert(social_network_config.private_key, I18N('Cant authorize user: No private_key!'))

    mailru.loader.require('api', function() {
        mailru.connect.init(
            social_network_config.app_id,
            social_network_config.private_key
          )
        callback()
      })
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    mailru.events.listen(mailru.connect.events.login, function(session)
    {
      if (session)
      {
        callback({
            id: session.vid, session: session.session_key,
            networkID: PKEngine.SocialNetAPI.NETWORK_TYPE.MM
          })
      }
      else
      {
        callback(null)
      }
    })

    mailru.connect.login([])
    return true
  }

  //TODO: Implement supported methods
  this.get_currency_name = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_billing_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_uid = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_friends = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_profiles = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_balance = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.payment = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.invite = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.wallPost = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
}


//------------------------------------------------------------------------------
// odnoklassniki
//------------------------------------------------------------------------------


PKEngine.check_namespace('SocialNetAPIImpl')

PKEngine.SocialNetAPIImpl.OK_Internal = new function()
{
  var logged_user_id_, session_key_

  this.init = function(social_network_config, query_params, callback)
  {
    logged_user_id_ = query_params['logged_user_id']
    session_key_ = query_params['session_key']

    FAPI.init(query_params['api_server'], query_params['apiconnection'], callback, function(error){})
    return true
  }

  this.has_method = function(name)
  {
    return this[name] && this[name] != PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  }

  this.login = function(callback)
  {
    callback({
        id: logged_user_id_, session: session_key_,
        networkID: PKEngine.SocialNetAPI.NETWORK_TYPE.OK
      })
    return true
  }

  //TODO: Implement supported methods
  this.get_currency_name = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_billing_app_id = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_uid = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_friends = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_profiles = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.get_balance = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD

  this.payment = function(id, service_name, price, callbacks)
  {
    FAPI.UI.showPayment('', service_name, id, price)
    return true
  }

  //TODO: Implement supported methods
  this.invite = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
  this.wallPost = PKEngine.SocialNetAPI.UNSUPPORTED_API_METHOD
}
