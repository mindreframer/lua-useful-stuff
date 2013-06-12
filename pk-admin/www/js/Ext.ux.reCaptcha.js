/**
 * @class Ext.ux.form.Recaptcha
 * @extends Ext.BoxComponent
 * Recaptcha field.
 * @constructor
 * Creates a new Recaptcha field
 * @param {Ext.Element/String/Object} config The configuration options.  If an element is passed, it is set as the internal
 * element and its id used as the component id.  If a string is passed, it is assumed to be the id of an existing element
 * and is used as the component id.  Otherwise, it is assumed to be a standard config object and is applied to the component.
 *
 * More information can be found about reCAPTCHA and lib files at: http://recaptcha.net
 */
Ext.ux.Recaptcha = Ext.extend(Ext.BoxComponent, {
    /**
     * @cfg {String} publickey The key to generate your recaptcha
     */
    /**
     * @cfg {String} theme The name of the theme
     */
    onRender : function(ct, position){
        if(!this.el){
            this.el = document.createElement('div');
            this.el.id = this.getId();
                        Recaptcha.create(this.publickey, this.el, {
                                theme: this.theme
                            ,    lang: this.lang
                            ,    callback: Recaptcha.focus_response_field
                        });
        }
        Ext.ux.Recaptcha.superclass.onRender.call(this, ct, position);
    }
});
Ext.reg('recaptcha', Ext.ux.Recaptcha);