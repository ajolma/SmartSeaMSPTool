/*
Copyright (c) 2016-2017, Finnish Environment Institute SYKE All rights
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
/*global $, msp*/

/**
 * A singleton for adding, editing, or deleting plans, uses, layers,
 * or rules.
 * @constructor
 * @param {msp.Config} config - Configuration.
 * @param {msp.Model} model - Model.
 * @param {msp.View} view - View.
 * @param {string} selector - selector of editor div.
 */
msp.Editor = function (options) {
    var self = this,
        lis = function (me) {
            var c = '';
            $.each(me.tabs, function (i, tab) {
                c += msp.e('li', {id: tab.id + '-tab'}, msp.e('a', {href: '#' + tab.id}, tab.title));
            });
            return c;
        },
        divs = function (me) {
            var c = '';
            $.each(me.tabs, function (i, tab) {
                c += msp.e('div', {id: tab.id}, msp.e('p', {id: 'radio'}) + msp.e('p', {id: 'buttons'}));
            });
            return c;
        }
        ;
    
    self.selector = options.selector;
    self.config = options.config;
    self.model = options.model;
    self.view = options.view;

    self.tabs = [
        {index: 0, title: 'Plans', id: 'plans'},
        {index: 1, title: 'Uses', id: 'uses'},
        {index: 2, title: 'Layers', id: 'layers'},
        {index: 3, title: 'Rules', id: 'rules'},
    ];

    self.editor = $(self.selector);
    self.html = msp.e('ul', {}, lis(self)) + divs(self);
    $.each(self.tabs, function (i, tab) {
        tab.selector = self.selector + ' #' + tab.id;
    });

    self.model.newPlans.attach(function () {
        if (self.isOpen) {
            self.createPlansPlus();
        }
    });

    self.model.usesChanged.attach(function () {
        if (self.isOpen) {
            self.createUsesPlus();
        }
    });

    self.model.newLayerList.attach(function () {
        if (self.isOpen) {
            self.createLayersPlus();
        }
    });

    self.model.rulesChanged.attach(function () {
        if (self.isOpen) {
            self.createRulesPlus();
        }
    });
    
};

msp.Editor.prototype = {

    buttons: function (what, klass) {
        var a = [];
        if (what.indexOf('a') !== -1) {
            a.push(msp.e('button', {type: 'button', class: klass + ' add'}, 'Add'));
        }
        if (what.indexOf('e') !== -1) {
            a.push(msp.e('button', {type: 'button', class: klass + ' edit'}, 'Edit'));
        }
        if (what.indexOf('d') !== -1) {
            a.push(msp.e('button', {type: 'button', class: klass + ' delete'}, 'Delete'));
        }
        return a.join('&nbsp;&nbsp;');
    },

    createPlans: function () {
        var self = this;
        self.plans = self.model.plans.length > 0 ? new msp.Widget({
            pretext: 'Select a plan:',
            container: self.selector,
            id: 'plans-radio',
            type: 'radio-group',
            list: self.model.plans,
            selected: self.model.plan.id
        }) : new msp.Widget({
            pretext: 'No plans yet.',
            container: self.selector,
            id: 'plans',
            type: 'paragraph'                    
        });
    },

    createPlansPlus: function () {
        var self = this;
        self.createPlans();
        $(self.tabs[0].selector + ' #radio').html(self.plans.html());
        self.plans.changed(function foo() {
            var b = '',
                plan = self.plans.getSelected();
            if (plan) {
                self.model.changePlan(plan.id);
                if (self.model.plan && self.config.config.auth) {
                    b = self.model.plan.owner === self.config.config.user ? 'ade' : 'a';
                }
            } else {
                if (self.config.config.auth) {
                    b = 'a';
                }
            }
            $(self.tabs[0].selector + ' #buttons').html(self.buttons(b, 'plan-button'));
            $(self.tabs[0].selector + ' .plan-button').click(function () {
                var classList = this.className.split(/\s+/);
                if (classList.includes('add')) {
                    self.view.planCommand.notify({cmd: 'add'});
                } else if (classList.includes('edit')) {
                    self.view.planCommand.notify({cmd: 'edit'});
                } else if (classList.includes('delete')) {
                    self.view.planCommand.notify({cmd: 'delete'});
                }
            });
            self.createUsesPlus();
            return foo;
        }());
    },

    createUses: function () {
        var self = this;
        self.use = self.model.layer ?
            self.model.layer.use :
            (self.model.plan ? self.model.plan.uses[0] : null);
        self.uses = self.use ? new msp.Widget({
            pretext: 'Select a use:',
            container: self.selector,
            id: 'uses-radio',
            type: 'radio-group',
            list: self.model.plan.uses,
            selected: self.use.id
        }) : new msp.Widget({
            pretext: 'No uses in this plan.',
            container: self.selector,
            id: 'uses',
            type: 'paragraph'                    
        });
    },

    createUsesPlus: function () {
        var self = this;
        self.createUses();
        $(self.tabs[1].selector + ' #radio').html(self.uses.html());
        self.uses.changed(function foo() {
            var b = '';
            self.view.closeUse(self.use);
            self.use = self.uses.getSelected();
            if (self.use && self.config.config.auth) {
                if (msp.useClass(self.use) === msp.enum.DATA) {
                    b = 'ae';
                } else if (msp.useClass(self.use) === msp.enum.ECOSYSTEM) {
                    b = 'a';
                } else {
                    b = self.use.owner === self.config.config.user ? 'ade' : 'a';
                }
            }
            $(self.tabs[1].selector + ' #buttons').html(self.buttons(b, 'use-button'));
            if (b !== '') {
                $(self.tabs[1].selector + ' .use-button').click(function () {
                    var classList = this.className.split(/\s+/);
                    if (classList.includes('add')) {
                        self.view.useCommand.notify({cmd: 'add'});
                    } else if (classList.includes('edit')) {
                        self.view.useCommand.notify({cmd: 'edit', use: self.use});
                    } else if (classList.includes('delete')) {
                        self.view.useCommand.notify({cmd: 'delete', use: self.use});
                    }
                });
            }
            self.createLayersPlus();
            self.view.openUse(self.use);
            return foo;
        }());
    },

    createLayers: function () {
        var self = this;
        if (self.use && self.model.layer) {
            if (!self.use.layers.find(function (layer) {
                return layer.id === self.model.layer.id && layer.use.id === self.model.layer.use.id;
            })) {
                self.model.unselectLayer();
            }
        }
        if (self.use && !self.model.layer && self.use.layers[0]) {
            self.model.selectLayer(self.use.layers[0]);
        }
        self.layers = self.model.layer ? new msp.Widget({
            pretext: 'Select a layer:',
            container: self.selector,
            id: 'layers-radio',
            type: 'radio-group',
            list: self.use.layers,
            selected: self.model.layer.id,
        }) : new msp.Widget({
            pretext: 'No layers in this use.',
            container: self.selector,
            id: 'layers',
            type: 'paragraph'                    
        });
    },

    createLayersPlus: function () {
        var self = this;
        self.createLayers();
        $(self.tabs[2].selector + ' #radio').html(self.layers.html());
        self.layers.changed(function foo() {
            var b = '',
                use_class = msp.useClass(self.use);
            self.model.unselectLayer();
            self.model.selectLayer(self.layers.getSelected());
            if (self.use && self.config.config.auth) {
                if (use_class !== msp.enum.DATA && use_class !== msp.enum.ECOSYSTEM) {
                    if (self.model.layer) {
                        b = self.model.layer.owner === self.config.config.user ? 'ade' : 'a';
                    } else {
                        b = 'a';
                    }
                }
            }
            $(self.tabs[2].selector + ' #buttons').html(self.buttons(b, 'layer-button'));
            if (b !== '') {
                $(self.tabs[2].selector + ' .layer-button').click(function () {
                    var classList = this.className.split(/\s+/);
                    if (classList.includes('add')) {
                        self.view.layerCommand.notify({cmd: 'add', use: self.use});
                    } else if (classList.includes('edit')) {
                        self.view.layerCommand.notify({cmd: 'edit', use: self.use});
                    } else if (classList.includes('delete')) {
                        self.view.layerCommand.notify({cmd: 'delete', use: self.use});
                    }
                });
            }
            self.createRulesPlus();
            
            return foo;
        }());
    },

    createRules: function () {
        var self = this;
        self.rule = (self.model.layer && self.model.layer.rules) ? self.model.layer.rules[0] : undefined;
        self.rules = self.rule ? new msp.Widget({
            pretext: 'Select a rule:',
            container: self.selector,
            id: 'rules-radio',
            type: 'radio-group',
            list: self.model.layer.rules,
            nameForItem: function (rule) {
                return rule.getName();
            },
            selected: self.rule.id,
        }) : new msp.Widget({
            pretext: 'No rules in this layer.',
            container: self.selector,
            id: 'rules',
            type: 'paragraph'                    
        });
    },

    createRulesPlus: function () {
        var self = this;
        var b = '';
        if (self.config.config.auth  &&
            self.model.layer &&
            self.model.layer.owner === self.config.config.user) {
            b = 'ade';
        }
        self.createRules();
        $(self.tabs[3].selector + ' #radio').html(self.rules.html());
        $(self.tabs[3].selector + ' #buttons').html(self.buttons(b, 'rule-button'));
        if (b !== '') {
            $(self.tabs[3].selector + ' .rule-button').click(function () {
                var classList = this.className.split(/\s+/),
                    options = {plan: self.model.plan, use: self.use};
                self.rule = self.rules.getSelected();
                if (classList.includes('add')) {
                    options.cmd = 'add';
                    self.view.ruleCommand.notify(options);
                } else if (classList.includes('edit')) {
                    options.cmd = 'edit';
                    options.rule = self.rule;
                    self.view.ruleCommand.notify(options);
                } else if (classList.includes('delete')) {
                    options.cmd = 'delete';
                    options.rule = self.rule;
                    self.view.ruleCommand.notify(options);
                }
            });
        }
    },
    
    open: function (options) {
        var self = this, 
            tabs,
            active_tab = (options && options.active_tab) ?
                self.tabs.find(function (tab) {return tab.id === options.active_tab;}) :
                self.tabs[0];
      
        self.editor.dialog({
            autoOpen: false,
            height: 600,
            width: 500,
            modal: true,
            buttons: {
                Close: function () {
                    self.editor.dialog('close');
                    self.isOpen = false;
                }
            },
        });
        self.editor.html(msp.e('div', {id: 'tabs'}));

        tabs = $(self.selector + ' #tabs');
        tabs.html(self.html);

        self.createPlansPlus();
        
        tabs.tabs({
            active: active_tab.index
        });
        
        self.editor.dialog('open');
        self.isOpen = true;
    }
    
};
