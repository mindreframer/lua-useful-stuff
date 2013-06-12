PK.common_stores = new function()
{
//------------------------------------------------------------------------------

  this.make_reader_fields = function(field_names)
  {
    var reader_fields = new Array;
    for(var i = 0; i < field_names.length; i++)
      reader_fields[reader_fields.length] = {name : field_names[i]};
    return reader_fields;
  };

//------------------------------------------------------------------------------

  // Parameters:
  //   fields
  //   primary_key
  //   request_url
  // Optional parameters:
  //   request_params
  //   autoLoad
  //   on_no_items
  //   remote_sorting_params = { field:<field_name>, dir: <ASC/DESC> }
  this.make_store_with_custom_fields = function(
      fields, primary_key,
      request_url, request_params, autoLoad, on_no_items,
      remote_sorting_params
    )
  {
    var reader = new Ext.data.JsonReader({
        root: 'result.item',
        totalProperty: 'result.total',
        //groupField: 'size',
        id: primary_key,
        fields: fields
      });

    var proxy = new Ext.data.HttpProxy({
        url: PK.make_admin_request_url(request_url),
        method: 'POST'
      });

    if(on_no_items)
      proxy.on('exception', PK.make_common_proxy_request_error_handler(on_no_items));
    else
      proxy.on('exception', PK.common_proxy_request_error_handler);

    var baseParams;
    if(request_params)
      baseParams = request_params;
    else
      baseParams = {};

    var remoteSort = false
    var sortInfo = { field: primary_key, direction: "ASC" }

    if(remote_sorting_params)
    {
      remoteSort = true
      sortInfo = remote_sorting_params
    }

    var store = new Ext.data.Store(
    {
      autoLoad: autoLoad,
      proxy: proxy,
      baseParams: PK.make_admin_request_params(baseParams),
      reader: reader,
      sortInfo: sortInfo,
      remoteSort: remoteSort
    });

    store.on(
      'exception',
      function(proxy, type, action, response, arg)
      {
        if(type == 'response' && arg.status === 200)
        {
          var json = Ext.decode(arg.responseText);
          if(json && !json.error && json.result && json.result.total == 0)
            store.removeAll(false);
        }
      }
    );

   return store;
  }

//------------------------------------------------------------------------------

  // Parameters:
  //   field_names
  //   primary_key
  //   request_url
  // Optional parameters:
  //   request_params
  //   autoLoad
  //   on_no_items
  //   remote_sorting_params = { field:<field_name>, dir: <ASC/DESC> }
  this.make_common_store = function(
      field_names, primary_key,
      request_url, request_params, autoLoad, on_no_items,
      remote_sorting_params
    )
  {
    return this.make_store_with_custom_fields(
        this.make_reader_fields(field_names),
        primary_key,
        request_url,
        request_params,
        autoLoad,
        on_no_items,
        remote_sorting_params
      );
  }

//------------------------------------------------------------------------------

  this.load_store = function(store_name, max_elements)
  {
    if(this[store_name])
      this[store_name].load({ params: {start: 0, limit: max_elements} });
  }

};
