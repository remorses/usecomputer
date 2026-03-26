/**
    serve.js

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
var http = require('http'),
    url = require('url');

/**
    This will act as a middleware that should work ok in Connect or Express.
*/
function getMiddleWare(urls, options) {
    return function (req, res, next) {
        var i,
            l = urls.length,
            m,
            h,
            parsedUrl = url.parse(req.url),
            pathname = parsedUrl.pathname,
            o,
            handled = false;
        function setUnHandled() {
            handled = false;
        }
        function getOptions() {
            return typeof options === 'function' ? options(req, res) : options;
        }

        for (i = 0; i < l && !handled; i += 1) {
            h = urls[i];
            m = h.filter.exec(pathname);
            if (m) {
                handled = true;
                o = getOptions();
                // allow the disabling of the whole middleware
                if (!o.pass) {
                    h.handler(req, res, { options: o, match: m, next: setUnHandled });
                }
            }
        }
        if (!handled && next) {
            next();
        }
    };
}

/**
    This function will serve the 'urls' mappings ({regexp: function})
    passing req, res and the match from the regexp to function.
*/
function serve(urls, options) {
    var mw = getMiddleWare(urls, options),
        port = options.port || 1337,
        srv;
    srv = http.createServer(function (req, res) {
        var processed = true;
        function next() {
            processed = false;
        }
        try {
            mw(req, res, next);
            if (!processed) {
                res.writeHead(404);
                res.end();
            }
        } catch (e) {
            console.log("Error " + e);
            res.writeHead(500);
            res.end();
        }
    }).listen(port, '0.0.0.0');
    console.log('Server running on local host port ' + port);
    return srv;
}

// library support
exports.serve = serve;
exports.getMiddleWare = getMiddleWare;
