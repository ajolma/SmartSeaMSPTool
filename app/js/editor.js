'use strict';

function TestView() {
    var self = this;
    self.error = new Event(self);
    self.planCommand = new Event(self);
    self.useCommand = new Event(self);
    self.layerCommand = new Event(self);
    self.ruleClicked = new Event(self);
}

(function() {
    var editor_id = '#editor',
        editor = $(editor_id),
        plans_tab_id = 'tab-plans',
        uses_tab_id = 'tab-uses',
        layers_tab_id = 'tab-layers',
        rules_tab_id = 'tab-rules',
        html = element('ul', {},
                       element('li', {id: 1}, element('a', {href: '#' + plans_tab_id}, 'Plans')) +
                       element('li', {id: 2}, element('a', {href: '#' + uses_tab_id}, 'Uses')) +
                       element('li', {id: 3}, element('a', {href: '#' + layers_tab_id}, 'Layers')) +
                       element('li', {id: 4}, element('a', {href: '#' + rules_tab_id}, 'Rules'))) +
        element('div', {id: plans_tab_id}, element('p')) +
        element('div', {id: uses_tab_id}, element('p')) +
        element('div', {id: layers_tab_id}, element('p')) +
        element('div', {id: rules_tab_id}, element('p')),

        buttons = function (what, klass) {
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

        config = new Config({
            epsg: 1,
            config: {
                user: "guest",
                protocol: "http",
                server: "localhost:5000/SmartSea",
                auth: false
            }
        }),

        model = new MSPModel({config: config}),
        view = new TestView(),
        controller = new MSPController(model, view)
    
    ;
             
    controller.loadPlans(function () {
        var plan = model.plan,
            plans = new Widget({
                pretext: 'Select a plan:',
                container_id: editor_id,
                id: 'plans',
                type: 'radio-group',
                list: model.plans,
                selected: plan.id
            }),
            use, uses, createUses = function () {
                use = plan.uses[0];
                uses = use ? new Widget({
                    pretext: 'Select a use:',
                    container_id: editor_id,
                    id: 'uses',
                    type: 'radio-group',
                    list: plan.uses,
                    selected: use.id
                }) : new Widget({
                    pretext: 'No uses in this plan.',
                    container_id: editor_id,
                    id: 'uses',
                    type: 'paragraph'                    
                });
            },
            createUsesPlus = function () {
                createUses();
                $(editor_id + ' #' + uses_tab_id + ' p').html(uses.html() + buttons('ade'));
                uses.changed(function foo() {
                    use = uses.getSelected();
                    createLayersPlus();
                    return foo;
                }());
            },
            layer, layers, createLayers = function () {
                layer = use.layers[0],
                layers = layer ? new Widget({
                    pretext: 'Select a layer:',
                    container_id: editor_id,
                    id: 'layers',
                    type: 'radio-group',
                    list: use.layers,
                    selected: layer.id,
                }) : new Widget({
                    pretext: 'No layers in this use.',
                    container_id: editor_id,
                    id: 'layers',
                    type: 'paragraph'                    
                });
            },
            createLayersPlus = function () {
                createLayers();
                $(editor_id + ' #' + layers_tab_id + ' p').html(layers.html() + buttons('de'));
                layers.changed(function foo() {
                    layer = layers.getSelected();
                    createRulesPlus();
                    return foo;
                }());
            },
            rule, rules, createRules = function () {
                rule = layer ? layer.rules[0] : undefined;
                rules = rule ? new Widget({
                    pretext: 'Select a rule:',
                    container_id: editor_id,
                    id: 'rules',
                    type: 'radio-group',
                    list: layer.rules,
                    nameForItem: function (rule) {
                        return rule.getName();
                    },
                    selected: rule.id,
                }) : new Widget({
                    pretext: 'No rules in this layer.',
                    container_id: editor_id,
                    id: 'rules',
                    type: 'paragraph'                    
                });
            },
            createRulesPlus = function () {
                createRules();
                $(editor_id + ' #' + rules_tab_id + ' p').html(rules.html() + buttons('ae'));
            },
            tabs
        ;
      
        editor.dialog({
            autoOpen: false,
            height: 600,
            width: 500,
            modal: true,
            buttons: {
                Close: function () {
                    self.editor.dialog('close');
                }
            },
        });
        editor.html(element('div', {id: 'tabs'}));

        tabs = $(editor_id + ' #tabs');
        tabs.html(html);

        $(editor_id + ' #' + plans_tab_id + ' p').html(plans.html() + element('p', {id: 'buttons'}));
        plans.changed(function foo() {
            plan = plans.getSelected();
            $(editor_id + ' #' + plans_tab_id + ' #buttons').html(buttons('a', 'plan-button'));
            $(editor_id + ' #' + plans_tab_id + ' .plan-button').click(function (event) {
                var classList = this.className.split(/\s+/);
                if (classList.includes('add')) {
                    view.planCommand.notify({cmd: 'add'});
                } else if (classList.includes('edit')) {
                } else if (classList.includes('delete')) {
                }
            });
            createUsesPlus();
            return foo;
        }());
        
        tabs.tabs({
            active: 0
        });
        
        editor.dialog('open');
    });
    
    
}());
