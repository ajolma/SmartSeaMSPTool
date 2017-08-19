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

"use strict";
/*jslint browser: true*/
/*global $, jQuery, alert*/

function element(tag, attrs, text) {
    var a = '', key;
    for (key in attrs) {
        if (attrs.hasOwnProperty(key)) {
            a += ' ' + key + '="' + attrs[key] + '"';
        }
    }
    if (text) {
        if (text === 'Ø') { // empty element
            return '<' + tag + a + '>';
        } else {
            return '<' + tag + a + '>' + text + '</' + tag + '>';
        }
    }
    return '<' + tag + a + '/>';
}

function Widget(args) {
    var self = this,
        pretext = args.pretext || '',
        attr = {id: args.id},
        tag,
        html = '';
    
    self.type = args.type;
    self.container_id = args.container_id;
    self.id = args.id;
    self.selector = self.container_id + ' #' + args.id;
    self.selected = args.selected;
    self.value = args.value;
    self.min = args.min;
    self.max = args.max;

    self.newValue = args.newValue;

    if (self.type === 'checkbox' || self.type === 'text') {
        tag = 'input';
        attr.type = self.type;
    } else if (self.type === 'select') {
        tag = 'select';
    } else if (self.type === 'checkbox-list') {
        tag = 'div';
        attr.style = 'overflow-y:scroll; max-height:350px; background-color:#c7ecfe;';
    } else if (self.type === 'para') {
        tag = 'p';
    } else if (self.type === 'spinner') {
        tag = 'input';
    }
    if (args.content) {
        html = args.content;
    } else if (args.list) {
        // key => scalar, or key => object
        // 
        self.list = args.list;
        $.each(self.list, function (i, item) {
            var tag, attr2, name, x, sel;
            if (args.includeItem) {
                if (!args.includeItem(i, item)) {
                    return true;
                }
            }
            if (args.nameForItem) {
                name = args.nameForItem(item);
            } else if (typeof item === 'object') {
                name = item.name;
            } else {
                name = item;
            }
            if (self.type === 'select') {
                tag = 'option';
                if (typeof item === 'object') {
                    // list contains objects, give the id of the selected in selected
                    attr2 = {value: item.id};
                    if (self.selected) {
                        sel = self.selected;
                        if (typeof sel === 'object') {
                            sel = sel.id;
                        }
                        if (item.id.toString() === sel.toString()) {
                            attr2.selected = 'selected';
                        }
                    }
                } else {
                    // list contains scalars, give the key of the selected in value
                    attr2 = {value: i};
                    if (parseInt(i, 10) === self.value) {
                        attr2.selected = 'selected';
                    }
                }
                x = '';
            } else if (self.type === 'checkbox-list') {
                tag = 'input';
                name = element('a', {id: 'item', item: item.id}, name);
                attr2 = {type: 'checkbox', item: item.id};
                if (self.selected && self.selected[item.id]) {
                    // selected is a hash keyed with ids
                    attr2.checked = "checked";
                }
                x = element('br');
            } else {
                console.assert(true, {message: "What is this list type: " + self.type});
            }
            html += element(tag, attr2, name) + x;
        });
    }
    if (self.type === 'slider') {
        self.min = parseFloat(self.min);
        self.max = parseFloat(self.max);
        self.value = parseFloat(self.value);
        html = element('p', {}, element('div', attr));
        if (typeof args.slider_value_id === 'undefined') {
            args.slider_value_id = 'slider-value';
        }
        html += element('input', {id: args.slider_value_id, type: 'text'}, '');
        self.value_selector = self.container_id + ' #' + args.slider_value_id;
    } else if (tag === 'input') {
        if (self.type === 'checkbox' && self.selected) {
            attr.checked = "checked";
        } else if (self.type === 'text' && self.value) {
            attr.value = self.value;
        }
        html = element(tag, attr, 'Ø');
        if (args.label) {
            html += element('label', {for: self.id}, args.label);
        }
    } else {
        html = element(tag, attr, html);
    }
    self.my_html = pretext + html;
}

Widget.prototype = {
    prepare: function () {
        var self = this,
            slider;
        if (self.type === 'spinner') {
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
    html: function (html) {
        var self = this;
        if (html) {
            $(self.selector).html(html);
        } else {
            return self.my_html;
        }
    },
    checked: function () {
        var self = this;
        return $(self.selector).prop('checked');
    },
    fromList: function (id) {
        var self = this,
            retval = null;
        if (!id) {
            return retval;
        }
        /*jslint unparam: true*/
        $.each(self.list, function (ignore, item) {
            if (item.id.toString() === id.toString()) {
                retval = item;
                return false;
            }
        });
        /*jslint unparam: false*/
        return retval;
    },
    setValue: function (value) {
        var self = this;
        if (self.type === 'slider') {
            self.value = parseFloat(value);
            if (self.value < self.min) {
                self.value = self.min
            } else if (self.value > self.max) {
                self.value = self.max
            }
            $(self.selector).slider('value', self.value);
        }
    },
    getValue: function () {
        var self = this,
            value = $(self.selector).val();
        if (self.type === 'spinner') {
            return $(self.selector).spinner('value');
        }
        if (self.type === 'slider') {
            return self.value; //$(self.selector).slider('value'); is not the same for some reason
        }
        return value;
    },
    getSelected: function () {
        var self = this;
        return self.fromList(self.getValue());
    },
    getSelectedIds: function () {
        var self = this,
            ids = {};
        if (self.type === 'checkbox-list') {
            /*jslint unparam: true*/
            $.each($(self.container_id + ' :checkbox'), function (i, item) {
                if (item.checked) {
                    ids[item.getAttribute('item')] = 1;
                }
            });
            /*jslint unparam: false*/
        }
        return ids;
    },
    changed: function (fct) {
        var self = this;
        $(self.selector).change(fct);
    }
};

function makeMenu(args) {
    var menu = $(args.menu),
        options = '';
    /*jslint unparam: true*/
    $.each(args.options, function (i, item) {
        if (Array.isArray(item)) {
            var first = item.shift(),
                sub = '';
            $.each(item, function (i, item2) {
                sub += element('li', {}, element('div', {tag: item2.cmd}, item2.label));
            });
            sub = element('div', {}, first.label) + element('ul', {}, sub);
            options += element('li', {}, sub);
        } else {
            options += element('li', {}, element('div', {tag: item.cmd}, item.label));
        }
    });
    /*jslint unparam: false*/
    menu.html(options);
    /*jslint unparam: true*/
    menu.menu({
        select: function (event, ui) {
            var cmd = ui.item.children().attr('tag');
            menu.hide();
            args.select(cmd);
        }
    });
    /*jslint unparam: false*/
    menu.menu("refresh");
    args.element.contextmenu(function (e) {
        if (args.prelude) {
            args.prelude();
        }
        menu.css('position', 'absolute');
        menu.css('top', e.pageY);
        menu.css('left', e.pageX);
        $(".menu").hide(); // close all other menus
        menu.show();
        return false;
    });
}

function Event(sender) {
    this.sender = sender;
    this.listeners = [];
}

Event.prototype = {
    attach : function (listener) {
        this.listeners.push(listener);
    },
    notify : function (args) {
        var i;
        for (i = 0; i < this.listeners.length; i += 1) {
            this.listeners[i](this.sender, args);
        }
    }
};
