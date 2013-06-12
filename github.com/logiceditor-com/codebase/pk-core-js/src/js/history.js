//------------------------------------------------------------------------------
// history.js: Browser history module init
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Note: ExtJS required
//
//------------------------------------------------------------------------------

PK.init_history = function()
{
  Ext.History.init();

  Ext.History.on(
    'change',
    function(token)
    {
      var topic = "";
      var params = [];

      if(token)
      {
        params = token.split(PK.navigation.tokenDelimiter);
        topic = params[0];
        params.splice(0,1);
      }

      PK.navigation.show_topic(topic, params);
    }
  );
};
