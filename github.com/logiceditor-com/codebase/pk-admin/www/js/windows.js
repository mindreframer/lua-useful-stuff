PK.Windows = new function() {
  this.SetPassword = function(handler)
  {
    var onOk = function()
    {
      var value1 = window_.get(0).getValue()
      var value2 = window_.get(1).getValue()
      if (value1 == "" || value1 != value2)
        return

      window_.hide()
      handler(value1)
    }

    var window_ = new Ext.Window({
      title: I18N('Set password window'),
      width: 270,
      height:130,
      resizable: false,
      layout: 'form',
      plain: true,
      style:'border: 5px;',
      bodyStyle:'padding: 5px;',
      buttonAlign:'center',
      modal: true,
      labelWidth: 90,

      items: [
        {
          xtype: 'textfield',
          fieldLabel: I18N('New password'),
          value: '',
          inputType: 'password',
          allowBlank: false
        },
        {
          xtype: 'textfield',
          fieldLabel: I18N('Verify'),
          value: '',
          inputType: 'password',
          allowBlank: false
        }
      ],

      keys: { key: [13], fn: onOk },

      buttons: [
        {
          text: 'OK',
          handler: onOk
        },
        {
          text: 'Cancel',
          handler: function() { window_.hide(); }
        }
      ]
    })

    window_.show()
    window_.getComponent(0).focus(true, true)
  }
}
