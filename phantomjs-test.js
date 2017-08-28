var page = require('webpage').create();
page.onConsoleMessage = function(msg) {
  console.log(msg);
};
var test = 'app/t/0.html';
page.open(test, function(status) {
    console.log("Status: " + status);
    if(status !== "success") {
        console.log('not ok - test page ' + test + ' failed to open.');
    }
    phantom.exit();
});
