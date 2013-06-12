PKAdmin.client_settings = new function()
{
  // TODO: Generalize and move to pk-core-js
  var set_fields = function(object, data)
  {
    for (var i = 0; i < data.length; i++)
      object[data[i][0]] = data[i][1]
  }

  var DEFAULT_TABLE_COLUMN_SETTINGS = []

  set_fields(
      DEFAULT_TABLE_COLUMN_SETTINGS,
      [
        [ PK.table_element_types.STRING,           { hidden  : false, width   : 100 } ],
        [ PK.table_element_types.INT,              { hidden  : false, width   :  50 } ],
        [ PK.table_element_types.ENUM,             { hidden  : false, width   : 100 } ],
        [ PK.table_element_types.BOOL,             { hidden  : false, width   :  50 } ],
        [ PK.table_element_types.DATE,             { hidden  : false, width   : 150 } ],
        [ PK.table_element_types.PHONE,            { hidden  : false, width   : 100 } ],
        [ PK.table_element_types.MAIL,             { hidden  : false, width   : 100 } ],
        [ PK.table_element_types.DB_IDS,           { hidden  : false, width   :  50 } ],
        [ PK.table_element_types.BINARY_DATA,      { hidden  : false, width   :  50 } ],
        [ PK.table_element_types.MONEY,            { hidden  : false, width   :  50 } ],
        [ PK.table_element_types.SERIALIZED_LIST,  { hidden  : false, width   :  50 } ]
      ]
    )

  var table_column_settings_ = {}

  // ---------------------------------------------------------------------------

  this.save = function()
  {
    PK.do_request({
      url: PK.make_admin_request_url(
          "client_settings/update_or_insert"
        ),
      params: PK.make_admin_request_params({
          account_id: PK.user.get_user_id(),
          settings: Ext.util.JSON.encode(table_column_settings_)
        }),
      on_success : function(result) {}
    })
  }

  this.load = function()
  {
    PK.do_request({
      url: PK.make_admin_request_url(
          "client_settings/get_by_id"
        ),
      params : PK.make_admin_request_params({
          id: PK.user.get_user_id(),
        }),
      on_success : function(result)
      {
        table_column_settings_ = Ext.util.JSON.decode(result.settings);
      },
      on_error : function(error)
      {
        if (error.id == "NOT_FOUND")
          return

        CRITICAL_ERROR(
            I18N('Sorry, please try again. Server error: ') + error.id
          );
      }
    })
  }

  // ---------------------------------------------------------------------------

  this.table_column = function(table_name, column_name, field_type, field_index)
  {
    if (!table_column_settings_[table_name])
      table_column_settings_[table_name] = {}

    if (!table_column_settings_[table_name][column_name])
    {
      table_column_settings_[table_name][column_name] = PK.clone(DEFAULT_TABLE_COLUMN_SETTINGS[field_type])

       var caption_width = Ext.util.TextMetrics.measure(
           Ext.get('navigator-menu-data'),
           I18N(column_name)
         ).width
         + 25


      table_column_settings_[table_name][column_name].width = Math.max(
          table_column_settings_[table_name][column_name].width,
          caption_width
        )

      table_column_settings_[table_name][column_name].field_index = field_index
    }

    return table_column_settings_[table_name][column_name]
  }

  this.set_table_column_visibility = function(table_name, column_name, hidden)
  {
    table_column_settings_[table_name][column_name].hidden = hidden

    // TODO: Actually we don't want to save settings on any user's change
    this.save()
  }

  this.change_table_column_order = function(table_name, column_order)
  {
    for (var i = 0; i < column_order.length; i++)
      table_column_settings_[table_name][column_order[i]].field_index = i

    // TODO: Actually we don't want to save settings on any user's change
    this.save()
  }

  this.change_table_column_width = function(table_name, column_name, width)
  {
    table_column_settings_[table_name][column_name].width = width

    // TODO: Actually we don't want to save settings on any user's change
    this.save()
  }
}
