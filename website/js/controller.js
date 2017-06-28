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
    self.server = 'http://'+server+'/browser/';
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
            self.editUse(self.model.plan, args.use);
        else if (args.cmd == 'delete')
            self.deleteUse(self.model.plan, args.use);
        else if (args.cmd == 'add_layer')
            self.addLayer(self.model.plan, args.use);
    });
    
    self.view.layerCommand.attach(function(sender, args) {
        if (args.cmd == 'edit')
            self.editLayer(args.layer);
        else if (args.cmd == 'delete')
            self.deleteLayer(self.model.plan, args.use, args.layer);
        else if (args.cmd == 'add_rule')
            self.addRule(self.model.plan, args.use, args.layer);
        else if (args.cmd == 'delete_rule')
            self.deleteRule(self.model.plan, args.use, args.layer);
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
                url: self.server+klass+'?'+query,
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
                    url: self.server+'plan?request=save',
                    payload: { name: name },
                    atSuccess: function(data) {
                        var plan = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        self.model.addPlan(plan);
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
                    url: self.server+'plan:'+plan.id+'?request=update',
                    payload: { name: name },
                    atSuccess: function(data) {
                        var plan = {
                            id: data.id.value,
                            owner: data.owner.value,
                            name: data.name.value
                        };
                        self.model.editPlan(plan);
                    }
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
                url: self.server+'plan:'+plan.id+'?request=delete',
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
                url: self.server+'plan:'+plan.id+'/uses?request=create',
                payload: {use_class: id},
                atSuccess: function(data) {
                    var use = {
                        id: data.id.value,
                        owner: data.owner.value,
                        plan: data.plan.value,
                        class_id: data.use_class.value,
                        layers: []
                    };
                    $.each(classes, function(i, klass) {
                        if (klass.id == data.use_class.value) {
                            use.name = klass.name;
                            return false;
                        }
                    });
                    self.model.addUse(use);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editUse: function(plan, use) {
        if (use.id != 0) return; // only for "Data"
        var self = this;
        self.editor.dialog('option', 'title', 'Use');
        self.editor.dialog('option', 'height', 400);

        // put into the list those datasets that are not in rules
        // selected are those in plan.data
        
        var inRules = self.model.datasetsInRules();
        var notInRules = [];
        $.each(self.model.datasets.layers, function(i, layer) {
            if (!inRules[layer.id]) notInRules.push(layer);
        });
        var datasets = new Widget({
            container_id:self.editor_id,
            id:'dataset_list',
            type:'checkbox-list',
            list:notInRules,
            selected:plan.data,
            pretext:'Select the extra datasets for this plan: '
        });
        var html = element('p', {}, datasets.content());
        
        self.editor.html(html);
        self.ok = function() {
            var selected = datasets.selected_ids();
            var update = '';
            $.each(selected, function(id, i) {
                if (update) update += '&';
                update += 'dataset='+id;
            });
            self.post({
                url: self.server+'plan:'+plan.id+'/extra_datasets?request=update',
                payload: update,
                atSuccess: function(data) {self.model.setPlanData(data)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    deleteUse: function(plan, use) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista käyttömuoto?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa koko käyttömuodon '"+use.name+"' suunnitelmasta '"+plan.name+"'?");
        self.ok = function() {
            self.post({
                url: self.server+'use:'+use.id+'?request=delete',
                atSuccess: function(data) {self.model.deleteUse(use.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addLayer: function(plan, use) {
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

        var rule_class_list = new Widget({
            container_id:self.editor_id,
            id:'rule_class',
            type:'select',
            list:self.simpleObjects('rule_class'),
            pretext:'Select the rule class for the new layer: '
        });
        
        var name = 'layer-name';
        var html = element('p', {}, klass_list.content());
        html += element('p', {},
                        'The layer will be computed by rules that exclude areas from the layer.'+
                        ' You can add rules after you have created the layer first.');
        html += element('p', {}, color_list.content());
        self.editor.html(html)
        self.ok = function() {
            var klass = klass_list.selected();
            var rule_class = rule_class_list.fromList(1); // excusive
            var color = color_list.selected();
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers?request=create',
                payload: {
                    layer_class:klass.id,
                    color_scale:color.id,
                    rule_class:rule_class.id
                },
                atSuccess: function(data) {
                    var layer = {
                        id: data.id.value,
                        class_id: data.layer_class.value,
                        owner: data.owner.value,
                        rules: [],
                        use_class_id: use.class_id,
                        color_scale: color.name,
                        name: klass.name,
                        rule_class: rule_class.name
                    };
                    self.model.addLayer(use, layer);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    editLayer: function(layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Layer');
        self.editor.dialog('option', 'height', 400);
        
        var color_list = new Widget({
            container_id:self.editor_id,
            id:'layer-color',
            type:'select',
            list:self.simpleObjects('color_scale'),
            selected:layer.color_scale
        });
        
        var html = element('p', {}, color_list.content());
        
        self.editor.html(html);
        
        self.ok = function() {
            var color = color_list.selected(); // fixme, when is this set?
            return true;
        };
        self.editor.dialog('open');
    },
    deleteLayer: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Poista ominaisuus?');
        self.editor.dialog('option', 'height', 400);
        self.editor.html("Haluatko varmasti poistaa ominaisuuden '"+layer.name+"' käyttömuodosta '"+use.name+"'?");
        self.ok = function() {
            self.post({
                url: self.server+'layer:'+layer.id+'?request=delete',
                atSuccess: function(data) {self.model.deleteLayer(use.id, layer.id)}
            });
            return true;
        };
        self.editor.dialog('open');
    },
    addRule: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', 'Lisää sääntö tasoon '+layer.name);
        self.editor.dialog('option', 'height', 400);
        
        var dataset = new Widget({
            container_id:self.editor_id,
            id:'rule-dataset',
            type:'select',
            list:self.model.getPlan(0).uses[0].layers, //self.simpleObjects('dataset', 'path=notnull'),
            pretext:'Rule is based on the dataset: '
        });
        var rule = new Widget({
            container_id:self.editor_id,
            id:'rule-defs',
            type:'para'
        });
        var html = element('p', {}, dataset.content()) + element('p', {id:'descr'}, '') + rule.content();

        // the rule can be binary, if dataset has only one class
        // otherwise the rule needs operator and threshold
        var op = new Widget({
            container_id:self.editor_id,
            id:'rule-op',
            type:'select',
            list:self.simpleObjects('op'),
            pretext:'Define the operator and the threshold:<br/>'
        });
        var threshold;
        self.editor.html(html);
        dataset.changed((function changed() {
            var set = dataset.selected();
            $(self.editor_id+' #descr').html(set.descr);
            if (!set) {
                rule.html('');
            } else if (set.classes == 1) {
                rule.html('Binary rule');
            } else {
                var args = {
                    container_id:self.editor_id,
                    id:'threshold',
                };
                if (set.class_semantics) {
                    args.type = 'select';
                    args.list = set.class_semantics.split(/;\s+/);
                } else {
                    args.type = 'text';
                }
                threshold = new Widget(args);
                rule.html(op.content() + '&nbsp;' + threshold.content());
            }
            return changed;
        }()));

        self.ok = function() {
            var set = dataset.selected();
            var operator = op.selected();
            var value = 0;
            if (set.classes != 1) value = threshold.value();
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers:'+layer.id+'/rules?request=save',
                payload: {dataset:set.id, op:operator.id, value:value},
                atSuccess: function(data) {
                    var rule = {
                        id: data.id.value,
                        binary: set.classes == 1,
                        name: set.name,
                        min: data.min_value.value,
                        max: data.max_value.value,
                        op: operator.name,
                        value: data.value.value,
                        dataset_id: data.dataset.value,
                        data_type: set.data_type,
                        active: true,
                        description: set.descr,
                    };
                    self.model.addRule(layer, rule);
                }
            });
            return true;
        };
        self.editor.dialog('open');
    },
    deleteRule: function(plan, use, layer) {
        var self = this;
        self.editor.dialog('option', 'title', "Delete rules from layer '"+layer.name+"'");
        self.editor.dialog('option', 'height', 400);

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
        
        var html = element('p', {}, 'Select rules to delete:')+rules.content();
        
        self.editor.html(html);
        
        self.ok = function() {
            var selected = rules.selected_ids();
            var deletes = '';
            $.each(selected, function(id, i) {
                if (deletes) deletes += '&';
                deletes += 'rule='+id;
            });
            self.post({
                url: self.server+'plan:'+plan.id+'/uses:'+use.id+'/layers:'+layer.id+'/rules?request=delete',
                payload: deletes,
                atSuccess: function(data) {self.model.deleteRule(layer, selected)}
            });
            return true;
        };
        self.editor.dialog('open');
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
                url: self.server+'rule:'+rule.id+'?request=modify',
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

