//------------------------------------------------------------------------------
//                           FILTER PANEL
//------------------------------------------------------------------------------

PKAdmin.make_filter_panel = function(filters)
{
  var filter_panel = undefined,
      current_filters = {},
      num_current_filters = 0

  var addFilter = function(el, item)
  {
    if (current_filters[item.data.field_name])
    {
      Ext.Msg.alert(I18N('Warning'), I18N('This field is already used in another filter'));
      return
    }

    current_filters[item.data.field_name] = true
    ++num_current_filters

    var filter_control = item.data.filter.render()

    if(num_current_filters % 2 == 1)
      filter_panel.get('left').add(filter_control)
    else
      filter_panel.get('right').add(filter_control)

    filter_panel.doLayout()
  }

  var applyFilters = function()
  {
    Ext.Msg.alert(I18N('TODO'), I18N('Not implemented yet'));
  }

  var clearFilters = function()
  {
    filter_panel.get('left').removeAll()
    filter_panel.get('right').removeAll()

    filter_panel.doLayout()

    current_filters = {}
    num_current_filters = 0
  }

  var loadFilters = function()
  {
    Ext.Msg.alert(I18N('TODO'), I18N('Not implemented yet'));
  }

  var saveFilters = function()
  {
    Ext.Msg.alert(I18N('TODO'), I18N('Not implemented yet'));
  }

  var exportData = function()
  {
    Ext.Msg.alert(I18N('TODO'), I18N('Not implemented yet'));
  }

  var drawChart = function()
  {
    Ext.Msg.alert(I18N('TODO'), I18N('Not implemented yet'));
  }

  var disabled = !filters || filters.length < 1

  filter_panel = new Ext.Panel({
    collapsible: true,
    title: I18N('Filters'),
    autoHeight: true,
    //height: 200,
    xtype: 'panel',
    autoScroll: true,
    layout:'column',
    bodyStyle:'padding:2px 2px 2px 2px',

    tbar: new Ext.Toolbar({
      disabled: disabled,
      items:
      [
        {
          xtype: 'combo',
          emptyText: I18N('Add new filter'),
          store: new Ext.data.ArrayStore({
            fields: ['field_name', 'field_title', 'filter'],
            data: filters
          }),
          valueField: 'field_name',
          displayField: 'field_title',
          editable: false,
          typeAhead: true,
          mode: 'local',
          triggerAction: 'all',
          selectOnFocus: true,
          width: 150,
          listeners: { select : addFilter }
        },
        {
          text: I18N('Apply'),
          tooltip: I18N('Apply filters'),
          iconCls: 'icon-apply',
          handler: applyFilters
        },
        {
          text: I18N('Clear'),
          tooltip: I18N('Clear filters'),
          iconCls: 'icon-delete',
          handler: clearFilters
        },
        {
          text: I18N('Load'),
          tooltip: I18N('Load filters'),
          iconCls: 'icon-load',
          handler: loadFilters
        },
        {
          text: I18N('Save'),
          tooltip: I18N('Save filters'),
          iconCls: 'icon-save',
          handler: saveFilters
        },
        "-",
        {
          text: I18N('Export data'),
          tooltip: I18N('Export data'),
          iconCls: 'icon-export-data',
          handler: exportData
        },
        "-",
        {
          text: I18N('Draw chart'),
          tooltip: I18N('Draw chart'),
          iconCls: 'icon-draw-chart',
          handler: drawChart
        }
      ]
    }),

    items:
    [
      {
        layout: 'form',
        id: 'left',
        baseCls: 'x-plain',
        columnWidth: 0.5
      },
      {
        layout: 'form',
        id: 'right',
        baseCls: 'x-plain',
        columnWidth: 0.5
      }
    ]
  })

  return filter_panel
}


//------------------------------------------------------------------------------
//                           GRID PANEL
//------------------------------------------------------------------------------

// Parameters:
//   title
//   tbar
//   bbar
//   height
//   width
//   per_page
//   displayMsg
//   emptyMsg
//   render_to
//   columns,
//   colModel_listeners, gridPanel_listeners
//   filters
//   store
PKAdmin.make_grid_panel = function(params)
{
  var plugins
  if(params.filters)
  {
    plugins = [params.filters];
  }

  var panel = new Ext.grid.GridPanel({
    renderTo: params.render_to,
    //frame: false,
    //hidden: true,
    store: params.store,
    colModel: new Ext.grid.ColumnModel({
      columns: params.columns,
      listeners: params.colModel_listeners
    }),
    listeners: params.gridPanel_listeners,
    loadMask: true,
    plugins: plugins,
    stripeRows: true,
    //autoExpandColumn: params.autoExpandColumn,
    height: params.height,
    width: params.width,
    title: params.title,
    iconCls: 'icon-grid',
    sm: new Ext.grid.RowSelectionModel({singleSelect:true}),
    viewConfig : {
      columnsText:  I18N('Columns'),
      sortAscText:  I18N('Sort asc'),
      sortDescText: I18N('Sort desc')
    },
    bbar: new Ext.PagingToolbar({
      store: params.store, // grid and PagingToolbar using same store
      displayInfo: true,
      pageSize: params.per_page,
      prependButtons: true,
      displayMsg: params.displayMsg,
      emptyMsg: params.emptyMsg
    }),
    tbar: params.tbar,
    bbar: params.bbar
  });

  if (params.store !== undefined)
  {
    //params.store.on("load", function() { panel.show(); } );
    params.store.load({ params: { start: 0, limit: params.per_page }});
  }

  return panel;
}


//------------------------------------------------------------------------------
//                           TABLE VIEW PANEL
//------------------------------------------------------------------------------

// Parameters:
//   title
//   name
//   primaryKey
//   displayMsg
//   emptyMsg
//   table_element_editor
//   server_handler_name
// Optional parameters:
//   read_only_data
//   append_only_data
//   prohibit_deletion
//   store_maker
//   remote_sorting_params
//   on_add_item
//   on_edit_item
//   on_successful_delete
//   add_request_params
//   per_page
//   custom_tbar
PKAdmin.make_table_view_panel = function(
    grid_panel_getter, title, columns, params, show_params
  )
{
  var per_page = 20
  if (params.per_page !== undefined)
    per_page = params.per_page

  var reader_fields = [], filters = []

  for(var i = 0; i < columns.length; i++)
  {
    if (columns[i].hidden === undefined)
      columns[i].hidden =
        PKAdmin.client_settings.table_column(
            params.name,
            columns[i].dataIndex,
            columns[i].value_type
          ).hidden

    if (columns[i].width === undefined)
      columns[i].width =
        PKAdmin.client_settings.table_column(
            params.name,
            columns[i].dataIndex,
            columns[i].value_type
          ).width

    reader_fields.push({
      name: columns[i].dataIndex,
      convert: columns[i].convert
    })

    if (columns[i].filter)
      filters.push([
        columns[i].dataIndex,
        columns[i].header,
        columns[i].filter
      ])
  }


  var grid_filters = undefined
//   var grid_filters = new Ext.ux.grid.GridFilters({
//     local: true, // false
//
//     filters:[
//       {dataIndex: params.primaryKey,   type: 'numeric'},
//       {dataIndex: 'name',    type: 'string'}
//       //{
//       //  dataIndex: 'risk',
//       //  type: 'list',
//       //  active:false,//whether filter value is activated
//       //  value:'low',//default filter value
//       //  options: ['low','medium','high'],
//       //  //if local = false or unspecified, phpMode has an effect
//       //  phpMode: false
//       //}
//     ]
//   });


  if(params.store_maker)
  {
    store_ = params.store_maker(
        reader_fields, params.server_handler_name, per_page, show_params
      );
  }
  else
  {
    var request_params = undefined;
    if(params.add_request_params)
    {
      request_params = {};
      params.add_request_params(request_params, show_params);
    }

    store_ = PK.common_stores.make_store_with_custom_fields(
      reader_fields, params.primaryKey, params.server_handler_name + '/list',
      request_params, false, undefined, params.remote_sorting_params
    );
  }

  function addItem()
  {
    if(params.on_add_item)
      params.on_add_item(params.table_element_editor, show_params);
    else
      PK.navigation.go_to_topic(params.table_element_editor, ["new"]);
  };

  function editItem(id)
  {
    if(!id && grid_panel_getter().selModel.selections.keys.length > 0)
    {
      id = grid_panel_getter().selModel.selections.keys[0];
    }

    if(id)
    {
      if(params.on_edit_item)
        params.on_edit_item(params.table_element_editor, show_params, id);
      else if (!params.read_only_data && !params.append_only_data)
        PK.navigation.go_to_topic(params.table_element_editor, [id]);
    }
  };

  function deleteItems()
  {
    var id = grid_panel_getter().selModel.selections.keys[0];

    var request_url = PK.make_admin_request_url(
        params.server_handler_name + '/delete'
      );

    var request_params = {id: id};
    if(params.add_request_params)
      params.add_request_params(request_params, show_params);

    // TODO: Must render 'waitMsg' somehow
    Ext.Ajax.request({
      url: request_url,
      method: 'POST',
      params: PK.make_admin_request_params(request_params),

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
            store_.reload();
            if(params.on_successful_delete)
              params.on_successful_delete();
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

  function confirmDelete()
  {
    if(grid_panel_getter().selModel.selections.keys.length > 0)
      Ext.Msg.confirm(
        I18N('Irreversible action'),
        I18N('Are you sure to delete selection?'),
        function(btn) { if(btn == 'yes') { deleteItems(); } }
      );
  };


  function onRowDblClick(grid, rowIndex, e)
  {
    var record = store_.getAt(rowIndex);
    var id = record[params.primaryKey];
    editItem(id);
    //This is an alternative way if the grid allows single selection only
    //editItem();
  };

  var tbar = [];
  if(params.read_only_data)
  {
    tbar = [];
  }
  else if(params.append_only_data || params.prohibit_deletion)
  {
    tbar = [
      {
        text: I18N('Add'),
        tooltip: I18N('Click to add'),
        iconCls:'icon-add',
        handler: addItem
      }
    ];
  }
  else
  {
    tbar = [
      {
        text: I18N('Add'),
        tooltip: I18N('Click to add'),
        iconCls:'icon-add',
        handler: addItem
      }, '-', //add a separator
      {
        text: I18N('Delete'),
        tooltip: I18N('Click to delete'),
        iconCls:'icon-delete',
        handler: confirmDelete
      }
    ];
  }

  var make_button_handler_using_grid_panel_getter = function(handler)
  {
    return function() { return handler(grid_panel_getter()) }
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
          handler:  make_button_handler_using_grid_panel_getter(
              params.custom_tbar[i].handler
            )
        };
        tbar.push(tbar_item);
      }
      else
        tbar.push(params.custom_tbar[i]);
    }
  }


  var grid_panel = PKAdmin.make_grid_panel({
      bbar: tbar,
      per_page: per_page,
      displayMsg: params.displayMsg,
      emptyMsg: params.emptyMsg,
      columns: columns,
      colModel_listeners:
      {
        columnmoved : function(cm, oldIndex, newIndex)
        {
          var column_order = []
          for (var i = 0; i < cm.columns.length; i++)
            column_order.push(cm.columns[i].dataIndex)

          PKAdmin.client_settings.change_table_column_order(params.name, column_order)
        },
        hiddenchange : function(cm, columnIndex, hidden)
        {
          column_name = cm.columns[columnIndex].dataIndex
          PKAdmin.client_settings.set_table_column_visibility(params.name, column_name, hidden)
        }
      },
      gridPanel_listeners:
      {
        columnresize : function(columnIndex, newWidth)
        {
          var cm = grid_panel_getter().colModel
          column_name = cm.columns[columnIndex].dataIndex
          PKAdmin.client_settings.change_table_column_width(params.name, column_name, newWidth)
        }
      },
      filters: grid_filters,
      store: store_
    });

  grid_panel.addListener('rowdblclick', onRowDblClick);

  var filter_panel = PKAdmin.make_filter_panel(filters)

  var panel = new Ext.Panel({
      title: title,
      baseCls: 'x-plain',
      layout: 'auto',
      items:
      [
        {
          height: 5,
          xtype:'spacer',
        },
        filter_panel,
        {
          height: 10,
          xtype:'spacer',
        },
        {
          height: 450,
          layout: 'fit',
          xtype: 'panel',
          baseCls:'x-plain',
          items: grid_panel
        }
      ]
    });

  var main_module = Ext.getCmp('main-module-panel')
  main_module.add(panel)
  main_module.doLayout()

  return panel;
}


//------------------------------------------------------------------------------
//                           TABLE VIEW
//------------------------------------------------------------------------------

// Parameters:
//   title
//   name
//   primaryKey
//   columns
//   displayMsg
//   emptyMsg
//   table_element_editor
//   server_handler_name
// Optional parameters:
//   read_only_data
//   append_only_data
//   prohibit_deletion
//   store_maker
//   remote_sorting_params
//   on_add_item
//   on_edit_item
//   on_successful_delete
//   add_request_params
//   per_page
//   custom_tbar
PKAdmin.make_table_view = function(params)
{
  return new function()
  {
    var panel_;
    var store_;

    var raw_init_ = function(columns, show_params)
    {
      if(typeof(params.title) == "function")
        this.title = params.title(show_params);
      else
        this.title = params.title;

      panel_ = PKAdmin.make_table_view_panel(
        function() // grid panel getter
        {
          if (!panel_ || !panel_.get(3) || !panel_.get(3).get(0))
            return undefined;
          return panel_.get(3).get(0)
        },
        this.title,
        columns,
        params,
        show_params
      );

      LOG("created topic: table_view " + this.title);
    };

    this.init = function(show_params)
    {
      if(typeof(params.columns) == "function")
      {
        params.columns(function(columns) {raw_init_(columns, show_params);});
      }
      else
      {
        raw_init_(params.columns, show_params);
      }
    }

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
