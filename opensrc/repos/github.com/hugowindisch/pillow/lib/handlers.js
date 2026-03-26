/**
    urls.js

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
/*jslint regexp: false */
var async = require('async'),
    scan = require('./scan'),
    fs = require('fs'),
    path = require('path'),
    mimetypes = {
        jpg: 'image/jpeg',
        gif: 'image/gif',
        png: 'image/png',
        html: 'text/html',
        json: 'application/json',
        css: 'text/css',
        js: 'application/ecmascript',
        md: 'text/x-markdown'
    };

/**
    Handler for making files on the fly and serving them.
*/
exports.makeAndServe = function (req, res, cxt) {
    var match = cxt.match,
        options = cxt.options;

    async.waterfall([
        function (cb) {
            scan.makeFile(options, match[1], cb);
        },
        function (data) {
            var extRE = /\.([^.]*)$/,
                m = extRE.exec(match[1]),
                ext = m ? m[1] : null,
                mime,
                mustCache = false,
                filePath = path.join(options.dstFolder, match[1]),
                rs;

            if (m) {
                rs = fs.createReadStream(filePath);
                mime = mimetypes[ext.toLowerCase()] || mime;

                // cache some packages
                if (options.cache) {
                    options.cache.forEach(function (packageName) {
                        var m = new RegExp('^' + packageName + '\/');
                        if (m.test(match[1])) {
                            mustCache = true;
                        }
                    });
                }
                // cache some extensions
                if (options.cacheext && ext) {
                    options.cacheext.forEach(function (extToCache) {
                        if (extToCache === ext) {
                            mustCache = true;
                        }
                    });
                }

                rs.on('error', function (err) {
                    res.writeHead(404);
                    res.end();
                });

                rs.once('open', function (fd) {
                    var headers = {'Content-Type': mime};
                    if (mustCache) {
                        headers['Cache-Control'] = 'max-age=2592000';
                    }
                    res.writeHead(200, headers);
                });
                rs.pipe(res);
            } else {
                res.writeHead(404);
                res.end();
            }
        }
    ], function (err) {
        if (err) {
            res.writeHead(404);
            res.end();
        }
    });
};
