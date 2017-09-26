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
        {id: 1, name: mspEnum.EXCLUSIVE},
        {id: 2, name: mspEnum.BAYESIAN_NETWORK},
        {id: 2, name: mspEnum.BOXCAR},
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
    self.error = new Event(self);
    self.planCommand = new Event(self);
    self.useCommand = new Event(self);
    self.layerCommand = new Event(self);
    self.ruleCommand = new Event(self);
    self.closeUse = function (use) {};
    self.openUse = function (use) {};
}

var config, model, view, controller, editor;

function test0(auth) {
    config = new Config({
        config: {
            auth: auth
        },
        klasses: klasses
    });
    model = new MSPModel({config: config});
    view = new TestView();
    controller = new MSPController({model: model, view: view, dialog: 'dialog'});
    editor = new Editor({
        selector: '#editor',
        config: config,
        model: model,
        view: view
    });
    controller.loadPlans(function () {
        editor.open()
    });
}

function test1() {
    config = new Config({
        config: {
            auth: true
        },
        plans: [
            {
                name: 'Data',
                layers: [{
                    id: 1,
                    name: 'Data layer'
                }]
            },
            {
                id: 1,
                name: 'My plan'
            }
        ],
        klasses: klasses
    });
    model = new MSPModel({config: config});
    view = new TestView();
    controller = new MSPController({model: model, view: view, dialog: 'dialog'});
    editor = new Editor({
        selector: '#editor',
        config: config,
        model: model,
        view: view
    });
    controller.loadPlans(function () {
        editor.open()
    });
}

test0(false); // cannot edit

test0(true); // can add plan, use, layer

$('#editor .add').click();
$('#dialog #plans-name').val('a');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();
is(model.plan.name, 'a', 'Create a plan.');

$('#editor #uses-tab a').trigger('click');
$('#editor #uses .add').trigger('click');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();
is(model.plans[0].uses[0].name, 'Fish farming', 'Create a use.');

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .add').trigger('click');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();
is(model.plans[0].uses[0].layers[0].name, 'Suitability', 'Create a layer.');

test1(); // can add rules

$('#editor #uses-tab a').trigger('click');
$('#editor #uses .add').trigger('click');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();

$('#editor #layers-tab a').trigger('click');
$('#editor #layers .add').trigger('click');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();

$('#editor #rules-tab a').trigger('click');
$('#editor #rules .add').trigger('click');
$('.ui-dialog')
    .filter(':first')
    .find('.ui-dialog-buttonpane')
    .find('.ui-button')
    .get(0)
    .click();

is(model.plans[0].uses[0].layers[0].rules[0].dataset.name, 'Data layer', 'Create a rule.');
