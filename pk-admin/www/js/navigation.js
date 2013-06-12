PK.navigation = new function()
{
  var last_topic_;

  this.topic_makers = {};
  this.topics = {};

  this.tokenDelimiter = '/';

  this.add_topic = function(topic_name, topic_maker)
  {
    //LOG("adding topic: " + topic_name);
    this.topic_makers[topic_name] = topic_maker;
  };

  this.make_all_topics = function()
  {
    for (var name in this.topic_makers)
    {
      //LOG("making topic: " + name);
      this.topics[name] = this.topic_makers[name]();
    }
  };

  // Run by user interface - just a request
  this.go_to_topic = function(topic, params, show_topic)
  {
    var token = (topic)?(topic):("");
    if(show_topic === undefined) { show_topic = false; };

    if(params && params.length)
    {
      for(i=0; i<params.length; i++)
        token += "/" + params[i];
    }

    Ext.History.add(token);

    if(show_topic)
      this.show_topic(topic, params);
  };


  // Run by Ext.History - time to change current topic
  this.show_topic = function(topic_name, params)
  {
    LOG("navigator.show_topic(): " + topic_name);

    if(!topic_name) topic_name = "index";

    if(last_topic_)
    {
      last_topic_.hide();
    }

    var topic = this.topics[topic_name];
    if (!topic)
    {
      {
       GUI_ERROR('No topic: ' + topic_name);
        return;
      }
      topic = this.topics["index"];
    }

    last_topic_ = topic;
    topic.show(params);

    document.title = I18N('Page title prefix') + (topic.title ? ": " + topic.title : "");
  };
};
