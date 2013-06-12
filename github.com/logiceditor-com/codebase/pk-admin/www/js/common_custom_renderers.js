PK.common_custom_renderers = new function()
{
  this.render_binary_data = function (v)
  {
    return I18N('binary data');
  }

  this.make_serialized_list_render = function(topic, name)
  {
    return function (value, metaData, record, rowIndex, colIndex, store)
    {
      if (!topic)
        return I18N('binary data')

      var text = I18N('Edit ' + name)

      return '<a href="' + '#' + topic + '/' + record.id + '">'
        + text
        + '</a>'
    }
  }

  this.make_enum_renderer = function(my_enum)
  {
    return function(v)
    {
      if( v === "")
        return I18N('not defined');

      for(i = 0; i < my_enum.length; i++)
      {
        var data = my_enum[i];
        if( data[0] == v )
          return data[1];
      }

      return I18N('invalid field value');
    }
  };

  this.render_bool = this.make_enum_renderer([[0, I18N('no')], [1, I18N('yes')]]);

  this.make_timestamp_renderer = function(format, print_time)
  {
    return function(v)
    {
      if(v == "")
        return I18N("not defined");

      if(v == "-" || v == 0 || v == "0")
        return I18N('invalid field value');

      var current_format = format;

      // TODO: Bad hack, to be removed ASAP!
      if (typeof(v) == "number")
      {
        v = String(v);
        current_format = "U";
      }

      var dt;
      if (current_format)
        dt = Date.parseDate(v, current_format);
      else
        dt = new Date(v);
      if (!dt)
        return I18N('invalid field value');

      if(!print_time)
        return dt.format("d.m.Y");

      return dt.format("Y-m-d H:i:sO");
    }
  };

  this.make_money_renderer = function(suffix_in)
  {
    var suffix = suffix_in ? suffix_in : 'rub'
    return function(v)
    {
      return (Number(v) / 100) + " " + I18N(suffix);
    }
  };

  this.make_real_renderer = function(precision)
  {
    return function(v)
    {
      if (precision == undefined)
        return v;
      return String(Math.round(Number(100 * v) / precision) * precision)
    }
  };

  // Optional parameters:
  //   enum_items
  //   precision
  this.make_renderer = function(value_type, params)
  {
    switch (Number(value_type))
    {
      case PK.table_element_types.STRING:
        return undefined;
        break;

      case PK.table_element_types.INT:
        if (!params.precision)
          return undefined;
        return this.make_real_renderer(params.precision);
        break;

      case PK.table_element_types.ENUM:
        if(!params.enum_items)
          return undefined;
        return this.make_enum_renderer(params.enum_items);
        break;

      case PK.table_element_types.BOOL:
        return this.render_bool;
        break;

      case PK.table_element_types.DATE:
        return this.make_timestamp_renderer(undefined, params.print_time);
        break;

      case PK.table_element_types.PHONE:
      case PK.table_element_types.MAIL:
      case PK.table_element_types.DB_IDS:
        return undefined;
        break;

      case PK.table_element_types.BINARY_DATA:
        return this.render_binary_data;
        break;

      case PK.table_element_types.SERIALIZED_LIST:
        return this.make_serialized_list_render(params.serialized_list_view_topic, params.serialized_list_name);
        break;

      case PK.table_element_types.MONEY:
        return this.make_money_renderer(params.suffix);
        break;

      default:
        return undefined;
    }
  };
};
