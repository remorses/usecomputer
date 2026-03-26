/**
    make.js

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

var fs = require('fs'),
    path = require('path'),
    async = require('async'),
    jqtpl = require('jqtpl'),
    jsmin = require('jsmin'),
    jslint = require('JSLint-commonJS'),
    dox = require('dox'),
    utils = require('./utils'),
    sep = utils.sep,
    assetExt = utils.assetExt,
    lintOptions = utils.lintOptions,
    safeWrite = utils.safeWrite,
    unWindowsifyPath = utils.unWindowsifyPath,
    concatObject = utils.concatObject,
    copyFileIfOutdated = utils.copyFileIfOutdated,
    checkOlderOrInvalid = utils.checkOlderOrInvalid,
    filterStats = utils.filterStats,
    publishPillow = utils.publishPillow,
    getMostRecent = utils.getMostRecent,
    getPackageDependencies = utils.getPackageDependencies,
    getFileMap = utils.getFileMap;

// synchronously load the templates that we need when this module is loaded
jqtpl.template(
    'srcTemplate',
    fs.readFileSync(
        path.join(__dirname, 'templates/src.js')
    ).toString()
);
jqtpl.template(
    'headerTemplate',
    fs.readFileSync(
        path.join(__dirname, 'templates/header.js')
    ).toString()
);
jqtpl.template(
    'componentTemplate',
    fs.readFileSync(
        path.join(__dirname, 'templates/component.html')
    ).toString()
);


/**
    Publishes an asset such as a jpg or png by copying it in the
    deployment directory.
*/
function publishAsset(
    options,
    modulename,
    modulerootfolder,
    filename,
    cb
) {
    var dstfile = path.join(
            options.dstFolder,
            modulename,
            filename.slice(modulerootfolder.length)
        ),
        dstfolder = path.dirname(dstfile),
        getExt = /\.(\w+)$/,
        m = getExt.exec(filename);

    if (m && assetExt[m[1].toLowerCase()]) {
        copyFileIfOutdated(filename, dstfolder, cb);
    } else {
        // nothing to do
        cb(null);
    }
}

/**
    Loads a js file (as text), packages it in a module closure and adds
    this module closure to a module.
*/
function publishJSFile(
    modulename,
    modulerootfolder,
    filename,
    dependencies,
    jsstream,
    optMini,
    test,
    cb
) {
    // we want to split the path
    //filename.split(
    var pillowPath = modulename + filename.slice(modulerootfolder.length, -3),
        isTest = filename.indexOf(modulerootfolder + '/test/') === 0;
    // fix windows nonsense
    pillowPath = unWindowsifyPath(pillowPath);

    // if this is a test file, only include it in test mode.
    if (isTest && !test) {
        return cb(null);
    }

    async.waterfall([
        function (cb) {
            fs.readFile(filename, cb);
        },
        function (filecontent, cb) {
            var indented = filecontent.toString().split('\n').map(
                    function (line) {
                        return '    ' + line;
                    }
                ).join('\n');

            cb(null, jqtpl.tmpl('srcTemplate', {
                modulename: modulename,
                filepath: pillowPath,
                code: indented,
                dependencies: ['require', 'exports', 'module'].concat(dependencies)
            }));

        },
        function (out, cb) {
            // optionally uglify (do not mangle)
            var ast;
            if (optMini) {
                out = jsmin.jsmin(out);
            }
            // write the result
            safeWrite(jsstream, out, false);
            cb(null);
        }
    ], cb);
}

/**
    Finds by guessing the module path.
    These will be tried in order:
        packagname.js
        /lib/packagename.js

    getMainModulePath
*/
function getMainModulePath(details) {
    var regExp,
        res;
    if (details.json.main) {
        // tolerate a .js or no .js at the end of the main file
        if (/\.js$/.test(details.json.main)) {
            res = details.json.main.slice(0, -3);
        } else {
            res = details.json.main;
        }
    } else {
        regExp = new RegExp(details.name + '\\.js$');
        details.js.forEach(function (n) {
            var s;
            if (regExp.test(n)) {
                s = n.slice(details.dirname.length + 1, -3);
                if (!res || s.length < res.length) {
                    res = s;
                }
            }
        });
    }
    return res;
}

/**
    Publishes the documentation as a json file generated by dox.
*/
function publishDox(
    options,
    details,
    packageMap,
    deps,
    cb
) {
    var publishdir = path.join(options.dstFolder, details.name),
        publishJsStream = path.join(publishdir, details.name + '.js'),
        publishDOX = path.join(publishdir, details.name + '.dox.json');

    async.waterfall([
        function (cb) {
            fs.readFile(publishJsStream, 'utf8', cb);
        },
        function (buf, cb) {
            var obj;
            // I think that dis dox thing crashes when there are no
            // comments at all.
            try {
                obj = dox.parseComments(buf); /*, { raw: program.raw }*/
            } catch (e) {
                obj = [];
            }
            fs.writeFile(
                publishDOX,
                JSON.stringify(obj, null, 4),
                cb
            );
        }
    ], function (err) {
        cb(err);
    });
}

/**
    Publishes all the js files in the package (the files are combined into
    one single js file).
*/
function publishJSFiles(
    options,
    details,
    packageMap,
    deps,
    test,
    cb
) {
    var publishdir = path.join(options.dstFolder, details.name),
        publishJsStream = path.join(
            publishdir,
            details.name + (test ? '.test.js' : '.js')
        ),
        stream = fs.createWriteStream(publishJsStream),
        dependencies = [ ];
    if (deps) {
        Object.keys(deps).forEach(function (d) {
            if (d !== details.name) {
                dependencies.push(d);
            }
        });
    }

    // possible post processing of the underlying stream
    stream.on('close', function () {
        cb(null);
    });

    stream.once('error', function (e) {
        cb(e);
    });

    // process all the js files
    async.forEach(details.js, function (f, cb) {
        publishJSFile(
            details.name,
            details.dirname,
            f,
            dependencies,
            stream,
            options.minify,
            test,
            cb
        );
    }, function (err) {
        if (err) {
            stream.destroy();
            return cb(err);
        }
        safeWrite(stream, jqtpl.tmpl('headerTemplate', {
            modulename: details.name,
            dependencies: dependencies,
            modulepath: '/' + details.name + '/' + getMainModulePath(details)
        }), true);
    });
}

/**
    Publishes the lint.
*/
function publishLint(
    options,
    details,
    packageMap,
    deps,
    cb
) {
    var publishdir = path.join(options.dstFolder, details.name),
        publishLintFilename = path.join(publishdir, details.name + '.lint.json'),
        results = {};

    // process all the js files
    async.forEach(details.js, function (filename, cb) {
        fs.readFile(filename, 'utf8', function (err, content) {
            var res;
            if (err) {
                return cb(err);
            }
            res = jslint(content, lintOptions);
            if (!res) {
                res = jslint.errors;
            }
            results[filename] = res;
            cb(null);

        });
    }, function (err) {
        if (err) {
            return cb(err);
        }
        fs.writeFile(
            publishLintFilename,
            JSON.stringify(results, null, 4),
            cb
        );
    });
}

/**
    Publishes the html that allows to run the package in a browser
    using a standalone statically loaded html.
*/
function publishHtml(
    options,
    details,
    packageMap,
    deps,
    cssFileMap,
    cb
) {
    // we need to load all components
    var dependencies = [ ],
        cssFiles = [];
    if (deps) {
        Object.keys(deps).forEach(function (d) {
            dependencies.push(d + '/' + d + '.js');
        });
        Object.keys(cssFileMap).forEach(function (k) {
            var details = cssFileMap[k].details,
                vfn = (details.name + k.slice(details.dirname.length));
            cssFiles.push(vfn.split('\\').join('/'));
        });
    }
    fs.writeFile(
        path.join(options.dstFolder, details.name + '.html'),
        jqtpl.tmpl('componentTemplate', {
            dependencies: dependencies,
            css: cssFiles,
            main: details.name,
            jquery: options.jquery ? path.basename(options.jquery) : null
        }),
        cb
    );
}


////////////////////////////////
// regenerate the JSFiles then the dox
function makeJSFilesThenDOXFile(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    // regenerate the DOX file
    function makeDOXFile(cb) {
        if (options.dox) {
            checkOlderOrInvalid(
                path.join(options.dstFolder, details.name, details.name + '.dox.json'),
                mostRecentJSDate,
                function (err, older) {
                    if (older) {
                        publishDox(options, details, packageMap, deps, cb);
                    } else {
                        cb(err);
                    }
                }
            );
        } else {
            cb(null);
        }
    }

    // regenerate JSFiles
    function makeJSFiles(cb) {
        checkOlderOrInvalid(
            path.join(options.dstFolder, details.name, details.name + '.js'),
            mostRecentJSDate,
            function (err, older) {
                if (older) {
                    publishJSFiles(options, details, packageMap, deps, false, cb);
                } else {
                    cb(err);
                }
            }
        );
    }

    async.waterfall([
        makeJSFiles,
        makeDOXFile
    ], cb);
}

// regenerate the lint
function makeLint(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    if (options.lint) {
        checkOlderOrInvalid(
            path.join(options.dstFolder, details.name, details.name + '.lint.json'),
            mostRecentJSDate,
            function (err, older) {
                if (older) {
                    publishLint(options, details, packageMap, deps, cb);
                } else {
                    cb(err);
                }
            }
        );
    } else {
        cb(null);
    }
}

// generates a test version of the JSFiles
function makeTestJSFiles(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    if (options.test) {
        // get the dependencies extended with testDependencies
        deps = getPackageDependencies(packageMap, details.name, true);
        checkOlderOrInvalid(
            path.join(options.dstFolder, details.name, details.name + '.test.js'),
            mostRecentJSDate,
            function (err, older) {
                if (older) {
                    publishJSFiles(options, details, packageMap, deps, true, cb);
                } else {
                    cb(err);
                }
            }
        );
    } else {
        cb(null);
    }
}

// regenerate Assets (jpg, png, etc)
function makeAssets(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    async.forEach(details.other, function (f, cb) {
        publishAsset(
            options,
            details.name,
            details.dirname,
            f,
            cb
        );
    }, cb);
}
// regenerate Html (note: we should add a .test.html ... one day)
function makeHtml(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    if (options.html) {
        if (mostRecentJSDate.getTime() > cssMostRecentDate.getTime()) {
            cssMostRecentDate = mostRecentJSDate;
        }
        // FIXME: publishHtml does not depend on jquery (important?)
        checkOlderOrInvalid(
            path.join(options.dstFolder, details.name + '.html'),
            cssMostRecentDate,
            function (err, older) {
                if (older) {
                    publishHtml(
                        options,
                        details,
                        packageMap,
                        deps,
                        cssFileMap,
                        cb
                    );
                } else {
                    cb(err);
                }
            }
        );
    } else {
        // no package.html to generate
        cb(null);
    }
}
// regenerate pillow
function makePillow(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    publishPillow(options.dstFolder, cb);
}
// regenerate jquery
function makeJQuery(
    cxt,
    cb
) {
    var options = cxt.options,
        details = cxt.details,
        packageMap = cxt.packageMap,
        mostRecentJSDate = cxt.mostRecentJSDate,
        deps = cxt.deps,
        depsFileMap = cxt.depsFileMap,
        cssFileMap = cxt.cssFileMap,
        cssMostRecentDate = cxt.cssMostRecentDate;

    if (options.jquery) {
        copyFileIfOutdated(options.jquery, options.dstFolder, cb);
    } else {
        cb(null);
    }
}
function make(cxt, cb) {
    cxt.makeDependencies(
        'makeJSFilesThenDOXFile',
        'makeLint',
        'makeTestJSFiles',
        'makeAssets',
        'makeHtml',
        'makePillow',
        'makeJQuery',
        cb
    );
}
// a rule can be a
exports.makeRules = {
    make: make,
    makeJSFilesThenDOXFile: makeJSFilesThenDOXFile,
    makeLint: makeLint,
    makeTestJSFiles: makeTestJSFiles,
    makeAssets: makeAssets,
    makeHtml: makeHtml,
    makePillow: makePillow,
    makeJQuery: makeJQuery
};
