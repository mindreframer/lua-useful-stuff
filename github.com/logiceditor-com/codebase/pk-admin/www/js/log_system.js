PK.log_system = new function()
{
  var events = new Array();

  // TODO: Can be uncommented - only for debug!
  //this.events = events;

  this.add = function(event)
  {
    events[events.length] = event;
  };

  this.list = function()
  {
    return events;
  };
};

//var LOG = function(event) {};
var LOG = PK.log_system.add;

var GUI_ERROR = function(text)
{
  Ext.Msg.alert(I18N('Failure'), text);
}

var CRITICAL_ERROR = function(text)
{
  LOG(text);
  Ext.Msg.alert(I18N('Failure'), text);
}
