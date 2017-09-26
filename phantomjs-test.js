phantom.onError = function(msg, trace) {
    var msgStack = ['PHANTOM ERROR: ' + msg];
    if (trace && trace.length) {
        msgStack.push('TRACE:');
        trace.forEach(function(t) {
            msgStack.push(
                ' -> '
                    + (t.file || t.sourceURL)
                    + ': '
                    + t.line
                    + (t.function ? ' (in function ' + t.function +')' : '')
            );
        });
    }
    console.error(msgStack.join('\n'));
    phantom.exit(1);
};

var page = require('webpage').create();

page.onError = function(msg, trace) {
    var msgStack = ['ERROR: ' + msg];
    if (trace && trace.length) {
        msgStack.push('TRACE:');
        trace.forEach(function(t) {
            msgStack.push(
                ' -> '
                    + t.file
                    + ': '
                    + t.line
                    + (t.function ? ' (in function "' + t.function +'")' : ''));
        });
    }
    console.error(msgStack.join('\n'));
};

page.onConsoleMessage = function(msg) {
    console.log(msg);
};

var dir = 'app/t/';
var tests = ['0.html' ,'1.html'];

var run_tests = function (index) {
    if (!index) {
        index = 0;
    }
    if (index >= tests.length) {
        phantom.exit();
    }
    console.log(tests[index] + ':');
    page.open(dir + tests[index], function(status) {
        if (status === "success") {
            run_tests(index+1);
        } else {
            console.log('error - test page ' + tests[index] + ' failed to open.');
            phantom.exit(1);
        }
    });
};

run_tests();
