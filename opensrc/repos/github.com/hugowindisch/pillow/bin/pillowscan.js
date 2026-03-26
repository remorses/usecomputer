#! /usr/bin/env node
/**
    pillowscan.js

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

var pillow = require('../'),
    options = pillow.fixOptions(
        pillow.processArgs(
            process.argv.slice(2),
            pillow.argFilters
        )
    );

if (!options.help) {
    if (options.srcFolder.length === 0) {
        console.log('--help for options');
    } else if (options.only) {
        pillow.makeFile(options, options.only, function (err) {
            if (err) {
                console.log(err);
            }
        });
    } else {
        pillow.makeAll(options, function (err) {
            if (err) {
                console.log(err);
            }
        });
    }
}
