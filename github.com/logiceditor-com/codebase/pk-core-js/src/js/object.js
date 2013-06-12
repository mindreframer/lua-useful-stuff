//------------------------------------------------------------------------------
// object.js: Utilities working with objects
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

/**
 * Serialize object.
 * Note: This method has a little use since we have JSON.stringify()
 *
 * @param object
 * @param br
 */
PK.serialize_object = function(object, br)
{
  if (br === undefined) br = "\n";

  if (typeof object == "string")
  {
    return "'" + object + "'";
  }

  var text = "";

  for (var prop in object)
  {
    var value = object[prop];
    var type = typeof value;
    switch (type)
    {
      case "object":
        text += prop + ": "+ "[Object]" + br;
        break;
      default:
        text += prop + ": "+ value + br;
    }
  }

  return text;
}

/**
 * Replace object properties following the rules, return object.
 *
 * @param properties
 * @param rules
 * @param data
 */
PK.override_object_properties = function(properties, rules, data)
{
  if (!rules) return properties;

  if (!properties)
  {
    properties = {};
  }

  for (var name in rules)
  {
    if (rules[name] === true) // just set field using data
    {
      if (data[name] !== undefined)
      {
        properties[name] = data[name];
      }
      else
      {
        CRITICAL_ERROR('No mandatory data for ' + name + '!');
      }
    }

    else if (typeof(rules[name]) == "function") //set and convert field using data
    {
      var value = rules[name](data[name]);
      if(value !== undefined)
      {
        properties[name] = value;
      }
    }

    else if (typeof(rules[name]) == "object") // set field to const
    {
      if (data[name] !== undefined)
      {
        properties[name] = data[name];
      }
      else if (rules[name].default_value !== undefined ) // set default value if necessary
      {
        properties[name] = rules[name].default_value;
      }
    }
  }

  return properties;
}

/**
 * Count object properties.
 *
 * @param obj
 */
PK.count_properties = function(obj)
{
  var length = 0;
  try
  {
    for(var word in obj)
    {
      length++;
    }
  }
  catch(e)
  {
    CRITICAL_ERROR("It is not dictionary! " + obj);
  }

  return length;
}

/**
 * { name1: 1, name2: 2 } => { 1: name1, 2: name2 }
 *
 * @param value_by_name
 */
PK.swap_keys_and_values = function(value_by_name)
{
  var name_by_value = {};
  for (var name in value_by_name)
  {
    name_by_value[value_by_name[name]] = name;
  }
  return name_by_value;
}
