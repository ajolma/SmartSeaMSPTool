'use strict';

var klasses = {
    use_class: [
        {id: 1, name: 'Fish farming'},
        {id: 2, name: 'Wind park'},
    ],
    layer_class: [
        {id: 1, name: 'Suitability'},
    ],
    rule_class: [
        {id: 1, name: msp.enum.EXCLUSIVE},
        {id: 2, name: msp.enum.BOXCAR},
        {id: 3, name: msp.enum.BAYESIAN_NETWORK},
    ],
    activity: '',
    palette: [
        {id: 1, name: 'Green'},
    ],
    op: [
        {id: 1, name: '>'},
        {id: 2, name: '=='},
        {id: 3, name: 'NOT'},
    ],
};

function TestView() {
    var self = this;
    self.error = new msp.Event(self);
    self.planCommand = new msp.Event(self);
    self.useCommand = new msp.Event(self);
    self.layerCommand = new msp.Event(self);
    self.ruleCommand = new msp.Event(self);
    self.closeUse = function (use) {};
    self.openUse = function (use) {};
}

function test0(auth) {
    var config = new msp.Config({
        config: {
            auth: auth
        },
        klasses: klasses
    }),
        model = new msp.Model({config: config}),
        view = new TestView(),
        controller = new msp.Controller({model: model, view: view, dialog: 'dialog'}),
        editor = new msp.Editor({
            selector: '#editor',
            config: config,
            model: model,
            view: view
        });
    controller.loadPlans(function () {
        editor.open()
    });
    return model;
}

function test1(layers) {
    var config = new msp.Config({
        config: {
            auth: true
        },
        plans: [{
            name: 'Data',
            layers: layers
        },{
            id: 1,
            name: 'My plan'
        }],
        klasses: klasses,
        networks : [{
            id: 1,
            name: 'Network',
            nodes: [{
                name: 'Node',
                states: ['State 1', 'State 2']
            },{
                name: 'Node 5',
                states: ['a', 'b', 'c', 'd', 'e', 'f']
            }]
        }]
    }),
        model = new msp.Model({config: config}),
        view = new TestView(),
        controller = new msp.Controller({model: model, view: view, dialog: 'dialog'}),
        editor = new msp.Editor({
            selector: '#editor',
            config: config,
            model: model,
            view: view
        });
    controller.loadPlans(function () {
        editor.open()
    });
    return model;
}

var select_tab_cmd = function (tab, cmd) {
    $('#editor #' + tab + '-tab a').trigger('click');
    $('#editor #' + tab + ' .' + cmd).trigger('click');
};

var press_button = function (nr) {
    $('.ui-dialog').filter(':first').find('.ui-dialog-buttonpane').find('.ui-button').get(nr).click();
};

function create_plan_use_layer(model) {
    $('#editor .add').click();
    $('#dialog #plans-name').val('a');
    press_button(0); // Ok
    
    is(model.plan.name, 'a', 'Create a plan.');

    select_tab_cmd('uses', 'add');
    press_button(0); // Ok
    
    is(model.plans[0].uses[0].name, 'Fish farming', 'Create a use.');

    select_tab_cmd('layers', 'add');
    press_button(0); // Ok
    
    is(model.plans[0].uses[0].layers[0].name, 'Suitability', 'Create a layer.');
}

function run_layer_and_rule_tests(model) {
    var value;
    select_tab_cmd('uses', 'add');
    press_button(0); // Ok

    select_tab_cmd('layers', 'add');
    press_button(0); // Ok

    select_tab_cmd('rules', 'add');
    press_button(0); // Ok
    
    is(model.plans[0].uses[0].layers[0].rules[0].dataset.name, 'Data layer', 'Create a rule.');
    
    $('#editor #rules .edit').trigger('click');
    if (model.datasets.layers[0].binary) {
        // skip the rest since dataset is binary
        return;
    } else if (model.datasets.layers[0].semantics) {
        value = 2;
        $('.ui-dialog #thrs').val(value).trigger('change');
    } else if (model.datasets.layers[0].data_type === msp.enum.REAL) {
        value = 2.5;
        $('.ui-dialog #thrs-value').val(value).trigger('change');
    } else {
        value = 2;
        $('.ui-dialog #thrs').spinner('value', value);
    }
    press_button(0); // Apply
    press_button(1); // Close
    
    is(model.plans[0].uses[0].layers[0].rules[0].value, value, 'Edit rule.');
    
    $('#editor #rules .delete').trigger('click');
    press_button(0);
    
    is(model.plans[0].uses[0].layers[0].rules.length, 0, 'Delete rule.');

    select_tab_cmd('layers', 'delete');
    press_button(0);
    
    is(model.plans[0].uses[0].layers.length, 0, 'Delete layer.');

    $('#editor #layers .add').trigger('click');
    $('#dialog #layer-rule-class').val('1');
    press_button(0);
    
    is(model.plans[0].uses[0].layers[0].rule_class, 'boxcar', 'Add a boxcar layer.');

    select_tab_cmd('rules', 'add');
    press_button(0);
    
    is(model.plans[0].uses[0].layers[0].rules[0].dataset.name, 'Data layer', 'Create a boxcar rule.');
    
    $('#editor #rules .edit').trigger('click');
    if (model.datasets.layers[0].semantics) {
        $('.ui-dialog #x2').val(value).trigger('change');
    } else if (model.datasets.layers[0].data_type === msp.enum.REAL) {
        $('.ui-dialog #x2-value').val(value).trigger('change');
    } else {
        $('.ui-dialog #x2').spinner('value', value);
    }
    press_button(0);
    press_button(1);
    
    is(model.plans[0].uses[0].layers[0].rules[0].boxcar_x3, value, 'Edit boxcar rule.');

    select_tab_cmd('layers', 'delete');
    press_button(0);

    if (model.datasets.layers[0].data_type === msp.enum.REAL) {
        // skip Bayesian network layer and rule since dataset is real
        return;
    }
    
    $('#editor #layers .add').trigger('click');
    $('#dialog #layer-rule-class').val('2').trigger('change');
    press_button(0);
    
    is(model.plans[0].uses[0].layers[0].rule_class, msp.enum.BAYESIAN_NETWORK, 'Add a Bayesian network layer.');

    select_tab_cmd('rules', 'add');
    press_button(0);
    
    is(model.plans[0].uses[0].layers[0].rules[0].node, 'Node 5', 'Create a Bayesian network rule.');
    
    $('#editor #rules .edit').trigger('click');
    $('.ui-dialog #rule-offset').spinner('value', -1);
    press_button(0);
    press_button(1);
    
    is(model.plans[0].uses[0].layers[0].rules[0].state_offset, -1, 'Edit Bayesian network rule.');

}

test0(false); // cannot edit

create_plan_use_layer(test0(true)); // can add plan, use, layer

run_layer_and_rule_tests(test1([{
    id: 1,
    name: 'Data layer',
    data_type: msp.enum.INTEGER,
    min_value: 0,
    max_value: 5
}]));

run_layer_and_rule_tests(test1([{
    id: 1,
    name: 'Data layer',
    data_type: msp.enum.REAL,
    min_value: 0,
    max_value: 5
}]));

run_layer_and_rule_tests(test1([{
    id: 1,
    name: 'Data layer',
    data_type: msp.enum.INTEGER,
    min_value: 1,
    max_value: 3,
    semantics: {
        1: 'one',
        2: 'two',
        3: 'three',
    }
}]));

run_layer_and_rule_tests(test1([{
    id: 1,
    name: 'Data layer',
    data_type: msp.enum.INTEGER,
    min_value: 0,
    max_value: 1,
}]));
