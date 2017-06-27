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

function element(tag, attrs, text) {
    var a = '';
    for (var key in attrs) {
        if (attrs.hasOwnProperty(key)) {
            a += ' ' + key + '="' + attrs[key] + '"';
        }
    }
    if (text)
        return '<'+tag+a+'>'+text+'</'+tag+'>';
    else
        return '<'+tag+a+'/>';
}

function containsObject(obj, list) {
    var i;
    for (i = 0; i < list.length; i++) {
        if (list[i] === obj) {
            return true;
        }
    }
    return false;
}

function cmp_date(a,b) {
    for (var i=0; i<3; i++) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
    }
    return 0;
}

function Widget(args) {
    var self = this;
    self.type = args.type;
    self.container_id = args.container_id;
    self.id = args.id;
    if (args.pretext)
        self.pretext = args.pretext;
    else
        self.pretext = '';
    var tag;
    var attr = {id:args.id};
    if (args.type == 'checkbox' || args.type == 'text') {
        tag = 'input';
        attr.type = args.type
    } else if (args.type == 'select') {
        tag = 'select';
    } else if (args.type == 'checkbox-list') {
        attr.style = 'overflow-y:scroll; max-height:350px; background-color:#c7ecfe;';
        tag = 'div';
    } else if (args.type == 'para') {
        tag = 'p';
    }
    var content = '';
    if (args.content) {
        content = args.content;
    } else if (args.list) {
        self.list = args.list;
        $.each(args.list, function(i, item) {
            var tag, attr, name, x;
            if (args.get_item) {
                item = args.get_item(i, item);
                if (!item) return true;
            }
            if (args.get_item_name) {
                name = args.get_item_name(item);
            } else if (typeof item === 'object') {
                name = item.name;
            } else {
                name = item;
            }
            if (args.type == 'select') {
                tag = 'option';
                if (typeof item === 'object') {
                    attr = {value:item.id};
                } else {
                    attr = {value:i};
                }
                if (name === args.selected) attr.selected = 'selected';
                x = '';
            } else if (args.type == 'checkbox-list') {
                tag = 'input';
                name = element('a', {id:'item', item:item.id}, name);
                attr = {type:'checkbox', item:item.id};
                if (args.selected[item.id]) attr.checked="checked"; 
                x = element('br');
            }
            content += element(tag, attr, name) + x;
        });
    }
    self.element = element(tag, attr, content);
}

Widget.prototype = {
    content: function() {
        var self = this;
        return self.pretext+self.element;
    },
    checked: function() {
        var self = this;
        return $(self.container_id+' #'+self.id).prop('checked');
    },
    fromList: function(id) {
        var self = this;
        if (!id) return null;
        var retval = null;
        $.each(self.list, function(i, item) {
            if (item.id == id) {
                retval = item;
                return false;
            }
        });
        return retval;
    },
    selected: function() {
        var self = this;
        return self.fromList($(self.container_id+' #'+self.id).val());
    },
    selected_ids: function() {
        var self = this;
        if (self.type === 'checkbox-list') {
            var ids = {};
            $.each($(self.container_id+' :checkbox'), function(i, item) {
                if (item.checked) ids[item.getAttribute('item')]= 1;
            });
            return ids;
        }
    },
    change: function(fct) {
        var self = this;
        $(self.container_id+' #'+self.id).change(fct);
    },
    html: function(html) {
        var self = this;
        $(self.container_id+' #'+self.id).html(html);
    },
};

function makeMenu(args) {
    var menu = $(args.menu);
    var options = '';
    $.each(args.options, function(i, item) {
        if (Array.isArray(item)) {
            var first = item.shift();
            var sub = '';
            $.each(item, function(i2, item2) {
                sub += element('li', {}, element('div', {tag:item2.cmd}, item2.label));
            });
            sub = element('div', {}, first.label)+element('ul', {}, sub);
            options += element('li', {}, sub);
        } else {
            options += element('li', {}, element('div', {tag:item.cmd}, item.label));
        }
    });
    menu.html(options);
    menu.menu({
        select:function( event, ui ) {
            var cmd = ui.item.children().attr('tag');
            menu.hide();
            args.select(cmd);
        }
    });
    menu.menu("refresh");
    args.element.contextmenu(function(e) {
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
    attach : function(listener) {
        this.listeners.push(listener);
    },
    notify : function(args) {
        for (var i = 0; i < this.listeners.length; ++i) {
            this.listeners[i](this.sender, args);
        }
    }
};
