//------------------------------------------------------------------------------
// log_system.js: Simple logging / error output system
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.log_system = new function()
{
  var default_gui_msg_printer_ = function(text, stack_trace)
  {
    text += "\n" + PK.Error.format_stack_trace(stack_trace);
    if (window.Ext)
    {
      if (Ext.isReady)
      {
        Ext.Msg.alert('Failure', text);
      }
    }
    else
    {
      alert(text);
    }
  }

  // ------------------ private --------------------------

  var events_ = new Array();

  var printer_ = default_gui_msg_printer_;

  // ------------------ public --------------------------

  this.GUI_EOL = "<br>"

  this.set_printer = function(printer)
  {
    printer_ = printer;
  }

  this.get_printer = function()
  {
    return printer_;
  }

  this.add = function(event)
  {
    events_[events_.length] = event;
  }

  this.list = function()
  {
    return events_;
  }
}

var LOG = PK.log_system.add

var GUI_ERROR = function(text)
{
  if (window.Ext)
  {
    if (Ext.isReady)
    {
      Ext.Msg.alert('Failure', text);
    }
    else
    {
      LOG('GUI ERROR: ' + text);
    }
  }
  else
  {
    var printer = PK.log_system.get_printer();
    if (printer) printer(text);
  }
}

/**
* Exception for critical errors.
*
* @param text
*/
PK.CriticalError = function (text)
{
  this.name = 'CRITICAL ERROR';
  this.message = text;

  this.stack = (new Error()).stack;
}
PK.CriticalError.prototype = Error.prototype;

/**
 * Error handler
 */
PK.Error = new function ()
{
  var instance_ = this;

  var handle_error_calls_ = 0;

  /**
   * Callback
   */
  var custom_error_handler_ = undefined;

  /**
   * Callback
   */
  var custom_error_text_wrapper_ = false;

  var log_error_ = function (error)
  {
    LOG(error.message);
    if (error.stack_trace)
    {
      LOG(error.stack_trace);
    }

    // Note: Don't use log_system's printer here - it's just for GUI_ERROR
    //var printer = PK.log_system.get_printer();
    //if (printer)
    //{
    //  printer(error.message, PK.clone(error.stack_trace));
    //}
  }

  var format_date_time_ = function ()
  {
    var now = new Date(PK.Time.get_current_timestamp());
    var cur_date = now.getDate() + '-' + (now.getMonth() + 1) + '-' + now.getFullYear();
    return '[' + cur_date + ' ' + now.toLocaleTimeString() + '] ';
  }


  /**
   * Returns stack trace if printStackTrace function available
   *
   * @param error Error object
   */
  var get_stack_trace_ = function (error)
  {
    if (window.printStackTrace)
    {
      var stack_lines = error ? window.printStackTrace({ e: error }) : window.printStackTrace();

      // Remove lines caused by call of printStackTrace(), get_stack_trace_()
      if (!error) stack_lines.splice(0, 4);

      return stack_lines;
    }
    else
    {
      return undefined;
    }
  }


  /**
   * Returns changed error
   *
   * @param error Error object
   * @param name string
   */
  var fix_error_message_and_add_stacktrace_ = function (error, name)
  {
    error.stack_trace = get_stack_trace_(error);

    if (custom_error_text_wrapper_)
    {
      error.message = custom_error_text_wrapper_(error.message);
    }

    if (name)
    {
      // TODO: Localize
      error.message = "[" + name + "]\n" + error.message;
    }

    error.message = format_date_time_() + error.message;

    return error
  }


  /**
   * Prevents recursive calling of critical_error
   */
  var critical_error_raised_ = false;

  //----------------------------------------------------------------------------
  // PUBLIC
  //----------------------------------------------------------------------------

  /**
   * Overrides window.onerror
   */
  this.override_window_onerror_callback = function()
  {
    window.onerror = this.on_unhandled_error;
  }


  /**
   * Raises critical error
   *
   * @param text string
   */
  this.critical_error = function (text)
  {
    if (critical_error_raised_)
    {
      LOG("\nRECURSIVE CRITICAL ERROR: " + text);
      return;
    }
    critical_error_raised_ = true;

    if (handle_error_calls_ > 0)
    {
      throw new PK.CriticalError(text);
    }
    else
    {
      instance_.handle_error (
          function() { throw new PK.CriticalError(text); },
          "Dangling error"
        );
    }
  }

  this.handle_error = function (callback, name)
  {
    handle_error_calls_++;
    try
    {
      callback();
    }
    catch (error)
    {
      // We've catched the error
      critical_error_raised_ = false;

      error = fix_error_message_and_add_stacktrace_(error, name)

      log_error_(error);

      if (custom_error_handler_)
      {
        custom_error_handler_(error);
      }
      else
      {
        throw error;
      }
    }
    handle_error_calls_--;
  }

  this.on_unhandled_error = function (message, file, line)
  {
    var full_message = message + " in file '" + file + "' at line " + line;

    if (custom_error_handler_)
    {
      var error = new Error(full_message);
      error = fix_error_message_and_add_stacktrace_(error, "Unhandled error")

      log_error_(error);

      custom_error_handler_(error);
      return true;
    }
    else
    {
      return false;
    }
  }

  /**
   * Set function to error handling process
   * callback = function (error) { ... }
   */
  this.set_custom_error_handler = function (callback)
  {
    custom_error_handler_= callback;
  }

  /**
   * Set function to add custom text to error message
   * callback = function (text) { ... return text }
   */
  this.set_custom_error_text_wrapper = function (callback)
  {
    custom_error_text_wrapper_= callback;
  }

  /**
   * Default stack trace format
   * @param stack_trace
   */
  this.format_stack_trace = function (stack_trace)
  {
    if (stack_trace)
    {
      var trace = PK.clone(stack_trace);
      trace.unshift("********** Stack Trace **********");
      trace.push("**********************************");
      return trace.join("\n");
    }
    else
    {
      return "(Stack trace not available)\n";
    }
  }
}

var CRITICAL_ERROR = PK.Error.critical_error;

PK.Error.override_window_onerror_callback()
