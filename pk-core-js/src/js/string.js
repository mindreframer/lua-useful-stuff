//------------------------------------------------------------------------------
// string.js: String functions
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

/**
 * Prepend value with 0 if length < precision.
 *
 * @param value
 * @param precision
 */
PK.formatNumber = function(value, precision)
{
  value = Number(value);
  if (isNaN(value))
  {
    CRITICAL_ERROR("Wrong value!");
  }

  var parts = value.toString().split('.');
  var int_part = parts[0];
  if (parts.length > 1)
  {
    CRITICAL_ERROR("Can't format not integer number!");
  }

  if (precision === undefined)
  {
    precision = 4;
  }

  precision = Number(precision);
  if (isNaN(precision))
  {
    CRITICAL_ERROR("Wrong precision!");
  }

  if (precision < 1) {
    CRITICAL_ERROR("Can't format with precision < 1!");
  }

  if (int_part.length < precision)
  {
    return new Array(precision - int_part.length + 1).join('0') + int_part;
  }
  else if (int_part.length == precision)
  {
    return value;
  }
  else
  {
    CRITICAL_ERROR("Can't format big number!");
  }
}

/**
 * Inspired by http://javascript.crockford.com/remedial.html
 *
 * @param s
 */
PK.entityify_and_escape_quotes = function (s)
{
  if (typeof(s) == "number")
  {
    return s;
  }
  //PKLILE.timing.start("entityify_and_escape_quotes")
  var result = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  //PKLILE.timing.stop("entityify_and_escape_quotes")
  return result;
}


/**
 * Split using placeholders like '${1}', '${2}' .. '${n}' or '${key}' (from keys).
 *
 * @param source
 * @param keys
 */
PK.split_using_placeholders = function(source, keys)
{
  // Check string is empty
  if (source.length == 0)
  {
    return [];
  }

  // Check string has no placeholders
  if (source.indexOf("${") == -1)
  {
    return [ PK.clone(source) ];
  }

  var pieces = [];
  var need_split_with_prev = false;
  var push_to_pieces = function (item)
  {
    if (item != undefined && item !== "")
    {
      if (item.substr(0, 2) == '${' && item.substr(item.length - 1) == '}')
      {
        var key = item.substr(2, item.length - 3);
        var key_number = Number(key);
        if (!isNaN(key_number))
        {
          if (key_number == key_number.toFixed(0))
          {
            item = key_number;
          }
        }
        else if (keys && keys.length)
        {
          if (!PK.is_value_in_array(keys, key))
          {
            need_split_with_prev = true;
            if (pieces.length)
            {
              pieces[pieces.length - 1] += item;
            }
            else
            {
              pieces.push(item);
            }
            return;
          }
        }
      }
      else if (need_split_with_prev)
      {
        if (pieces.length)
        {
          pieces[pieces.length - 1] += item;
        }
        else
        {
          pieces.push(item);
        }
        need_split_with_prev = false;
        return;
      }
      pieces.push(item);
    }
  }
  var pos_from = 0;
  var pos_to = 0;
  var pos = 0;
  while (pos != -1)
  {
    pos_from = source.indexOf("${", pos);
    if (pos_from != -1)
    {
      push_to_pieces(source.substr(pos, pos_from - pos));
      pos_to = source.indexOf("}", pos_from + 2);
      if (pos_to != -1)
      {
        push_to_pieces(source.substr(pos_from, pos_to - pos_from + 1));
        pos = pos_to + 1;
      }
      else
      {
        push_to_pieces(source.substr(pos_from));
        pos = -1;
      }
    }
    else
    {
      push_to_pieces(source.substr(pos));
      pos = -1;
    }
  }
  return pieces;
}


/**
 * Fill placeholders with values.
 *
 * @param source
 * @param ivalues Array
 * @param values Object
 */
PK.fill_placeholders = function(source, ivalues, values)
{
  // Check string has no placeholders
  if (source.indexOf("${") == -1)
  {
    return PK.clone(source);
  }

  // Return clone of source if no ivalues and values
  if ( (!ivalues || ivalues.length == 0) && (!values || values.length == 0) )
  {
    return PK.clone(source);
  }

  // Do simple replace if one ivalue and no values
  if ( (ivalues && ivalues.length == 1) && (!values || values.length == 0) )
  {
    return source.replace('${1}', ivalues[0]);
  }

  var keys = undefined;
  var placeholders_values = undefined;
  if (values)
  {
    keys = [];
    placeholders_values = {};
    for (var key in values)
    {
      keys.push(key);
      placeholders_values["${"+key+"}"] = values[key];
    }
  }
  var pieces = PK.split_using_placeholders(source, keys);
  var result = [];
  for (var n = 0; n < pieces.length; n++) {
    var item = pieces[n];
    if (placeholders_values)
    {
      if (placeholders_values[item])
      {
        item = placeholders_values[item];
        result.push(item);
        continue;
      }
    }
    if (typeof(item) == 'number' && ivalues)
    {
      var num = item - 1;
      if (ivalues.length > num)
      {
        item = ivalues[num];
        result.push(item);
        continue;
      }
      else
      {
        CRITICAL_ERROR(
          "Too big value placeholder number: " + ivalues.length + '<=' + num
        );
        if (window.console && console.log)
        {
          console.log("[PK.fill_placeholders] failed on data:", source, ivalues, pieces);
        }

        LOG("source: " + source);
        LOG("ivalues: " + JSON.stringify(ivalues, null, 4));
        LOG("Data: " + JSON.stringify(pieces, null, 4));
      }
    }
    result.push(item);
  }
  return result.join('');
}

/**
 * PK.formatString("some ${1} text ${2}", var_1, var_2) will replace ${1} by var_1 and ${2} by var_2 and etc.
 */
PK.formatString = function()
{
  if (arguments.length < 1)
  {
    return undefined;
  }

  var ivalues = Array.prototype.slice.call(arguments);
  var text = ivalues.shift();
  text = PK.fill_placeholders(text, ivalues);

  return text;
}


//-----------------------------------------------------------------------------
// OBSOLETE IMPLEMENTATIONS - Only for benchmarking!
//-----------------------------------------------------------------------------

PK.check_namespace('Obsolete');

PK.Obsolete.split_using_placeholders_very_old = function(s, keys)
{
  var SEPARATOR = '{%_SEP_%}'

  var num_placehoders = 0, placeholder_found = true

  while (true)
  {
    num_placehoders++
    var placeholder = '${' + num_placehoders + '}'
    if( s.indexOf(placeholder) < 0 )
      break
    s = s.replace(placeholder, SEPARATOR + placeholder + SEPARATOR)
  }
  num_placehoders--

  if(keys)
   {
     for (var i = 0; i < keys.length; i++)
     {
      var placeholder = '${' + keys[i] + '}'
      if( s.indexOf(placeholder) >= 0 )
      {
        s = s.replace(placeholder, SEPARATOR + placeholder + SEPARATOR)
      }
     }
   }

  var splitted = s.split(SEPARATOR)

  var result = []
  for(var i = 0; i < splitted.length; i++)
   {
    if (splitted[i].match(/\$\{\d+\}/g))
    {
      result.push(Number(splitted[i].replace(/[\$\{\}]/g, "")))
    }
    else if (splitted[i] != "")
     {
      result.push(splitted[i])
     }

   }

  return result
}

 /**
 * Split using placeholders like '${1}', '${2}' .. '${n}' or '${key}' (from keys).
 *
 * @param source
 * @param keys
 */
PK.Obsolete.split_using_placeholders_old = function(source, keys)
{
  var result = [];
  var pattern = '(\\$\\{[0-9]+\\})';
  if (keys && keys.length)
  {
    for (var i = 0; i < keys.length; i++)
    {
      pattern += '|(\\$\\{'+keys[i]+'\\})';
    }

  }
  var pieces = source.split(new RegExp(pattern));
  for (var n = 0; n < pieces.length; n++)
  {
    if (pieces[n] != undefined && pieces[n] !== "")
    {
      var item = pieces[n];
      if (item.substr(0, 2) == '${' && item.substr(item.length - 1) == '}')
      {
        var key = item.substr(2, item.length - 3);
        var key_number = Number(key);
        if (!isNaN(key_number))
        {
          if (key_number == key_number.toFixed(0))
          {
            item = key_number;
          }
        }
      }
      result.push(item);
    }
  }
  return result;
}


//-----------------------------------------------------------------------------

PK.Obsolete.fill_placeholders_very_old = function(s, ivalues)
{
  var keys = undefined, values = undefined
  var data_with_ph = PK.Obsolete.split_using_placeholders_very_old(s, keys)
  if (!data_with_ph)
    return s

  //PKLILE.timing.start("fill_placeholders")

  var result = []

  for(var i = 0; i < data_with_ph.length; i++)
   {
    if (typeof(data_with_ph[i]) == "number")
     {
      var num = data_with_ph[i] - 1
       if (ivalues.length > num)
       {
        result = result.concat(ivalues[num])
       }
       else
       {
         CRITICAL_ERROR(
            "Too big value placeholder number: " + ivalues.length + '<=' + num
          )
         if(window.console && console.log)
         {
          console.log("[PK.fill_placeholders] failed on data:", s, ivalues, data_with_ph)
         }

        LOG("s: " + s)
        LOG("ivalues: " + JSON.stringify(ivalues, null, 4))
        LOG("Data: " + JSON.stringify(data_with_ph, null, 4))
       }
     }
    else if (values && values[data_with_ph[i]] !== undefined)
    {
      result.push(values[data_with_ph[i]])
    }
    else
    {
      result.push(data_with_ph[i])
    }
   }

  var out = result.join('')
  //PKLILE.timing.stop("fill_placeholders")
  return out
}


/**
 * Fill placeholders with values.
 *
 * @param source
 * @param ivalues Array
 * @param values Object
 */
PK.Obsolete.fill_placeholders_old = function(source, ivalues, values)
{
  var keys = undefined;
  var placeholders_values = undefined;
  if (values)
  {
    keys = [];
    placeholders_values = {};
    for (var key in values)
    {
      keys.push(key);
      placeholders_values["${"+key+"}"] = values[key];
    }
  }
  var pieces = PK.Obsolete.split_using_placeholders_old(source, keys);
  var result = [];
  for (var n = 0; n < pieces.length; n++) {
    var item = pieces[n];
    if (placeholders_values)
    {
      if (placeholders_values[item])
      {
        item = placeholders_values[item];
        result.push(item);
        continue;
      }
    }
    if (typeof(item) == 'number' && ivalues)
    {
      var num = item - 1;
      if (ivalues.length > num)
      {
        item = ivalues[num];
        result.push(item);
        continue;
      }
      else
      {
        CRITICAL_ERROR(
          "Too big value placeholder number: " + ivalues.length + '<=' + num
        );
        if (window.console && console.log)
        {
          console.log("[PK.fill_placeholders] failed on data:", source, ivalues, pieces);
        }

        LOG("source: " + source);
        LOG("ivalues: " + JSON.stringify(ivalues, null, 4));
        LOG("Data: " + JSON.stringify(pieces, null, 4));
      }
    }
    result.push(item);
  }
  return result.join('');
}
