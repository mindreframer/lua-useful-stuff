//
// TODO: Move PKAdmin.make_linked_field_editor() to separate file
//

var LFE_PER_PAGE = 1000;

var TEE_WIDTH = 1010;
var TEE_HEIGHT = 550;
var VSCROLL_WIDTH = 20;

//------------------------------------------------------------------------------
//          LINKED FIELD EDITOR
//------------------------------------------------------------------------------

//  Parameters:
//    name
//    tag_type_id
//    linked_tag_type_table
//    linked_tag_type_id
//    columns
//    assigned_objects_request_url
//    linked_object_table_request_url
//    assign_request_url
//    unassign_request_url
PKAdmin.make_linked_field_editor = function(element_id, params)
{
  var HEIGHT_1 = (TEE_HEIGHT - 54)/2, HEIGHT_2 = (TEE_HEIGHT - 54)/2;

  var title_assigned = I18N('Currently assigned'), title_all = I18N('All objects');

  var assigned_objects_panel, all_objects_panel;

  // Make stores
  var store_assigned, store_all;
  {
    var reader_fields = new Array;
    if (params.columns)
    {
      for(f in params.columns)
      {
        reader_fields[reader_fields.length] =
        {
          name: params.columns[f].dataIndex,
          convert: params.columns[f].convert
        }
      }
    }

    store_assigned = PK.common_stores.make_store_with_custom_fields(
      reader_fields, 'id', params.assigned_objects_request_url,
      {
        object_id: element_id,
        tag_type_id: params.tag_type_id
      },
      true
    );

    store_all = PK.common_stores.make_store_with_custom_fields(
      reader_fields, 'id', params.linked_object_table_request_url,
      undefined, false
    );
  }

  // Make top bars
  var tbar_assigned, tbar_all;
  {
    function change_assignment(request_url, id)
    {
      var request_url = PK.make_admin_request_url(request_url);

      // TODO: Must render 'waitMsg' somehow
      Ext.Ajax.request({
        url: request_url,
        method: 'POST',
        params: PK.make_admin_request_params({
            object_id: element_id,
            linked_object_id: id,
            tag_type_id: params.tag_type_id
          }),

        //the function to be called upon failure of the request (404, 403 etc)
        failure:function(response,options)
        {
          PK.on_request_failure(request_url, response.status);
        },

        success:function(srv_raw_response,options)
        {
          var response = Ext.util.JSON.decode(srv_raw_response.responseText);
          if(response)
          {
            if(response.result /*&& response.result.count == 1*/)
            {
              store_assigned.reload();
              //if(params.on_successful_delete) params.on_successful_delete();
            }
            else
            {
              if(response.error)
              {
                PK.on_server_error(response.error.id);
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
    };

    function confirmUnassign()
    {
      if(assigned_objects_panel.selModel.selections.keys.length > 0)
        Ext.Msg.confirm(
          I18N('Loggable action'),
          I18N('Are you sure to unassign') + ' '
              + assigned_objects_panel.selModel.selections.items[0].data.name + '?',
          function(btn) { if(btn == 'yes') {
              change_assignment(
                  params.unassign_request_url,
                  assigned_objects_panel.selModel.selections.keys[0]
                );
            }}
        );
    };

    function confirmAssign()
    {
      if(all_objects_panel.selModel.selections.keys.length > 0)
        Ext.Msg.confirm(
          I18N('Loggable action'),
          I18N('Are you sure to assign') + ' '
              + all_objects_panel.selModel.selections.items[0].data.name + '?',
          function(btn) { if(btn == 'yes') {
              change_assignment(
                  params.assign_request_url,
                  all_objects_panel.selModel.selections.keys[0]
                );
            }}
        );
    };

    tbar_assigned = [{
        text: I18N('Unassign'),
        tooltip: I18N('Click to unassign'),
        iconCls:'icon-unassign',
        handler: confirmUnassign
      }];

    tbar_all = [{
        text: I18N('Assign'),
        tooltip: I18N('Click to assign'),
        iconCls:'icon-assign',
        handler: confirmAssign
      }];
  }


  // Make grid panels

  assigned_objects_panel = PK.make_grid_panel({
      title: title_assigned,
      tbar: tbar_assigned,
      height: HEIGHT_1,
      width: TEE_WIDTH - 3,
      per_page: LFE_PER_PAGE,
      columns: params.columns,
      displayMsg: I18N('Displaying items {0} - {1} of {2}'),
      emptyMsg: I18N('No items'),
      store: store_assigned
    });

  all_objects_panel = PK.make_grid_panel({
      title: title_all,
      tbar: tbar_all,
      height: HEIGHT_2,
      width: TEE_WIDTH - 3,
      per_page: LFE_PER_PAGE,
      columns: params.columns,
      displayMsg: I18N('Displaying items {0} - {1} of {2}'),
      emptyMsg: I18N('No items'),
      store: store_all
    });

  return new Ext.Panel({
      title: params.name,
      items: [assigned_objects_panel, all_objects_panel]
    });
};


//------------------------------------------------------------------------------
//          TABLE ELEMENT EDITOR
//------------------------------------------------------------------------------


// Parameters:
//   topic_name
//   table_view_topic_name
//   title
//   properties
//   server_handler_name
//   msg_on_successful_update
//   msg_on_successful_insert
// Optional parameters:
//   element_id
//   read_only_data
//   table_view_params_maker
//   update_request_params_maker
//   insert_request_params_maker
//   on_successful_update
//   on_successful_insert
//   primaryKey
//   custom_tbar
PKAdmin.make_table_element_editor = function(params)
{
  return new function()
  {
    var panel_;
    var general_properties_panel_;

    var raw_init_ = function(
        properties, linked_tables_data, serialized_fields, show_params
      )
    {
      LOG("initing topic: table_element_editor ");

      var element_id;
      if(params.element_id)
      {
        element_id = params.element_id
      }
      if(show_params && show_params.length > 0 && show_params[0] !== "new")
      {
        element_id = show_params[0]
      }

      var title_;
      if(element_id)
      {
        if(typeof(params.existing_item_title) == "function")
          title_ = params.existing_item_title(element_id, show_params);
        else
          title_ = params.existing_item_title + ' ' + element_id;
      }
      else
      {
        if(typeof(params.new_item_title) == "function")
          title_ = params.new_item_title(show_params);
        else
          title_ = params.new_item_title;
      }

      this.title = title_;


      var reader_fields = new Array;
      var propertyNames = new Object;
      var propertyEditors = new Object;
      var propertyRenderers = new Object;
      var defaultValues = (!element_id) ? new Object : undefined;
      for (var name in properties)
      {
        reader_fields[reader_fields.length] =
        {
          name : name,
          mapping : properties[name].mapping,
          convert : properties[name].convert
        };

        if(properties[name].editor_maker)
          propertyEditors[name] = properties[name].editor_maker();
        if(properties[name].renderer)
          propertyRenderers[name] = properties[name].renderer;

        propertyNames[name] = properties[name].loc_name;

        if(!element_id)
        {
          defaultValues[name] = properties[name].defaultValue;
        }
      }

      function addOrUpdateItem()
      {

        var item = new Object;

        var data = general_properties_panel_.getSource();
        for (var name in properties)
        {
          if(properties[name].serializer)
            properties[name].serializer(data[name], item);
          else
            item[properties[name].mapping] = data[name];
        }

        var hidden_fields = general_properties_panel_.hidden_fields
        if (hidden_fields)
        {
          for (var name in hidden_fields)
            item[name] = hidden_fields[name]
        }

        var request_url, request_params;
        if(element_id)
        {
          // Update existing item

          request_url = PK.make_admin_request_url(
              params.server_handler_name + '/update'
            );

          item.id = element_id;

          if(params.update_request_params_maker)
            request_params = params.update_request_params_maker(item, show_params);
          else
            request_params = PK.make_admin_request_params(item);
        }
        else
        {
          // Add new item

          request_url = PK.make_admin_request_url(
              params.server_handler_name + '/insert'
            );

          if(params.insert_request_params_maker)
            request_params = params.insert_request_params_maker(item, show_params);
          else
            request_params = PK.make_admin_request_params(item);
        }


        //LOG("request_params: " + Ext.encode(request_params));

        // TODO: Must render 'waitMsg' somehow
        Ext.Ajax.request({
          url: request_url,
          method: 'POST',
          params: request_params,

          //the function to be called upon failure of the request (404, 403 etc)
          failure: function(response, options)
          {
            PK.on_request_failure(request_url, response.status);
          },

          success: function(srv_raw_response, options)
          {
            var response = Ext.util.JSON.decode(srv_raw_response.responseText);
            if(response)
            {
              if(response.result)
              {
                if(!element_id && response.result.id !== undefined)
                {
                  Ext.Msg.confirm(
                    I18N('Operation complete'),
                    params.msg_on_successful_insert,
                    function(btn)
                    {
                      if(btn == 'yes')
                      {
                        if(params.on_successful_insert)
                          params.on_successful_insert();
                        PK.navigation.go_to_topic(params.topic_name, show_params, true);
                      }
                      else if(btn == 'no')
                      {
                        var table_view_show_params;
                        if(params.table_view_params_maker)
                          table_view_show_params =
                            params.table_view_params_maker(show_params);

                        PK.navigation.go_to_topic(
                            params.table_view_topic_name,
                            table_view_show_params
                          );
                      }
                    }
                  );
                }
                else if(element_id && (response.result.count == 1))
                {
                  Ext.Msg.alert(
                    I18N('Operation complete'),
                    params.msg_on_successful_update,
                    function(btn)
                    {
                      if(params.on_successful_update)
                        params.on_successful_update();

                      var table_view_show_params;
                      if(params.table_view_params_maker)
                        table_view_show_params =
                          params.table_view_params_maker(show_params);

                      PK.navigation.go_to_topic(
                          params.table_view_topic_name,
                          table_view_show_params
                        );
                    }
                  );
                }
                else // result exists, but doesn't contain 'id' or 'count' fields
                {
                  CRITICAL_ERROR(
                      I18N('Sorry, please try again. Unknown server error.')
                      + ' ' + srv_raw_response.responseText
                    );
                }
              }
              else // no result
              {
                if(response.error)
                {
                  PK.on_server_error(response.error.id);
                }
                else  // no error given by server
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

      function cancelEditing()
      {
        Ext.History.back();
      };

      var theStore = undefined;
      if(element_id)
      {
        var request_params = {id : element_id};
        if(params.get_by_id_request_params_maker)
          request_params = params.get_by_id_request_params_maker(
              request_params, show_params
            );
        else
          request_params = PK.make_admin_request_params(request_params);

        var theProxy = new Ext.data.HttpProxy({
            url: PK.make_admin_request_url(
              params.server_handler_name + '/get_by_id'
            ),
            method: 'POST'
          });

        theProxy.on('exception', PK.common_proxy_request_error_handler);

        var primaryKey = 'id'
        if (params.primaryKey)
          primaryKey = params.primaryKey;

        theStore = new Ext.data.JsonStore(
        {
          proxy: theProxy,
          baseParams: PK.make_admin_request_params(request_params),
          root: 'result',
          id: primaryKey,
          fields: reader_fields
        });
      }

      function makePanel(source)
      {
        var tbar = []
        if(params.read_only_data)
        {
          tbar = []
        }
        else
        {
          tbar = [
            {
              text: I18N('Save'),
              tooltip: I18N('Click to save'),
              iconCls: 'icon-save',
              handler: addOrUpdateItem
            }, '-', //add a separator
            {
              text: I18N('Cancel'),
              tooltip: I18N('Click to cancel editing'),
              iconCls: 'icon-cancel',
              handler: cancelEditing
            }
          ]
        }

        var make_button_handler = function(handler, param1)
        {
          return function() { return handler(param1); }
        }

        var make_button_handler_using_general_panel = function(handler)
        {
          return function() { return handler(general_properties_panel_); }
        }

        if(params.custom_tbar)
        {
          for(var i = 0; i < params.custom_tbar.length; i++)
          {
            if (typeof(params.custom_tbar[i]) != "string")
            {
              var tbar_item =
              {
                text:     params.custom_tbar[i].text,
                tooltip:  params.custom_tbar[i].tooltip,
                iconCls:  params.custom_tbar[i].iconCls,
                handler:  make_button_handler_using_general_panel(
                    params.custom_tbar[i].handler
                  )
              };
              tbar.push(tbar_item);
            }
            else
              tbar.push(params.custom_tbar[i]);
          }
        }

        if (serialized_fields)
        {
          for(var i = 0; i < serialized_fields.length; i++)
          {
            if (typeof(serialized_fields[i]) != "string")
            {
              var tbar_item =
              {
                text:     serialized_fields[i].text,
                tooltip:  serialized_fields[i].tooltip,
                iconCls:  serialized_fields[i].iconCls,
                handler:  make_button_handler(
                    serialized_fields[i].handler,
                    element_id
                  )
              };
              tbar.push(tbar_item);
            }
            else
              tbar.push(serialized_fields[i]);
          }
        }

        var must_have_tabs =
          (linked_tables_data !== undefined && linked_tables_data.length > 0);

        general_properties_panel_ = new Ext.grid.PropertyGrid({
          title  : (must_have_tabs ? I18N('General properties') : title_),
          //autoHeight: false,
          width: params.nameWidth + params.valueWidth + VSCROLL_WIDTH,
          height: TEE_HEIGHT,
          propertyNames: propertyNames,
          source : source,
          customEditors: propertyEditors,
          customRenderers: propertyRenderers,
          tbar: tbar
        });
        general_properties_panel_.getColumnModel().setColumnHeader(0, I18N('Property name'));
        general_properties_panel_.getColumnModel().setColumnHeader(1, I18N('Property value'));
        general_properties_panel_.getColumnModel().setColumnWidth(0, params.nameWidth);
        general_properties_panel_.getColumnModel().setColumnWidth(1, params.valueWidth);

        var main_module = Ext.getCmp('main-module-panel')

        if (!must_have_tabs)
        {
          main_module.add(general_properties_panel_)

          panel_ = general_properties_panel_;
        }
        else
        {
          var tabs = [];
          tabs.push(general_properties_panel_);

          var width = TEE_WIDTH; //general_properties_panel_.getWidth();
          var height = TEE_HEIGHT; //general_properties_panel_.getHeight();

          if (linked_tables_data)
          {
            for(var i = 0; i < linked_tables_data.length; i++)
              tabs.push(PKAdmin.make_linked_field_editor(element_id, linked_tables_data[i]));
          }

          panel_ = new Ext.Panel({
            title  : title_,
            autoHeight: false,
            frame: false,
            width: width,
            height: height,
            layout : 'fit',
            items  : [
              new Ext.TabPanel({
                activeTab: 0,
                frame: false,
                defaults: { /*autoHeight: true*/ },
                items: tabs
              })
            ]
          });

          main_module.add(panel_)
        }

        main_module.doLayout()
      };

      if(element_id)
      {
        theStore.load({
          callback:function(r,options,success)
          {
            if(success && r.length > 0) makePanel(r[0].data);
          }
        });
      }
      else
      {
        makePanel(defaultValues);
      }

      LOG("created topic: table_element_editor " + this.title);
    };

    this.init = function(show_params)
    {
      if(typeof(params.properties) == "function")
      {
        params.properties(
            // is existing element?
            (show_params && show_params.length > 0 && show_params[0] !== "new"),
            // callback
            function(properties, linked_tables_data, serialized_fields)
            {
              raw_init_(
                  properties,
                  linked_tables_data,
                  serialized_fields,
                  show_params
                );
            }
          );
      }
      else
      {
        raw_init_(params.properties, undefined, undefined, show_params);
      }
    };

    this.show = function(show_params)
    {
      if(!panel_) { this.init(show_params); }
  //    panel_.show(show_params);
    };

    this.hide = function()
    {
      if(panel_)
      {
  //      panel_.hide();
        panel_.destroy();
        panel_ = undefined;
      }
    };
  };
};
