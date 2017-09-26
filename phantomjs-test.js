var page = require('webpage').create();

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onError = function (msg, trace) {
    console.log(msg);
    trace.forEach(function(item) {
        console.log('  ', item.file, ':', item.line);
    });
};

page.onLoadFinished = function(status) {
    console.log('Load Finished: ' + status);
};
page.onLoadStarted = function() {
    console.log('Load Started');
};

var test = 'app/t/0.html';

page.open(test, function(status) {
    console.log("Status: " + status);
    if(status !== "success") {
        console.log('not ok - test page ' + test + ' failed to open.');
    }
    phantom.exit();
});
