PK.common_custom_convertors = new function()
{
  this.make_timestamp_convertor = function(format, print_time)
  {
    return function(v)
    {
      if(v == "")
        return I18N('not defined');

      var dt;
      if (format)
        dt = Date.parseDate(v, format);
      else
        dt = new Date(v);
      if (!dt)
        return "-";

      var res;
      if(!print_time)
        res = dt.format("d.m.Y");
      else
        res = dt.format("Y-m-d H:i:sO");

      return res;
    }
  };

  this.number_convertor = function(v)
  {
    return Number(v);
  }

  this.make_convertor = function(value_type)
  {
    return function(v)
    {
      switch (Number(value_type))
      {
        case PK.object_tag_value_types.STRING:
          return v;
          break;

        case PK.object_tag_value_types.INT:
          return Number(v);
          break;

        case PK.object_tag_value_types.ENUM:
        case PK.object_tag_value_types.BOOL:
          return v;
          break;

        case PK.object_tag_value_types.DATE:

          // TODO: Hackish!
          if(isNaN(v))
            return 0;
          return Number(v);
          //return PK.common_custom_convertors.make_timestamp_convertor("U", false)(
          //    v
          //  );

        case PK.object_tag_value_types.PHONE:
        case PK.object_tag_value_types.MAIL:
          return v;
          break;

        case PK.object_tag_value_types.DB_IDS:
          // TODO: Hack! v can contain few ids!
          return Number(v);
          break;

        case PK.object_tag_value_types.BINARY_DATA:
          return v;
          break;

        case PK.object_tag_value_types.MONEY:
          return parseFloat(v);
          break;

        default:
          return v;
      }
    }
  }

}
