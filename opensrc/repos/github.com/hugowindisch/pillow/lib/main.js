/**
    main.js

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
/*jslint nomen: true */
"use strict";

var http = require('http'),
    scan = require('./scan'),
    args = require('./args'),
    processargs = require('./processargs'),
    urls = require('./urls'),
    handlers = require('./handlers'),
    serve = require('./serve');

// library support
exports.makeAndServe = handlers.makeAndServe;
exports.serve = serve.serve;
exports.getMiddleWare = serve.getMiddleWare;
exports.urls = urls.urls;
exports.makeAll = scan.makeAll;
exports.makePackage = scan.makePackage;
exports.makeFile = scan.makeFile;
exports.processArgs = processargs.processArgs;
exports.showHelp = processargs.showHelp;
exports.argFilters = args.argFilters;
exports.fixOptions = args.fixOptions;
exports.findPackages = scan.findPackages;
