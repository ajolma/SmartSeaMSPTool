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
            if (args.type == 'select') {
                // set selected
                if (typeof item == 'object')
                    content += element('option', {value:item.id}, item.name);
                else
                    content += element('option', {value:i}, item);
            } else if (args.type == 'checkbox-list') {
                var name = args.item_name(item);
                var label = element('a', {id:'item', item:item.id}, name);
                content += element('input', {type:'checkbox', item:item.id}, label) + element('br');
            }
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
    selected: function() {
        var self = this;
        var id = $(self.container_id+' #'+self.id).val();
        var retval = null;
        $.each(self.list, function(i, item) {
            if (item.id == id) {
                retval = item;
                return false;
            }
        });
        return retval;
    },
    change: function(fct) {
        var self = this;
        $(self.container_id+' #'+self.id).change(fct);
    },
    html: function(html) {
        var self = this;
        $(self.container_id+' #'+self.id).html(html);
    },
}
