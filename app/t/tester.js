var is = function (got, expected, desc) {
    if (typeof got !== typeof expected) {
        console.log('error - got ' + typeof got + ' expected ' + typeof expected + ' - ' + desc);
    } else {
        if (typeof got === 'object') {
            if (got.id === expected.id) {
                console.log('ok - ' + desc);
            } else {
                console.log('error - got ' + got.id + ' expected ' + expected.id + ' - ' + desc);
            }
        } else {
            if (got === expected) {
                console.log('ok - ' + desc);
            } else {
                console.log('error - got ' + got + ' expected ' + expected + ' - ' + desc);
            }
        }
    }
}
