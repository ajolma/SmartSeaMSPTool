/*
Copyright (c) 2016, Finnish Environment Institute SYKE All rights
reserved.

Redistribution and use, with or without modification, are permitted
provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

Neither the name of the Finnish Environment Institute (SYKE) nor the
names of its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE FINNISH
ENVIRONMENT INSTITUTE (SYKE) BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.
*/

'use strict';
/*global $, alert*/

function element(tag, attrs, text) {
    var a = '', key;
    if (attrs) {
        for (key in attrs) {
            if (attrs.hasOwnProperty(key)) {
                a += ' ' + key + '="' + attrs[key] + '"';
            }
        }
    }
    if (text) {
        if (text === 'Ø') { // empty element
            return '<' + tag + a + '>';
        }
        return '<' + tag + a + '>' + text + '</' + tag + '>';
    }
    return '<' + tag + a + '/>';
}

/**
 * Options for creating a widget.
 * @typedef {Object} WidgetOptions
 * @property {string} container - The selector of the parent element.
 * @property {string} id - The id of this widget element.
 * @property {string=} slider_value_id - The id for the slider
 * value. Needed if there are more than one slider in the same parent.
 * @property {string} type - The type of the widget. Possible values
 * are: paragraph, text, checkbox, select, checkbox-list, spinner,
 * slider
 * @property {string=} pretext - Text to prepend to the html before the
 * actual element.
 * @property {string=} label - Label for an input widget.
 * @property {boolean|number|string|Object=} selected - For selection
 * type widgets, the selected. Boolean for select true/false
 * widget. The list item or item.name for select-one widgets. Hash
 * keyed with ids for select-multiple type widgets.
 * @property {number|string=} value - The initial value of the text
 * input or the numeric value of widgets for selecting a numeric
 * value.
 * @property {function=} newValue - Function to be called when user
 * has adjusted the value.
 * @property {number|string=} min - The lower bound for value for
 * widgets for selecting a numeric value.
 * @property {number|string=} max - The upper bound for value for
 * widgets for selecting a numeric value.
 * @property {Array|Object=} list - The list of selectables for
 * select-from-multiple-values type widgets.
 * @property {function=} includeItem - Function to be called for
 * querying whether a list item is to be included in the selectables.
 * @property {function=} nameForItem - Function to be called to obtain
 * a visible name for an item.
 */

/**
 * An HTML element, mainly for user input.
 * @constructor
 * @param {WidgetOptions} options - Options.
 */
function Widget(args) {
    var self = this,
        pretext = args.pretext || '',
        attr = {id: args.id},
        tag,
        html = '';

    self.type = args.type;
    self.container = args.container;
    self.id = args.id;
    self.selector = self.container + ' #' + args.id;
    self.selected = args.selected;
    self.value = args.value;

    self.newValue = args.newValue;

    if (self.type === 'checkbox' || self.type === 'text') {
        tag = 'input';
        attr.type = self.type;
    } else if (self.type === 'select') {
        tag = 'select';
    } else if (self.type === 'checkbox-list') {
        tag = 'div';
        attr.style = 'overflow-y:scroll; max-height:350px; background-color:#c7ecfe;';
    } else if (self.type === 'paragraph') {
        tag = 'p';
    } else if (self.type === 'spinner') {
        tag = 'input';
    } else if (self.type === 'radio-group') {
        tag = 'p';
    }
    if (args.list) {
        // key => scalar, or key => object
        self.list = args.list;
        $.each(self.list, function (key, item) {
            var a = '', tag2, attr2, name, x = '';
            if (args.includeItem && !args.includeItem(item)) {
                return true;
            }
            if (args.nameForItem) {
                name = args.nameForItem(item);
            } else if (typeof item === 'object') {
                name = item.name;
            } else {
                name = item;
            }
            if (self.type === 'select') {
                tag2 = 'option';
                attr2 = {value: key};
                if (typeof item === 'object') {
                    if (typeof self.selected === 'object') {
                        if (self.selected === item) {
                            attr2.selected = 'selected';
                        }
                    } else if (self.selected === item.name) {
                        attr2.selected = 'selected';
                    }
                } else {
                    if (self.selected === item) {
                        attr2.selected = 'selected';
                    }
                }
            } else if (self.type === 'checkbox-list') {
                tag2 = 'input';
                name = element('a', {id: 'item', item: item.id}, name);
                attr2 = {type: 'checkbox', item: item.id};
                if (self.selected && self.selected[item.id]) {
                    // selected is a hash keyed with ids
                    attr2.checked = 'checked';
                }
                x = element('br');
            } else if (self.type === 'radio-group') {
                attr2 = {type: 'radio', name: 'radio-' + self.id, id: item.id};
                if (self.selected === item.id) {
                    attr2.checked = 'checked';
                }
                a = element('input', attr2);
                tag2 = 'label';
                attr2 = {for: self.id + '-' + key};
                x = element('br');
            }
            html += a + element(tag2, attr2, name) + x;
        });
    }
    if (self.type === 'radio-group') {
        html = element('fieldset', {}, element('legend', {}, pretext) + html);
        pretext = '';
        self.selector = self.container + ' input[name=\'radio-' + self.id + '\']';
    }
    if (self.type === 'slider') {
        self.min = parseFloat(args.min);
        self.max = parseFloat(args.max);
        self.value = parseFloat(self.value);
        html = element('p', {}, element('div', attr));
        if (!args.slider_value_id) {
            args.slider_value_id = 'slider-value';
        }
        html += element('input', {id: args.slider_value_id, type: 'text'}, '');
        self.value_selector = self.container + ' #' + args.slider_value_id;
    } else if (tag === 'input') {
        if (self.type === 'checkbox' && self.selected) {
            attr.checked = 'checked';
        } else if (self.type === 'text' && self.value) {
            attr.value = self.value;
        }
        html = element(tag, attr, 'Ø');
        if (args.label) {
            html += element('label', {for: self.id}, args.label);
        }
    } else {
        if (!(tag === 'select' && html === '')) {
            html = element(tag, attr, html);
        }
    }
    self.my_html = pretext + html;
}

Widget.prototype = {
    /**
     * Prepare the element for display.
     * @example
     * widget = new Widget(options);
     * parent.html(widget.html());
     * widget.prepare();
     */
    prepare: function () {
        var self = this,
            slider;
        if (self.type === 'select') {
            if (self.newValue) {
                $(self.selector).change(function () {
                    self.newValue(self.getValue());
                });
            }
        } else if (self.type === 'spinner') {
            $(self.selector)
                .spinner({
                    min: self.min,
                    max: self.max
                })
                .spinner('value', self.value);
        } else if (self.type === 'slider') {
            slider = $(self.selector).slider({
                min: self.min,
                max: self.max,
                step: 0.1,
                value: self.value,
                change: function () {
                    self.value = slider.slider('value');
                    $(self.value_selector).val(self.value);
                    if (self.newValue) {
                        self.newValue(self.value);
                    }
                },
                slide: function () {
                    self.value = slider.slider('value');
                    $(self.value_selector).val(self.value);
                    if (self.newValue) {
                        self.newValue(self.value);
                    }
                }
            });
            $(self.value_selector).val(self.value);
            $(self.value_selector).change(function () {
                self.value = $(self.value_selector).val();
                slider.slider('value', self.value);
            });
        }
    },
    /**
     * Get or set the HTML of this widget.
     */
    html: function (html) {
        var self = this;
        if (!(html === null || html === undefined)) {
            $(self.selector).html(html);
            self.my_html = html;
        }
        return self.my_html;
    },
    /**
     * Set the value of this widget.
     * @param {boolean|number|string} value
     */
    setValue: function (value) {
        var self = this;
        if (self.type === 'select') {
            $(self.selector).val(value);
        } else if (self.type === 'slider') {
            self.value = parseFloat(value);
            if (self.value < self.min) {
                self.value = self.min;
            } else if (self.value > self.max) {
                self.value = self.max;
            }
            $(self.selector).slider('value', self.value);
        } else if (self.type === 'checkbox') {
            $(self.selector)[0].checked = value;
        }
    },
    /**
     * Get the value of this widget.
     */
    getValue: function () {
        var self = this;
        if (self.type === 'spinner') {
            return $(self.selector).spinner('value');
        }
        if (self.type === 'slider') {
            return self.value;
        }
        if (self.type === 'checkbox') {
            return $(self.selector).prop('checked');
        }
        return $(self.selector).val();
    },
    getFloatValue: function () {
        var self = this,
            value = self.getValue();
        if (typeof value === 'string') {
            value = parseFloat(value);
        }
        return value;
    },
    /**
     * Get the selected item.
     */
    getSelected: function () {
        var self = this, id;
        if (self.type === 'paragraph') {
            return undefined;
        }
        if (self.type === 'radio-group') {
            id = parseInt($(self.selector + ':checked')[0].getAttribute('id'), 10);
            return self.list.find(function (item) {
                return item.id === id;
            });
        }
        return self.list[self.getValue()]; // key as string
    },
    /**
     * Get the ids of the selected items in a existence hash.
     */
    getSelectedIds: function () {
        var self = this,
            ids = {};
        if (self.type === 'checkbox-list') {
            $.each($(self.container + ' :checkbox'), function (i, item) {
                if (item.checked) {
                    ids[item.getAttribute('item')] = 1;
                }
            });
        }
        return ids;
    },
    /**
     * Set a listener for changes in this widget.
     * @example
     * widget = new Widget({
     *     ...
     *     list: list,
     *     ...
     * });
     * parent.html(widget.html());
     * widget.changed((function changed() {
     *     ... do something because the user has changed the selected
     *     item in the widget or the widget was just shown ...
     *     return changed;
     * }()));
     */
    changed: function (fct) {
        var self = this;
        $(self.selector).change(fct);
    }
};

function Menu(args) {
    var self = this,
        options = '',
        itemDiv = function (item) {
            var html = element('div', {}, item.label),
                li = '';
            if (item.submenu) {
                $.each(item.submenu, function (i, entry) {
                    if (entry.submenu) {
                        li += element('li', {}, itemDiv(entry));
                    } else {
                        li += element('li', {}, element('div', {tag: entry.cmd}, entry.label));
                    }
                });
                html += element('ul', {}, li);
            }
            return html;
        };
    self.menu = $(args.menu),
    self.handler = function (event) {
        if (args.prelude) {
            args.prelude();
        }
        self.menu.css('position', 'absolute');
        self.menu.css('top', event.pageY);
        if (args.right) {
            self.menu.css('right', args.right);
        } else {
            self.menu.css('left', event.pageX);
        }

        self.menu.menu({
            position: { my: 'right top' }
        });
        
        $('.menu').hide(); // close all other menus
        self.menu.show();
        return false;
    };
    $.each(args.options, function (i, item) {
        var attr = item.submenu ? {} : {tag: item.cmd};
        options += element('li', attr, itemDiv(item));
    });
    self.menu.html(options);
    self.menu.menu({
        select: function (event, ui) {
            var cmd = ui.item.attr('tag');
            self.menu.hide();
            args.select(cmd);
        }
    });
    self.element = args.element;
    self.event = args.event;
}

Menu.prototype = {
    activate: function () {
        var self = this;
        self.menu.menu('refresh');
        if (self.event) {
            self.handler(self.event);
        } else {
            self.element.contextmenu(self.handler);
        }
    }
};

function Event(sender) {
    this.sender = sender;
    this.listeners = [];
}

Event.prototype = {
    attach: function (listener) {
        this.listeners.push(listener);
    },
    notify: function (args) {
        var i;
        for (i = 0; i < this.listeners.length; i += 1) {
            this.listeners[i](this.sender, args);
        }
    }
};
