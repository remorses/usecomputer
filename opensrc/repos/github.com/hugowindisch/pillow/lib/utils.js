/**
    utils.js

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
var path = require('path'),
    fs = require('fs'),
    async = require('async'),
    sep = path.sep || '/';
exports.sep = sep;
exports.assetExt = {
    'jpg': true,
    'png': true,
    'gif': true,
    'html': true,
    'json': true,
    'css': true,
    'vis': false,
    'md': true
};
exports.lintOptions = {
    bitwise: true,
    browser: true,
    cap: true,
    css: true,
    devel: true,
    eqeqeq: true,
    es5: true,
    forin: true,
    fragment: true,
    immed: true,
    newcap: true,
    nomen: true,
    on: true,
    onevar: true,
    plusplus: true,
    regexp: true,
    undef: true,
    indent: 4,
    white: true,
    predef: [
        'require',
        'console',
        'process',
        'exports',
        'emit',
        'module'
    ]
};

// FIXME: maybe there is a normal (non convoluted) way of dealing with
// the drain thing (I think that there is a problem if you neglect the
// return code from write and the drain event)
// FIXME: This whole thing sucks... (streaming everything would be better)
function safeWrite(stream, d, end) {
/*
    if (stream.queued) {
        stream.queued.push({d: d, end: end});
    } else if (stream.write(d)) {
        if (end) {
            stream.end();
        }
    } else {
        stream.queued = []; //[{d: d, end: end}];
        if (end) {
            stream.end();
        }
        stream.once('drain', function () {
            var q = stream.queued;
            delete stream.queued;
            q.forEach(function (b) {
                safeWrite(stream, b.d, b.end);
            });
        });
    }
*/
    if (!stream.absurdBuf) {
        stream.absurdBuf = d;
    } else {
        stream.absurdBuf += d;
    }
    if (end) {
        var absurdBuf = stream.absurdBuf;
        delete stream.absurdBuf;
        if (stream.write(absurdBuf)) {
            stream.end();
        } else {
            stream.once('drain', function () {
                stream.end();
            });
        }
    }
}

/**
    Fixes windows path nonsense
*/
function unWindowsifyPath(p) {
    // windows nonsense
    if (sep !== '/') {
        p = p.split(sep).join('/');
    }
    return p;
}


/**
    Concatenates two objects.
*/
function concatObject(dst, src) {
    var k;
    for (k in src) {
        if (src.hasOwnProperty(k)) {
            dst[k] = src[k];
        }
    }
    return dst;
}

/**
    Creates a folder if the folder does not already exist.
*/
function createFolder(foldername, cb) {
    var fn = path.resolve(foldername),
        basedir = path.dirname(fn);

    function makeUnexistingDir(dirname, cb) {
        fs.exists(dirname, function (exists) {
            fs.mkdir(dirname, '0775', function (err) {
                var eExist = /^EEXIST/;
                if (!err || eExist.test(err.message)) {
                    err = null;
                }
                cb(err);
            });
        });
    }
    fs.exists(basedir, function (exists) {
        if (!exists) {
            createFolder(basedir, function (err) {
                if (err) {
                    return cb(err);
                }
                makeUnexistingDir(fn, cb);
            });
        } else {
            makeUnexistingDir(fn, cb);
        }
    });
}

/**
    Copies a file.
*/
function copyFile(from, to, cb) {
    fs.readFile(from, function (err, data) {
        if (err) {
            return cb(err);
        }
        createFolder(to, function (err) {
            var dstFile = path.join(to, path.basename(from));
            if (err) {
                return cb(err);
            }
            fs.writeFile(dstFile, data, function (err) {
                cb(err);
            });
        });
    });
}

/**
    Updates a file (copies it if it does not exist or if it is
    out dated).
*/
function copyFileIfOutdated(from, to, cb) {
    async.map(
        [from, path.join(to, path.basename(from))],
        fs.stat,
        function (err, stats) {
            if (err || stats[1].mtime.getTime() < stats[0].mtime.getTime()) {
                copyFile(from, to, cb);
            } else {
                // nothing to do
                cb(null);
            }
        }
    );
}

/**
    Checks if a file is older than a given date
*/
function checkOlderOrInvalid(fn, date, cb) {
    fs.stat(fn, function (err, stats) {
        cb(null, err || (stats.mtime.getTime() < date.getTime()));
    });
}

/**
    Finds files that matches a given pattern in an object
    { filename: filestat }
*/
function filterStats(stats, regexp) {
    var res = {};
    Object.keys(stats).forEach(function (s) {
        if (regexp.test(s)) {
            res[s] = stats[s];
        }
    });
    return res;
}

/**
    Publishes the pillow file itself. This is a simple file copy.
*/
function publishPillow(
    outputfolder,
    cb
) {
    copyFileIfOutdated(path.join(__dirname, 'pillow.js'), outputfolder, cb);
}

/**
    Finds the latest date for a given regexp
    { filename: filestat }
*/
function getMostRecent(stats, regexp) {
    var s = filterStats(stats, regexp),
        ret = new Date();
    ret.setTime(0);
    Object.keys(s).forEach(function (k) {
        var stat = s[k];
        if (stat.mtime.getTime() > ret.getTime()) {
            ret = stat.mtime;
        }
    });
    return ret;
}

/**
    Returns a package map that contains a package an all its recursive
    dependencies.
*/
function getPackageDependencies(packageMap, packageName, includeTestDeps) {
    function gd(res, name) {
        var p = packageMap[name],
            dep;
        if (p) {
            // don't re process if already there (circular deps)
            if (!res[name]) {
                res[name] = p;
                // normal dependencies
                dep = p.json.dependencies;
                if (dep) {
                    Object.keys(dep).forEach(function (k) {
                        // FIXME we should validate versions
                        gd(res, k);
                    });
                }
                // test dependencies
                dep = p.json.testDependencies;
                if (includeTestDeps && dep) {
                    dep.forEach(function (k) {
                        gd(res, k);
                    });
                }
            }
        } else {
            throw new Error("Missing Package " + name);
        }
    }
    var res = {};
    gd(res, packageName);
    return res;
}

/**
    Returns a unified { filename: stats} for a package map.
*/
function getFileMap(packageMap) {
    var res = {};
    Object.keys(packageMap).forEach(function (k) {
        var p = packageMap[k];
        concatObject(res, p.stats);
    });
    return res;
}


exports.safeWrite = safeWrite;
exports.unWindowsifyPath = unWindowsifyPath;
exports.concatObject = concatObject;
exports.createFolder = createFolder;
exports.copyFile = copyFile;
exports.copyFileIfOutdated = copyFileIfOutdated;
exports.checkOlderOrInvalid = checkOlderOrInvalid;
exports.filterStats = filterStats;
exports.publishPillow = publishPillow;
exports.getMostRecent = getMostRecent;
exports.getPackageDependencies = getPackageDependencies;
exports.getFileMap = getFileMap;
