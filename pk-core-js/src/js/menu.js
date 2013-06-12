//------------------------------------------------------------------------------
// menu.js: Menu tooltips
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Note: ExtJS required
// Inspired by http://www.manfbraun.de/cont/tech/probs/ExtMenuWithTooltip2e.js
//
//------------------------------------------------------------------------------

PK.override_menu_item_to_enable_tooltips = function()
{
  var DISMISS_DELAY_FOR_MENU_ITEM_TOOLTIP = 0

  Ext.override(Ext.menu.Item, {
    onRender: function(container, position)
      {
        if (!this.itemTpl)
        {
          this.itemTpl = Ext.menu.Item.prototype.itemTpl = new Ext.XTemplate
          (
            '<a id="{id}" class="{cls}" hidefocus="true" unselectable="on" href="{href}"',
            '<tpl if="hrefTarget">',
            ' target="{hrefTarget}"',
            '</tpl>',
            '>',
            '<img src="{icon}" class="x-menu-item-icon {iconCls}"/>',
            '<span class="x-menu-item-text">{text}</span>',
            '</a>'
          );
        }
        var a = this.getTemplateArgs();
        this.el = position ? this.itemTpl.insertBefore(position, a, true) : this.itemTpl.append(container, a, true);
        this.iconEl = this.el.child('img.x-menu-item-icon');
        this.textEl = this.el.child('.x-menu-item-text');
        if (this.tooltip)
        {
          // Note: constrainPosition is not documented
          this.tooltip = new Ext.ToolTip(Ext.apply({
                target: this.el,
                constrainPosition: true,
                dismissDelay: DISMISS_DELAY_FOR_MENU_ITEM_TOOLTIP
                }, Ext.isObject(this.tooltip) ? this.tooltip : { html: this.tooltip } ));
        }
        Ext.menu.Item.superclass.onRender.call(this, container, position);
      },
    getTemplateArgs: function()
        {
          var result = {
              id: this.id,
              cls: this.itemCls + (this.menu ?  ' x-menu-item-arrow' : '') + (this.cls ?  ' ' + this.cls : ''),
              href: this.href || '#',
              tooltip: this.tooltip,
              hrefTarget: this.hrefTarget,
              icon: this.icon || Ext.BLANK_IMAGE_URL,
              iconCls: this.iconCls || '',
              text: this.itemText || this.text || ' '
              };
          return result;
        }
  })
}
