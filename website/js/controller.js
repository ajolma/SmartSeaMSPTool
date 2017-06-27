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

// after https://alexatnet.com/articles/model-view-controller-mvc-javascript

function MSPController(model, view) {
    var self = this;
    self.model = model;
    self.view = view;
    self.editor_id = '#editor';
    self.editor = $(self.editor_id);
    self.rule_tool_id = '#rule-tool';
    self.rule_tool = $(self.rule_tool_id);
    self.klasses = {};

    self.use_classes = null;
    self.layer_classes = null;

    self.view.planCommand.attach(function(sender, args) {
        if (args.cmd == 'add')
            self.addPlan();
        else if (args.cmd == 'edit')
            self.editPlan(self.model.plan);
        else if (args.cmd == 'delete')
            self.deletePlan(self.model.plan);
        else if (args.cmd == 'add_use')
            self.addUse(self.model.plan);
    });
    
    self.view.useCommand.attach(function(sender, args) {
        if (args.cmd == 'edit')
            self.editUse(args.use);
        else if (args.cmd == 'delete')
            self.deleteUse(args.use);
        else if (args.cmd == 'add_layer')
            self.addLayer(args.use);
    });
    
    self.view.layerCommand.attach(function(sender, args) {
        if (args.cmd == 'edit')
            self.editLayer(args.layer);
        else if (args.cmd == 'delete')
            self.deleteLayer(args.layer);
        else if (args.cmd == 'add_rule')
            self.addRule(args.layer);
        else if (args.cmd == 'delete_rule')
            self.deleteRule(args.layer);
    });
    
    self.view.ruleSelected.attach(function(sender, args) {
        self.modifyRule(args);
    });

    self.model.newPlans.attach(function(sender, args) {
        self.editor.dialog('close');
    });

    self.editor.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: true,
        buttons: {
            Ok: function() {
                if (self.ok()) self.editor.dialog('close');
            },
            Cancel: function() {
                self.editor.dialog('close');
            }
        },
        close: function() {
        }
    });

    self.rule_tool.dialog({
        autoOpen: false,
        height: 400,
        width: 350,
        modal: false,
        buttons: {
            Apply: function() {
                self.apply();
            },
            Close: function() {
                self.rule_tool.dialog('close');
            }
        },
        close: function() {
        }
    });
}

MSPController.prototype = {
    post: function(args) {
        var self = this;
        $.ajaxSetup({
            headers: { 
                Accept : 'application/json'
            },
            crossDomain: true,
            xhrFields: {
                withCredentials: true
            }
        });
        $.post(args.url, args.payload,
               function(data) {
                   if (data.error)
                       self.model.error(data.error);
                    else
                        args.atSuccess(data);
                }
              )
            .fail(function(xhr, textStatus, errorThrown) {
                var msg = xhr.responseText;
                if (msg == '') msg = textStatus;
                msg = 'Calling SmartSea MSP server failed. The error message is: '+msg;
                self.model.error(msg);
            });  
    },
    simpleObjects: function(klass, query) {
        var self = this;
        if (!query) query = '';
        if (!self.klasses[klass]) {
            $.ajax({
                headers: {
                    Accept: 'application/json'
                },
                url: 'http://'+server+'/browser/'+klass+'?'+query,
                success: function (result) {
                    if (result.isOk == false) self.model.error(result.message);
                    self.klasses[klass] = result;
                },
                fail: function (xhr, textStatus, errorThrown) {
                    var msg = xhr.responseText;
                    if (msg == '') msg = textStatus;
                    msg = 'Calling SmartSea MSP server failed. The error message is: '+msg;
                    self.model.error(msg);
                },
                async: false
            });
        }
        return self.klasses[klass];
    },
    addPlan: function(args) {
        var self = this;
        if (!args) args = {};
        self.editor.dialog('option', 'title', 'Uusi suunnitelma');
        self.editor.dialog('option', 'height', 400);
        var name = 'plan-name';
        var html = 'Anna nimi suunnitelmalle: '+element('input', {type:'text', id:name}, '');
        if (args.error) html = element('p', {style:'color:red;'}, args.error)+html;
        self.editor.html(html);
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: 'http://'+server+'/browser/plan?request=save',
                    payload: { name: name },
                    atSuccess: function(data) {
                        self.model.addPlan(data);
                    }
                });
            } else {
                self.addPlan({error:"Suunnitelma '"+name+"' on jo olemassa."});
                return false;
            }
        };
        self.editor.dialog('open');
    },
    editPlan: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'Suunnitelma');
        self.editor.dialog('option', 'height', 400);
        var name = 'plan-name';
        var html = element('input', {type:'text', id:name, value:plan.name}, '');
        html = element('p', {}, 'Suunnitelman nimi: ' + html);
        self.editor.html(html);
        self.ok = function() {
            name = $(self.editor_id+' #'+name).val();
            if (self.model.planNameOk(name)) {
                self.post({
                    url: 'http://'+server+'/browser/plan:'+plan.id+'?request=update',
                    payload: { name: name },
                    atSuccess: function(data) {self.model.editPlan(data)}
                });
            } else {
                self.addPlan({error:"Suunnitelma '"+name+"' on jo olemassa."});
                return false;
            }
            return true;
        };
        self.editor.dialog('open');
    },
    deletePlan: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista suunnitelma?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa koko suunnitelman '"+plan.name+"'?");
        self.ok = function() {
            self.post({
                url: 'http://'+server+'/browser/plan:'+plan.id+'?request=delete',
                atSuccess: function(data) {self.model.deletePlan(plan.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addUse: function(plan) {
        var self = this;
        self.editor.dialog('option', 'title', 'New use');
        self.editor.dialog('option', 'height', 400);
        var id = 'use-id';
        var name = 'use-name';
        var classes = self.simpleObjects('use_class');
        var list = '';
        for (var i = 0; i < classes.length; ++i) {
            if (!self.model.hasUse(classes[i].id)) {
                list += element('option', {value:classes[i].id}, classes[i].name);
            }
        }
        var html = 'Select the class for the new use: '+element('select', {id:id}, list);
        self.editor.html(html)
        self.ok = function() {
            id = $(self.editor_id+' #'+id).val();
            self.post({
                url: 'http://'+server+'/browser/plan:'+plan.id+'/uses?request=create',
                payload: {use_class: id},
                atSuccess: function(data) {
                    $.each(classes, function(i, klass) {
                        if (klass.id == data.use_class.value) {
                            data.name = klass.name;
                            return false;
                        }
                    });
                    self.model.addUse(data);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editUse: function(use) {
        if (use.id != 0) return; // only for "Data"
        var self = this;
        self.editor.dialog('option', 'title', 'Use');
        self.editor.dialog('option', 'height', 400);

        // put into the list those datasets that are not in rules
        // selected are those in self.model.plan.data
        
        var inRules = self.model.datasetsInRules();
        var notInRules = [];
        $.each(self.model.datasets.layers, function(i, layer) {
            if (!inRules[layer.id]) notInRules.push(layer);
        });
        var dataset_list = new Widget({
            container_id:self.editor_id,
            id:'dataset_list',
            type:'checkbox-list',
            list:notInRules,
            selected:self.model.plan.data,
            pretext:'Select the extra datasets for this plan: '
        });
        var html = element('p', {}, dataset_list.content());
        
        self.editor.html(html);
        self.ok = function() {
            var selected = dataset_list.selected_ids();
            var plan_id = self.model.plan.id;
            var update = '';
            $.each(selected, function(i, id) {
                if (update) update += '&';
                update += 'dataset='+id;
            });
            self.post({
                url: 'http://'+server+'/browser/plan:'+plan_id+'/extra_datasets?request=update',
                payload: update,
                atSuccess: function(data) {self.model.setPlanData(data)}
            });
        };
        self.editor.dialog('open');
    },
    deleteUse: function(use) {
        var self = this;
        self.post({
            url: 'http://'+server+'/browser/use:'+use.id+'?request=delete',
            payload: {},
            atSuccess: function(data) {self.model.deleteUse(use.id)}
        });
    },
    addLayer: function(use) {
        var self = this;
        self.editor.dialog('option', 'title', 'New layer');
        self.editor.dialog('option', 'height', 400);
        var klass_list = new Widget({
            container_id:self.editor_id,
            id:'layer-klass',
            type:'select',
            list:self.simpleObjects('layer_class'),
            get_item:function(i, klass) {
                if (klass.id == 5) return null; // TODO: Impact layers
                var retval = klass;
                $.each(use.layers, function(j, layer) {
                    if (klass.id == layer.class_id) {
                        retval = null;
                        return false;
                    }
                });
                return retval;
            },
            pretext:'Select the class for the new layer: '
        });
        var color_list = new Widget({
            container_id:self.editor_id,
            id:'layer-color',
            type:'select',
            list:self.simpleObjects('color_scale'),
            pretext:'Select the color for the new layer: '
        });
        
        var rule_id = 1;
        var name = 'layer-name';
        var html = element('p', {}, klass_list.content());
        html += element('p', {},
                        'The layer will be computed by rules that exclude areas from the layer.'+
                        ' You can add rules after you have created the layer first.');
        html += element('p', {}, color_list.content());
        self.editor.html(html)
        self.ok = function() {
            var klass = klass_list.selected();
            var color = color_list.selected();
            self.post({
                url: 'http://'+server+'/browser/layer?request=save',
                payload: {
                    use:use.id,
                    layer_class:klass.id,
                    color_scale:color.id,
                    classes:2,
                    min:0,
                    max:1,
                    rule_class:rule_id
                },
                atSuccess: function(layer) {self.model.addLayer(use, layer)}
            });
            self.editor.dialog('close');
        };
        self.editor.dialog('open');
    },
    editLayer: function(layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Layer');
        self.editor.dialog('option', 'height', 400);
        
        var change_color = new Widget({
            container_id:self.editor_id,
            id:'change-color',
            type:'checkbox',
            content:'Select the color for this layer: '
        });
        var color_list = new Widget({
            container_id:self.editor_id,
            id:'layer-color',
            type:'select',
            list:self.simpleObjects('color_scale'),
            selected:layer.color_scale
        });
        
        var html = element('p', {}, change_color.content()+color_list.content());
        
        self.editor.html(html);
        
        self.ok = function() {
            var color = color_list.selected(); // fixme, when is this set?
            self.editor.dialog('close');
        };
        self.editor.dialog('open');
    },
    deleteLayer: function(layer) {
        var self = this;
        self.post({
            url: 'http://'+server+'/browser/layer:'+layer.id+'?request=delete',
            payload: {},
            atSuccess: function(data) {self.model.deleteLayer(layer.id)}
        });
    },
    addRule: function(layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Rules in '+layer.name);
        self.editor.dialog('option', 'height', 400);
        
        // list the rules with a possibility to delete one or more with checkboxes

        var rule_add = new Widget({
            container_id:self.editor_id,
            id:'add-rule',
            type:'checkbox',
            content:'Add a rule to this layer:'
        });
        var dataset_list = new Widget({
            container_id:self.editor_id,
            id:'rule-dataset',
            type:'select',
            list:self.simpleObjects('dataset', 'path=notnull'), // fixme: get this from self.model.datasets
            pretext:'Rule is based on the dataset: '
        });
        
        var html = element('p', {}, rule_add.content()) + element('p', {}, dataset_list.content());
        
        // the rule can be binary, if dataset has only one class
        // otherwise the rule needs operator and threshold
        var op_list = new Widget({
            container_id:self.editor_id,
            id:'rule-op',
            type:'select',
            list:self.simpleObjects('op'),
            pretext:'Define the operator and the threshold:<br/>'
        });
        var threshold = new Widget({
            container_id:self.editor_id,
            id:'rule-threshold',
            type:'text',
        });
        var semantic_threshold = null;
        var rule_op_threshold = op_list.content() + '&nbsp;' + threshold.content();
        var rule_binary = 'Binary rule';
        var rule_defs = new Widget({
            container_id:self.editor_id,
            id:'rule-defs',
            type:'para'
        });
        
        html += rule_defs.content();

        var delete_rule = new Widget({
            container_id:self.editor_id,
            id:'delete-rule',
            type:'checkbox',
            content:'Delete rule(s) from this layer:'
        });

        html += element('p', {}, delete_rule.content());

        var rules = new Widget({
            container_id:self.editor_id,
            id:'rules-to-delete',
            type:'checkbox-list',
            list:layer.rules,
            selected:{},
            get_item_name:function(rule) {
                var name = rule.name;
                if (!rule.binary) {
                    var value = rule.value;
                    if (rule.value_semantics) value = rule.value_semantics[value];
                    name += ' '+rule.op+' '+value;
                }
                return name;
            }
        });
        
        html += rules.content();

        var dataset_changed = function() {
            var dataset = dataset_list.selected();
            if (!dataset) {
                rule_defs.html('');
            } else if (dataset.classes == 1) {
                rule_defs.html(rule_binary);
            } else if (dataset.class_semantics) {
                semantic_threshold = new Widget({
                    container_id:self.editor_id,
                    id:'rule-threshold',
                    type:'select',
                    list:dataset.class_semantics.split(/;\s+/)
                });
                rule_defs.html(op_list.content() + '&nbsp;' + semantic_threshold.content());
            } else {
                rule_defs.html(rule_op_threshold);
            }
        };
            
        dataset_list.change(dataset_changed);
        dataset_changed();

        self.editor.html(html);
        
        self.ok = function() {
            if (rule_add.checked()) {
                var dataset = dataset_list.selected();
                var op = {id:1};
                var value = 0;
                // value_type is to be gone from rule, since it is available from dataset (or layer?)
                // from dataset we also get min & max => slider
                if (dataset.classes == 1) {
                } else if (dataset.class_semantics) {
                } else {
                }
                self.post({
                    url: 'http://'+server+'/browser/layer:'+layer.id+'/rule?request=save',
                    payload: {r_dataset:dataset.id, op:op.id, value:value},
                    atSuccess: function(data) {self.model.addRule(layer, data)}
                });
            } else if (rule_delete.checked()) {
            }
            self.editor.dialog('close');
        };
        self.editor.dialog('open');
    },
    deleteRule: function(layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Delete rules from '+layer.name);
        self.editor.dialog('option', 'height', 400);
    },
    modifyRule: function(args) {
        var self = this;
        self.rule_tool.dialog('option', 'title', 'Modify rule');
        self.editor.dialog('option', 'height', 400);
        var rule = self.model.selectRule(args.id);
        var html = rule.name;
        
        html = html
            .replace(/^- If/, 'Do not allocate if')
            .replace(/==/, 'equals:');

        var editor = 'rule-editor';
        var slider_value = 'rule-slider-value';
        if (rule.value_semantics) {
            if (self.model.layer.rule_class == 'exclusive')
                html = 'Unmark cell if '+html+' is '+rule.op+' than';
            //var label = element('label',{for:'rule-editor'},'Select value');
            var options = '';
            $.each(rule.value_semantics, function(i, semantic) {
                var attr = {value:i};
                if (i == rule.value) attr.selected = 'selected';
                options += element('option', attr, semantic);
            });
            var menu = element('select', {id:editor}, options);
            html += element('p',{},menu);
        } else if (rule.binary) {
            html += element('p',{},'Binary rule, nothing to edit.');
        } else if (rule.type == 'integer') {
            html += element('p',{},element('input', {id:editor}));
        } else if (rule.type == 'real') {
            html += element('p', {}, element('div', {id:editor}));
            html += element('p', {id:slider_value}, '');
        }
        html += element('p', {}, rule.description);
        self.rule_tool.html(html);

        editor = self.rule_tool_id+' #'+editor;
        slider_value = self.rule_tool_id+' #'+slider_value;
        
        if (rule.type == 'integer') {
            $(editor)
                .spinner({
                    min: rule.min,
                    max: rule.max
                })
                .spinner('value', rule.value);
        } else if (rule.type == 'real') {
            $(editor).slider({
                min: parseFloat(rule.min),
                max: parseFloat(rule.max),
                step: 0.1, // todo fix this
                value: parseFloat(rule.value),
                slide: function (event, ui) {
                    var value = slider.slider('value');
                    $(slider_value).html(value);
                }
            });
            $(slider_value).html(rule.value);
        }
        self.apply = function() {
            var value;
            if (rule.value_semantics)
                value = $(editor).find(':selected').attr('value');
            else if (rule.type == 'integer')
                value = $(editor).spinner('value');
            else if (rule.type == 'real')
                value = $(editor).slider('value');
            self.post({
                url: 'http://'+server+'/browser/rule:'+rule.id+'?request=modify',
                payload: { value: value },
                atSuccess: function(data) {
                    self.model.modifyRule(data.object);
                }
                // if (xhr.status == 403)
                // self.model.error('Rule modification requires cookies. Please enable cookies and reload this app.');
            });
        };
        self.rule_tool.dialog('open');
    }
};

