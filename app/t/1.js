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

function test1() {
    var config = new msp.Config({
        config: {
            auth: true
        },
        plans: [{
            name: 'Data',
            layers: [{
                id: 1,
                name: 'Data layer',
                binary: false,
                data_type: msp.enum.INTEGER, // alt: REAL, semantics
                min_value: 0,
                max_value: 5
            }]
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

var press_button = function (nr) {
    $('.ui-dialog').filter(':first').find('.ui-dialog-buttonpane').find('.ui-button').get(nr).click();
};

var model;

model = test0(false); // cannot edit

model = test0(true); // can add plan, use, layer

$('#editor .add').click();
$('#dialog #plans-name').val('a');
press_button(0); // Ok

is(model.plan.name, 'a', 'Create a plan.');

$('#editor #uses-tab a').trigger('click');
$('#editor #uses .add').trigger('click');
press_button(0); // Ok

is(model.plans[0].uses[0].name, 'Fish farming', 'Create a use.');

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .add').trigger('click');
press_button(0); // Ok

is(model.plans[0].uses[0].layers[0].name, 'Suitability', 'Create a layer.');

model = test1(); // can add rules

$('#editor #uses-tab a').trigger('click');
$('#editor #uses .add').trigger('click');
press_button(0); // Ok

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .add').trigger('click');
press_button(0); // Ok

$('#editor #rules-tab a').trigger('click');
$('#editor #rules .add').trigger('click');
press_button(0); // Ok

is(model.plans[0].uses[0].layers[0].rules[0].dataset.name, 'Data layer', 'Create a rule.');

$('#editor #rules .edit').trigger('click');
$('.ui-dialog #thrs').spinner('value', 2);
press_button(0); // Apply
press_button(1); // Close

is(model.plans[0].uses[0].layers[0].rules[0].value, 2, 'Edit rule.');

$('#editor #rules .delete').trigger('click');
press_button(0);

is(model.plans[0].uses[0].layers[0].rules.length, 0, 'Delete rule.');

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .delete').trigger('click');
press_button(0);

is(model.plans[0].uses[0].layers.length, 0, 'Delete layer.');

$('#editor #layers .add').trigger('click');
$('#dialog #layer-rule-class').val('1');
press_button(0);

is(model.plans[0].uses[0].layers[0].rule_class, 'boxcar', 'Add a boxcar layer.');

$('#editor #rules-tab a').trigger('click');
$('#editor #rules .add').trigger('click');
press_button(0);

is(model.plans[0].uses[0].layers[0].rules[0].dataset.name, 'Data layer', 'Create a boxcar rule.');

$('#editor #rules .edit').trigger('click');
$('.ui-dialog #x2').spinner('value', 2);
press_button(0);
press_button(1);

is(model.plans[0].uses[0].layers[0].rules[0].boxcar_x3, 2, 'Edit boxcar rule.');

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .delete').trigger('click');
press_button(0);

$('#editor #layers .add').trigger('click');
$('#dialog #layer-rule-class').val('2').trigger('change');
press_button(0);

is(model.plans[0].uses[0].layers[0].rule_class, msp.enum.BAYESIAN_NETWORK, 'Add a Bayesian network layer.');

$('#editor #rules-tab a').trigger('click');
$('#editor #rules .add').trigger('click');
press_button(0);

is(model.plans[0].uses[0].layers[0].rules[0].node, 'Node 5', 'Create a Bayesian network rule.');

$('#editor #rules .edit').trigger('click');
$('.ui-dialog #rule-offset').spinner('value', -1);
press_button(0);
press_button(1);

is(model.plans[0].uses[0].layers[0].rules[0].state_offset, -1, 'Edit Bayesian network rule.');
