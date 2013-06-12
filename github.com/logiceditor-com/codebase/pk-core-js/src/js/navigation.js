//------------------------------------------------------------------------------
// navigation.js: Common navigation for our topic system
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Note: ExtJS required. Localization for 'Page title prefix' required
//
//------------------------------------------------------------------------------

PK.navigation = new function()
{
  var set_doc_title_ = true

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
    this.topic_makers = {};
  };

  // Run by user interface - just a request
  this.go_to_topic = function(topic, params, must_show_topic)
  {
    var token = (topic)?(topic):("");
    if(must_show_topic === undefined) { must_show_topic = false; };

    if(params && params.length)
    {
      for(var i = 0; i < params.length; i++)
        token += "/" + params[i];
    }

    var prevToken = Ext.History.getToken();

    Ext.History.add(token);

    if(prevToken == token && must_show_topic)
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
      //topic = this.topics["index"];
    }

    last_topic_ = topic;
    topic.show(params);

    if (set_doc_title_)
      document.title =
        I18N('Page title prefix') + (topic.title ? ": " + topic.title : "")
  };

  this.must_set_doc_title = function(state)
  {
    set_doc_title_ = state
  }
};
