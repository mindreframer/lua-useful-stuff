PK.object_tag_value_types = PK.table_element_types;

//------------------------------------------------------------------------------


PK.object_tag = new function()
{
  var VALUE_TYPE_DB_ID = 8;
  var MAX_TAG_TYPES_ = 998;

  //----------------------------------------------------------------------------

  var make_tag_serializer_ = function(tag_type_id, value_type)
  {
    return function(value, item)
    {
      switch (Number(value_type))
      {
        case PK.object_tag_value_types.STRING:
        case PK.object_tag_value_types.INT:
        case PK.object_tag_value_types.ENUM:
        case PK.object_tag_value_types.BOOL:
          break;

        case PK.object_tag_value_types.DATE:

          if(!value || value == "")
            return;

          var current_format = undefined;

          // TODO: Bad hack, to be removed ASAP!
          if (typeof(value) == "number")
          {
            value = String(value);
            current_format = "U";
          }

          var dt;
          if (current_format)
            dt = Date.parseDate(value, current_format);
          else
            dt = new Date(value);

          if (dt)
            value = dt.format("U");

          break;

        case PK.object_tag_value_types.PHONE:
        case PK.object_tag_value_types.MAIL:
        case PK.object_tag_value_types.DB_IDS:
        case PK.object_tag_value_types.BINARY_DATA:
          break;

        default:
      }

      if(!item["tags[size]"])
        item["tags[size]"] = 1;
      else
        item["tags[size]"] += 1;

      var index = item["tags[size]"];

      item["tags[" + index + "][type_id]"] = tag_type_id;
      item["tags[" + index + "][value]"] = value;
    };
  };

  var make_tag_convertor_ = function(id, value_type)
  {
    return function(v, record)
    {
      if(record.tags && record.tags.item && record.tags.item[id])
      {
        switch (Number(value_type))
        {
          case PK.object_tag_value_types.STRING:
          case PK.object_tag_value_types.INT:
          case PK.object_tag_value_types.ENUM:
          case PK.object_tag_value_types.BOOL:
            return record.tags.item[id].value;
            break;

          case PK.object_tag_value_types.DATE:

            // TODO: Hackish!
            if(isNaN(record.tags.item[id].value))
              return 0;
            return Number(record.tags.item[id].value);
            //return PK.common_custom_convertors.make_timestamp_convertor("U", false)(
            //    record.tags.item[id].value
            //  );

          case PK.object_tag_value_types.PHONE:
          case PK.object_tag_value_types.MAIL:
          case PK.object_tag_value_types.DB_IDS:
          case PK.object_tag_value_types.BINARY_DATA:
            return record.tags.item[id].value;
            break;

          default:
            return record.tags.item[id].value;
        }
      }
      return "";
    }
  }

  var make_enum_ = function(tag_type_values)
  {
    var values_assoc = new Object;
    for (var i in tag_type_values)
      values_assoc[Number(tag_type_values[i].id)] = tag_type_values[i].name;

    var values = new Array;
    for (var k in values_assoc)
      if(Number(k) > 0)
        values.push([Number(k), values_assoc[k]]);

    return values;
  };

  //----------------------------------------------------------------------------

  var make_tag_type_property_adder_ = function(properties, linked_tables)
  {
    return function(tag_type_record)
    {
      if (tag_type_record.data.value_type == VALUE_TYPE_DB_ID)
      {
        linked_tables[linked_tables.length] =
        {
          name : tag_type_record.data.name,
          tag_type_id : tag_type_record.data.id,
          linked_object_table : tag_type_record.data.linked_object_table,
          linked_tag_type_table : tag_type_record.data.linked_tag_type_table,
          linked_tag_type_id : tag_type_record.data.linked_tag_type_id
        };
      }
      else
      {
        var enum_items = undefined;
        if(tag_type_record.data.values && tag_type_record.data.values.item)
        {
          enum_items = make_enum_(tag_type_record.data.values.item);
        }

        properties['099' + PK.formatNumber(Number(tag_type_record.data.id), 4)] =
        {
          loc_name: tag_type_record.data.name,
          serializer: make_tag_serializer_(
              tag_type_record.data.id,
              tag_type_record.data.value_type
            ),
          defaultValue: '',
          convert: make_tag_convertor_(
              tag_type_record.data.id,
              tag_type_record.data.value_type
            ),
          renderer: PK.common_custom_renderers.make_renderer(
              tag_type_record.data.value_type, true, enum_items
            ),
          editor_maker: PK.common_custom_editors.make_editor_maker(
              tag_type_record.data.value_type, enum_items
          )
        };
      }
    };
  };

  var make_tag_type_column_adder_ = function(columns)
  {
    return function(tag_type_record)
    {
      var tag_id = Number(tag_type_record.data.id);

      var enum_items = undefined;
      if(tag_type_record.data.values && tag_type_record.data.values.item)
      {
        enum_items = make_enum_(tag_type_record.data.values.item);
      }

      columns[2 + tag_id] =
      {
        header: tag_type_record.data.name,
        hidden: false,
        width: 100,
        dataIndex: 'tag_' + PK.formatNumber(tag_id, 4),
        convert: make_tag_convertor_(
            tag_id, tag_type_record.data.value_type
          ),
        renderer: PK.common_custom_renderers.make_renderer(
            tag_type_record.data.value_type, false, enum_items
          ),
      };
    };
  };

  //  Parameters:
  //    field_names
  //    primary_key
  //    request
  //    load_callback_maker
  //    limit
  var load_tag_types_ = function(params)
  {
    var reader_fields = PK.common_stores.make_reader_fields(
        [
          'id', 'name', 'value_type', 'value_type', 'parent_id',
          'linked_object_table', 'linked_tag_type_table', 'linked_tag_type_id'
        ]
      );
    reader_fields[reader_fields.length] = { name : "values" };

    var tag_types = PK.common_stores.make_store_with_custom_fields(
        reader_fields,
        'id',
        params.request,
        undefined,
        false,
        params.load_callback_maker(undefined)
      );

    tag_types.on("load", params.load_callback_maker(tag_types));
    tag_types.load({ params: {start: 0, limit: MAX_TAG_TYPES_} });
  };


  //----------------------------------------------------------------------------

  var load_linked_tables_data_ = function(
      linked_tables,
      objects_request_url_prefix,
      callback
    )
  {
    var linked_tables_data = new Array;

    // TODO: Load all data of all linked tables:
    //        name
    //        columns
    //        assigned_objects_request_url
    //        linked_object_table_request_url

    var current_table = 0;

    if( linked_tables[current_table].linked_object_table === undefined
      || linked_tables[current_table].linked_object_table.length == 0)
    {
      CRITICAL_ERROR(I18N("No linked object table name"));
      callback();
      return;
    }

    var object_list_columns_maker = PK.object_tag.make_object_list_columns_maker(
        linked_tables[current_table].linked_object_table + '/tags/types/list'
      );

    object_list_columns_maker(function(columns)
      {
        linked_tables_data.push({
            name: linked_tables[current_table].name,

            tag_type_id : linked_tables[current_table].tag_type_id,
            linked_tag_type_table: linked_tables[current_table].linked_tag_type_table,
            linked_tag_type_id: linked_tables[current_table].linked_tag_type_id,

            columns: columns,

            assigned_objects_request_url:
              objects_request_url_prefix + '/get_linked_db_ids',
            linked_object_table_request_url:
              linked_tables[current_table].linked_object_table + '/list',

            assign_request_url:
              objects_request_url_prefix + '/assign',
            unassign_request_url:
              objects_request_url_prefix + '/unassign'
          });

        callback(linked_tables_data);
      });
  }

  //----------------------------------------------------------------------------

  this.make_object_properties_maker = function(request_url, objects_request_url_prefix)
  {
    return function(is_existing_element, load_callback)
    {
      properties =
      {
        // Note: 'id' field can't be edited
        '001' : { loc_name: I18N('Name'), mapping: 'name', defaultValue: '' },
        '002' : { loc_name: I18N('Description'), mapping: 'description', defaultValue: '' }
      };

      load_tag_types_({
          request: request_url,
          load_callback_maker: function(store) { return function()
            {
              var linked_tables = new Array;

              if (store)
                store.each(make_tag_type_property_adder_(properties, linked_tables));

              if(!is_existing_element || linked_tables.length == 0)
              {
                load_callback(properties);
              }
              else
              {
                load_linked_tables_data_(
                    linked_tables,
                    objects_request_url_prefix,
                    function(linked_tables_data)
                      {
                        load_callback(
                            properties,
                            linked_tables_data,
                            undefined
                          );
                      }
                  );
              }
            }}
        });
    };
  };

  this.make_object_list_columns_maker = function(request_url)
  {
    return function(load_callback)
    {
      var columns =
      [
        {header: I18N('ID'),          hidden: false, width:  50, dataIndex: 'id', id: 'id'},
        {header: I18N('Name'),        hidden: false, width: 250, dataIndex: 'name'},
        {header: I18N('Description'), hidden: false, width: 250, dataIndex: 'description'}
      ];

      load_tag_types_({
          request: request_url,
          load_callback_maker: function(store) { return function() {
              if (store) store.each(make_tag_type_column_adder_(columns));
              load_callback(columns);
            }}
        });
    };
  };
};

//------------------- make request params --------------------------------------

PK.makeInsertTagTypeValueRequestParams = function(item, show_params)
{
  if(!show_params || show_params.length < 2)
  {
    CRITICAL_ERROR(
        I18N('Can\'t make insert request params: tag type is undefined!')
      );
    return;
  }

  item.tag_type_id = show_params[1];

  return PK.make_admin_request_params(item);
};


//-------------------- make show params & titles -------------------------------

PK.makeTableViewShowParams = function(show_params)
{
  if(!show_params || show_params.length < 3)
  {
    CRITICAL_ERROR(
        I18N('Can\'t make table view show_params: tag type is undefined!')
      );
    return undefined;
  }

  return [show_params[1], show_params[2] ];
};


PK.makeTitleTagTypeValues = function(show_params)
{
  if(!show_params || show_params.length < 2)
  {
    CRITICAL_ERROR(
        I18N('Can\'t make title of tag type value list: tag type is undefined!')
      );
    return I18N('invalid value');
  }

  return I18N("Tag type values") + ' \'' + show_params[1] + '\'';
};


PK.makeTitleExistingTagTypeValue = function(id, show_params)
{
  if(!show_params || show_params.length < 3)
  {
    CRITICAL_ERROR(
        I18N('Can\'t make title of tag type value editor: tag type is undefined!')
      );
    return undefined;
  }

  return I18N("Editing of tag type value") + ' \'' + show_params[2] + '\'';
};


PK.makeTitleNewTagTypeValue = function(show_params)
{
  if(!show_params || show_params.length < 3)
  {
    CRITICAL_ERROR(
        I18N('Can\'t make title of tag type value editor: tag type is undefined!')
      );
    return undefined;
  }

  return I18N("New tag type value") + ' \'' + show_params[2] + '\'';
};


//--------------------- make store of values -----------------------------------

PK.makeTagTypeValueStore = function(reader_fields, server_handler_name, limit, show_params)
{
  if(!show_params || show_params.length == 0)
  {
    CRITICAL_ERROR(
        I18N('Can\'t get tag type values: tag type is undefined!')
      );
    return undefined;
  }

  return PK.common_stores.make_store_with_custom_fields(
    reader_fields, 'id', server_handler_name + '/list',
    {start: 0, limit: limit, tag_type_id: show_params[0]},
    false
  );
};


//--------------------- navigation ---------------------------------------------

PK.openNewTagTypeValueEditing = function(table_element_editor, show_params)
{
  if(!show_params || show_params.length < 2)
  {
    CRITICAL_ERROR(
        I18N('Can\'t start tag type value editing: tag type is undefined!')
      );
    return;
  }

  PK.navigation.go_to_topic(
      table_element_editor,
      ["new", show_params[0], show_params[1]]
    );
};


PK.openExistingTagTypeValueEditing = function(table_element_editor, show_params, id)
{
  if(!show_params || show_params.length < 2)
  {
    CRITICAL_ERROR(
        I18N('Can\'t start tag type value editing: tag type is undefined!')
      );
    return;
  }

  PK.navigation.go_to_topic(
      table_element_editor,
      [id, show_params[0], show_params[1]]
    );
};


PK.makeEditTagTypeValuesHandler = function(
    topic_tag_type_values, tag_value_type_list
  )
{
  return function(panel)
  {
    var id;
    if(panel.selModel.selections.keys.length > 0)
    {
      id = panel.selModel.selections.keys[0];
    }

    if(id === undefined)
    {
      GUI_ERROR(I18N('No selected tag. Must choose appropriative tag first.'));
      return;
    }

    var record = panel.getStore().getById(id);
    if(record && record.data && record.data.value_type ==tag_value_type_list)
    {
      var tagTypeTitle = record.data.name;
      PK.navigation.go_to_topic(topic_tag_type_values, [id, tagTypeTitle]);
    }
    else
    {
      GUI_ERROR(I18N('Tag value type is not a list.'));
    }
  }
};
