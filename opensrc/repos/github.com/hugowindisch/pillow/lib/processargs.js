/**
    processargs.js

    Copyright (C) 2012 Hugo Windisch

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
*/

// Note: This could be replaced by another existing node module arg or
// command-parser or whatever or externalized to another module

/**
    Parses the command line for creating the options object.
*/
function processArgs(args, filters) {
    var options = { },
        resopt;

    function concatOptions(o) {
        if (o) {
            Object.keys(o).forEach(function (n) {
                var p = o[n];
                // concatenate arrays
                if (p instanceof Array) {
                    if (!(options[n] instanceof Array)) {
                        options[n] = [];
                    }
                    options[n] = options[n].concat(p);

                } else {
                    options[n] = p;
                }
            });
        }
    }

    // filter the args
    args.forEach(function (a) {
        filters.some(function (f) {
            var m = f.filter.exec(a);
            if (m) {
                concatOptions(f.action(m, filters));
                return true;
            }
            return false;
        });
    });

    return options;
}
/**
    Pads a string.
*/
function pad(str, l) {
    while (str.length < l) {
        str += ' ';
    }
    return str;
}

/**
    Prints the args to the console
*/
function showHelp(filters, header, footer) {
    var maxl = 0;
    // the header
    if (header) {
        console.log(header);
    }
    // the options
    filters.forEach(function (f) {
        if (f.name.length > maxl) {
            maxl = f.name.length;
        }
    });
    filters.forEach(function (f) {
        console.log(pad(f.name, maxl) + ': ' + f.help);
    });
    // the footer
    if (footer) {
        console.log(footer);
    }

}

exports.processArgs = processArgs;
exports.showHelp = showHelp;
