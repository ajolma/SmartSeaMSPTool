var test_container_selector = '#test';
var test_container = $(test_container_selector);

var test = new Widget({
    container: test_container_selector,
    id: 'x',
    type: 'paragraph'
});

test_container.html(test.html());

var text = 'Hello world!';

test.html(text);

is(test_container.html(), '<p id="x">' + text + '</p>', 'paragraph widget html');

// test a dropdown made from various types of lists
// the list items can be scalars or objects
// the selected must be the scalar, the object, or the name attribute of the object

test = function (list, selected, descr, exp) {
    var test = new Widget({
        container: test_container_selector,
        id: 'x',
        type: 'select',
        list: list,
        selected: selected
    });
    test_container.html(test.html());
    is(test.getSelected(), exp || selected, descr);
};

var list1a = ['a', 'b', 'c'];
var list1b = {1:'a', 2:'b', 3:'c'};
var list1c = [1, 2, 3];
var list1d = {1:2, 2:3, 3:4};
var list1e = {'1':'a', '2':'b', '3':'c'};
var list1f = {'1':2, '2':3, '3':4};

var sel = {id:2, name:'b'}
var list2a = [{id:1, name:'a'},sel,{id:3, name:'c'}];
var list2b = {4:{id:1, name:'a'},5:sel,6:{id:3, name:'c'}};

test(list1a, 'b', 'select widget with array of strings');
test(list1b, 'b', 'select widget with object of numbers => strings');
test(list1c, 2, 'select widget with array of numbers');
test(list1d, 3, 'select widget with object of numbers => numbers');
test(list1e, 'b', 'select widget with object of strings => strings');
test(list1f, 3, 'select widget with object of strings => numbers');

test(list2a, sel, 'select from array of objects with object');
test(list2a, 'b', 'select from array of objects with name', sel);

test(list2b, sel, 'select from object of objects with object');
test(list2b, 'b', 'select from object of objects with name', sel);
