PK.common_custom_editors = new function()
{
  this.make_form_field_string_editor = function()
  {
    return new Ext.form.TextField({
        selectOnFocus: true,
        allowBlank: true,
        style:'text-align:left;'
      });
  };

  this.make_form_field_enum_editor = function(my_enum)
  {
    return new Ext.form.ComboBox({
      typeAhead: true,
      triggerAction: 'all',
      editable: false,
      mode: 'local',
      lazyRender: true, // should always be true for editor
      store: new Ext.data.ArrayStore({
          fields: ['id', 'text'],
          data: my_enum
        }),
      value: my_enum[0][0],
      autoSelect: true,
      displayField: 'text',
      valueField: 'id'
    });
  };

  this.make_form_field_bool_editor = function()
  {
    return this.make_form_field_enum_editor(
        [[0, I18N('no')],
        [1, I18N('yes')]]
      );
  }

  this.make_form_field_number_editor = function()
  {
    return new Ext.form.NumberField({
        selectOnFocus: true,
        allowBlank: true,
        style:'text-align:left;'
      });
  };

  this.make_form_field_money_editor = function()
  {
    return new Ext.form.NumberField({
        selectOnFocus: true,
        allowBlank: true,
        style:'text-align:left;',
        allowDecimals: true,
        allowNegative: false,
    });
  };

  this.make_form_field_date_editor = function()
  {
    return new Ext.form.DateField({
        format: 'd.m.Y',
        selectOnFocus: true
      });
  };

  this.make_form_field_password_editor = function()
  {
    return new Ext.form.TextField({allowBlank: false})
  };


  // ---------------------------------------------------------------------------


  this.make_enum_editor_maker = function(my_enum)
  {
    return function()
    {
      return new Ext.grid.GridEditor(
          PK.common_custom_editors.make_form_field_enum_editor(my_enum)
        );
    };
  };

  this.make_bool_editor =
    this.make_enum_editor_maker([[0, I18N('no')], [1, I18N('yes')]]);

  this.make_number_editor = function()
  {
    return new Ext.grid.GridEditor(
        PK.common_custom_editors.make_form_field_number_editor()
      );
  };

  this.make_money_editor = function()
  {
    return new Ext.grid.GridEditor(
        PK.common_custom_editors.make_form_field_money_editor()
      );
    grid_editor.on(
        'beforecomplete',
        function(this_ge, value, startValue)
        {
          if(value && value != startValue)
          {
            this_ge.setValue(Math.floor(value * 100));
          }
          return true;
        }
      );
    grid_editor.on(
        'beforeshow',
        function(editor)
        {
          if (editor.getValue())
            editor.setValue(editor.getValue()/ 100);
          return true;
        }
      );

    return grid_editor;
  };

  this.make_date_editor = function()
  {
    return new Ext.grid.GridEditor(
        PK.common_custom_editors.make_form_field_date_editor()
      );
  };

  this.make_password_editor = function()
  {
    return new Ext.grid.GridEditor(
        PK.common_custom_editors.make_form_field_password_editor()
      );

    grid_editor.on(
        'beforecomplete',
        function(this_ge, value, startValue)
        {
          if(value && value != startValue && value.length > 0)
          {
            //this_ge.setValue(Ext.util.MD5(value));
            this_ge.setValue(value);
          }
          return true;
        }
      );

    return grid_editor;
  };


  //----------------------------------------------------------------------------


  this.make_form_field_editor = function(value_type, params)
  {
    switch (Number(value_type))
    {
      case PK.table_element_types.STRING:
        return this.make_form_field_string_editor();
        break;

      case PK.table_element_types.INT:
        return this.make_form_field_number_editor();
        break;

      case PK.table_element_types.ENUM:
        if(!params.enum_items)
          return undefined;
        return this.make_form_field_enum_editor(params.enum_items);
        break;

      case PK.table_element_types.BOOL:
        return this.make_form_field_bool_editor();
        break;

      case PK.table_element_types.DATE:
        return this.make_form_field_date_editor();
        break;

      case PK.table_element_types.PHONE:
      case PK.table_element_types.MAIL:
        return this.make_form_field_string_editor();
        break;

      case PK.table_element_types.DB_IDS:
        // TODO: Hack! Value can contain few ids!
        return this.make_form_field_number_editor();
        break;

      case PK.table_element_types.BINARY_DATA:
      case PK.table_element_types.SERIALIZED_LIST:
        return undefined;
        break;

      case PK.table_element_types.MONEY:
        return this.make_form_field_money_editor();
        break;

      default:
        return undefined;
    }
  };


  this.make_editor_maker = function(value_type, params)
  {
    switch (Number(value_type))
    {
      case PK.table_element_types.STRING:
        return undefined;
        break;

      case PK.table_element_types.INT:
        return this.make_number_editor;
        break;

      case PK.table_element_types.ENUM:
        if(!params.enum_items)
          return undefined;
        return this.make_enum_editor_maker(params.enum_items);
        break;

      case PK.table_element_types.BOOL:
        return this.make_bool_editor;
        break;

      case PK.table_element_types.DATE:
        return this.make_date_editor;
        break;

      case PK.table_element_types.PHONE:
      case PK.table_element_types.MAIL:
        return undefined;
        break;

      case PK.table_element_types.DB_IDS:
        // TODO: Hack! Value can contain few ids!
        return this.make_number_editor;
        break;

      case PK.table_element_types.BINARY_DATA:
      case PK.table_element_types.SERIALIZED_LIST:
        return undefined;
        break;

      case PK.table_element_types.MONEY:
        return this.make_money_editor;
        break;

      default:
        return undefined;
    }
  };
};
