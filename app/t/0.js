if (!Array.prototype.find) {
    Array.prototype.find = function(predicate) {
        if (this === null) {
            throw new TypeError('Array.prototype.find called on null or undefined');
        }
        if (typeof predicate !== 'function') {
            throw new TypeError('predicate must be a function');
        }
        var list = Object(this);
        var length = list.length >>> 0;
        var thisArg = arguments[1];
        var value;
        
        for (var i = 0; i < length; i++) {
            value = list[i];
            if (predicate.call(thisArg, value, i, list)) {
                return value;
            }
        }
        return undefined;
    };
}

var is = function (got, expected, desc) {
    if (typeof got !== typeof expected) {
        console.log('not ok - got ' + typeof got + ' expected ' + typeof expected + ' - ' + desc);
    }
    if (typeof got === 'object') {
        if (got.id === expected.id) {
            console.log('ok - ' + desc);
        } else {
            console.log('not ok - got ' + got.id + ' expected ' + expected.id + ' - ' + desc);
        }
    } else {
        if (got === expected) {
            console.log('ok - ' + desc);
        } else {
            console.log('not ok - got ' + got + ' expected ' + expected + ' - ' + desc);
        }
    }
}

var test_container_selector = '#test';
var test_container = $(test_container_selector);

var test = new Widget({
    container_id: test_container_selector,
    id: 'x',
    type: 'para'
});

test_container.html(test.html());

var text = 'Hello world!';

test.html(text);

is(test_container.html(), '<p id="x">' + text + '</p>', 'para widget html');

// test a dropdown made from various types of lists
// the list items can be scalars or objects
// the selected must be the scalar, the object or the name attribute of the object

test = function (list, value, selected, descr) {
    var test = new Widget({
        container_id: test_container_selector,
        id: 'x',
        type: 'select',
        list: list,
        selected: selected
    });
    test_container.html(test.html());
    is(test.getValue(), value, descr);
    is(test.getSelected(), selected, descr);
};

var list1a = ['a','b','c'];
var list1b = {1:'a',2:'b',3:'c'};
var list1c = [1,2,3];
var list1d = {1:2,2:3,3:4};
var list2a = [{id:1, name:'a'},{id:2, name:'b'},{id:3, name:'c'}];
var list2b = {4:{id:1, name:'a'},5:{id:2, name:'b'},6:{id:3, name:'c'}};

test(list1a, 1, 'b', 'select widget with array of strings');
test(list1b, 2, 'b', 'select widget with object of strings');
test(list1c, 1, 2, 'select widget with array of numbers');
test(list1d, 2, 3, 'select widget with object of numbers');
