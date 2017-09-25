'use strict';

function Editor(options) {
    var self = this,
        lis = function (me) {
            var c = '';
            $.each(me.tabs, function (i, tab) {
                c += element('li', {id: tab.id + '-tab'}, element('a', {href: '#' + tab.id}, tab.title));
            });
            return c;
        },
        divs = function (me) {
            var c = '';
            $.each(me.tabs, function (i, tab) {
                c += element('div', {id: tab.id}, element('p', {id: 'radio'}) + element('p', {id: 'buttons'}));
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
    self.html = element('ul', {}, lis(self)) + divs(self);
    $.each(self.tabs, function (i, tab) {
        tab.selector = self.selector + ' #' + tab.id;
    });

    self.model.newPlans.attach(function (ignore, args) {
        if (self.isOpen) {
            self.createPlansPlus();
        }
    });

    self.model.usesChanged.attach(function (ignore, args) {
        if (self.isOpen) {
            self.createUsesPlus();
        }
    });

    self.model.newLayerList.attach(function (ignore, args) {
        if (self.isOpen) {
            self.createLayersPlus();
        }
    });

    self.model.rulesChanged.attach(function (ignore, args) {
        if (self.isOpen) {
            self.createRulesPlus();
        }
    });
    
}

Editor.prototype = {

    buttons: function (what, klass) {
        var a = [];
        if (what.includes('a')) {
            a.push(element('button', {type: 'button', class: klass + ' add'}, 'Add'));
        }
        if (what.includes('e')) {
            a.push(element('button', {type: 'button', class: klass + ' edit'}, 'Edit'));
        }
        if (what.includes('d')) {
            a.push(element('button', {type: 'button', class: klass + ' delete'}, 'Delete'));
        }
        return a.join('&nbsp;&nbsp;');
    },

    createPlans: function () {
        var self = this;
        self.plans = new Widget({
            pretext: 'Select a plan:',
            container: self.selector,
            id: 'plans-radio',
            type: 'radio-group',
            list: self.model.plans,
            selected: self.model.plan.id
        });
    },

    createPlansPlus: function () {
        var self = this;
        self.createPlans();
        $(self.tabs[0].selector + ' #radio').html(self.plans.html());
        self.plans.changed(function foo() {
            var b = '';
            self.model.changePlan(self.plans.getSelected().id);
            if (self.model.plan && self.config.config.auth) {
                b = self.model.plan.owner === self.config.config.user ? 'ade' : 'a';
            }
            $(self.tabs[0].selector + ' #buttons').html(self.buttons(b, 'plan-button'));
            $(self.tabs[0].selector + ' .plan-button').click(function (event) {
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
        self.use = self.model.plan.uses[0];
        self.uses = self.use ? new Widget({
            pretext: 'Select a use:',
            container: self.selector,
            id: 'uses-radio',
            type: 'radio-group',
            list: self.model.plan.uses,
            selected: self.use.id
        }) : new Widget({
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
            if (self.config.config.auth) {
                if (self.use.id === 0) {
                    b = 'ae';
                } else if (self.use) {
                    b = self.use.owner === self.config.config.user ? 'ade' : 'a';
                } else {
                    b = 'a';
                }
            }
            $(self.tabs[1].selector + ' #buttons').html(self.buttons(b, 'use-button'));
            if (b !== '') {
                $(self.tabs[1].selector + ' .use-button').click(function (event) {
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
        if (!self.use) {
            return;
        }
        if (self.model.layer) {
            if (!self.use.layers.find(function (layer) {
                return layer.id === self.model.layer.id && layer.use.id === self.model.layer.use.id;
            })) {
                self.model.unselectLayer();
            }
        }
        if (!self.model.layer && self.use.layers[0]) {
            self.model.selectLayer(self.use.layers[0]);
        }
        self.layers = self.model.layer ? new Widget({
            pretext: 'Select a layer:',
            container: self.selector,
            id: 'layers-radio',
            type: 'radio-group',
            list: self.use.layers,
            selected: self.model.layer.id,
        }) : new Widget({
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
            var b = '';
            self.model.unselectLayer();
            self.model.selectLayer(self.layers.getSelected());
            if (self.config.config.auth) {
                if (self.use.id > 1) {
                    if (self.model.layer) {
                        b = self.model.layer.owner === self.config.config.user ? 'ade' : 'a';
                    } else {
                        b = 'a';
                    }
                }
            }
            $(self.tabs[2].selector + ' #buttons').html(self.buttons(b, 'layer-button'));
            if (b !== '') {
                $(self.tabs[2].selector + ' .layer-button').click(function (event) {
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
        self.rules = self.rule ? new Widget({
            pretext: 'Select a rule:',
            container: self.selector,
            id: 'rules-radio',
            type: 'radio-group',
            list: self.model.layer.rules,
            nameForItem: function (rule) {
                return rule.getName();
            },
            selected: self.rule.id,
        }) : new Widget({
            pretext: 'No rules in this layer.',
            container: self.selector,
            id: 'rules',
            type: 'paragraph'                    
        });
    },

    createRulesPlus: function () {
        var self = this;
        var b = '';
        if (self.config.config.auth  && self.model.layer && self.model.layer.owner === self.config.config.user) {
            b = 'ade';
        }
        self.createRules();
        $(self.tabs[3].selector + ' #radio').html(self.rules.html());
        $(self.tabs[3].selector + ' #buttons').html(self.buttons(b, 'rule-button'));
        if (b !== '') {
            $(self.tabs[3].selector + ' .rule-button').click(function (event) {
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
            active_tab = (options && options.active_tab)
            ? self.tabs.find(function (tab) {return tab.id === options.active_tab})
            : self.tabs[0];
      
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
        self.editor.html(element('div', {id: 'tabs'}));

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
