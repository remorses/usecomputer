/**
    scan.js
        This will scan directories, find the package.json files and then
        publish the package.json files in a statically servable directory
        structure.

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
/*globals __dirname, __filename */
"use strict";
var fs = require('fs'),
    events = require('events'),
    path = require('path'),
    async = require('async'),
    jsmin = require('jsmin'),
    jslint = require('JSLint-commonJS'),
    dox = require('dox'),
    utils = require('./utils'),
    sep = utils.sep,
    assetExt = utils.assetExt,
    lintOptions = utils.lintOptions,
    unWindowsifyPath = utils.unWindowsifyPath,
    concatObject = utils.concatObject,
    createFolder = utils.createFolder,
    copyFileIfOutdated = utils.copyFileIfOutdated,
    checkOlderOrInvalid = utils.checkOlderOrInvalid,
    filterStats = utils.filterStats,
    publishPillow = utils.publishPillow,
    getMostRecent = utils.getMostRecent,
    getPackageDependencies = utils.getPackageDependencies,
    getFileMap = utils.getFileMap;


/**
    Generates the published form of a given package.
*/
function makePublishedPackage(
    options,
    details,
    packageMap,
    cb
) {

    var detName = details.name,
        mostRecentJSDate = getMostRecent(
            details.stats,
            new RegExp("(\\.js$|" + detName + "\\.json)")
        ),
        deps = getPackageDependencies(packageMap, detName, false),
        depsFileMap = getFileMap(deps),
        cssFileMap = options.css ? filterStats(depsFileMap, /\.css$/) : {},
        cssMostRecentDate =
            options.css ? getMostRecent(depsFileMap, /\.css$/) : mostRecentJSDate,
        rules = concatObject(concatObject({}, require('./make').makeRules), options.makeRules || {}),
        cxt = {
            options: options,
            details: details,
            packageMap: packageMap,
            mostRecentJSDate: mostRecentJSDate,
            deps: deps,
            depsFileMap: depsFileMap,
            cssFileMap: cssFileMap,
            cssMostRecentDate: cssMostRecentDate
        },
        rulesOutput = {};
    cxt.makeDependencies = function () {
        var deps = Array.prototype.slice.call(arguments, 0, -1),
            cb = arguments[arguments.length - 1];
        async.map(
            deps,
            function (dep, cb) {
                if (rulesOutput[dep]) {
                    return cb(null, rulesOutput[dep]);
                }
                if (rules[dep]) {
                    rules[dep](cxt, function (err, res) {
                        if (err) {
                            return cb(err);
                        }
                        rulesOutput[dep] = res || true;
                        cb(null, rulesOutput[dep]);
                    });
                } else {
                    cb(new Error('Unknown rule: ' + dep));
                }
            },
            function (err, results) {
                if (err) {
                    return cb(err);
                }
                results.unshift(null, cxt);
                cb.apply(null, results);
            }
        );
    };
    // make the whole thing
    cxt.makeDependencies('make', cb);
}

/**
    Finds all package files (all files that we want to process)
    and returns them in an object
    {
        packageFile: {}
        js: [],
        other: []
    }
*/
function findPackageFiles(folder, details, cb) {
    // make sure we have what we need
    if (!details.js) {
        details.js = [];
    }
    if (!details.other) {
        details.other = [];
    }
    if (!details.stats) {
        details.stats = {};
    }
    // read the dir
    function readDir(cb) {
        fs.readdir(folder, cb);
    }
    // stat all files
    function statFiles(files, cb) {
        async.map(
            files,
            function (filename, cb) {
                fs.stat(
                    path.join(folder, filename),
                    function (err, stats) {
                        if (err) {
                            return cb(err);
                        }
                        cb(err, {filename: filename, stats: stats});
                    }
                );
            },
            cb
        );
    }
    // with the stats
    function processFiles(stats, cb) {
        // process all files
        async.forEach(
            stats,
            function (file, cb) {
                var isJs = /\.js$/,
                    getExt = /\.(\w+)$/,
                    matches,
                    ffn = unWindowsifyPath(
                        path.join(folder, file.filename)
                    );
                if (file.stats.isFile()) {
                    // keep a pointer to the details
                    file.stats.details = details;
                    // js file
                    if (isJs.test(file.filename)) {
                        details.stats[ffn] = file.stats;
                        details.js.push(ffn);
                    } else {
                        matches = getExt.exec(file.filename);
                        if (matches &&
                                assetExt[matches[1].toLowerCase()] !== undefined) {
                            details.stats[ffn] = file.stats;
                            details.other.push(ffn);
                        }
                    }
                    // nothing really async here
                    cb(null);
                } else if (file.stats.isDirectory()) {
                    findPackageFiles(ffn, details, cb);
                }
            },
            cb
        );
    }

    // do the async processing
    async.waterfall(
        [ readDir, statFiles, processFiles ],
        function (err) {
            cb(err, details);
        }
    );
}

/**
    Finds the files of an ender package.
*/
function findEnderPackageFiles(folder, details, cb) {
    var mainf = details.json.main.slice(2), // skip ./
        fn = path.join(folder, mainf);
    // make sure we have what we need
    if (!details.js) {
        details.js = [];
    }
    if (!details.other) {
        details.other = [];
    }
    if (!details.stats) {
        details.stats = {};
    }
    fs.stat(fn, function (err, stats) {
        if (err) {
            return cb(err);
        }
        var ffn = unWindowsifyPath(fn);
        details.stats[ffn] = stats;
        details.js.push(ffn);
        stats.details = details;
        cb(null, details);
    });
}

/**
    Checks if a package has a given keyword.
*/
function hasKeyword(json, kw) {
    var ret = false;
    if (json.keywords) {
        json.keywords.forEach(function (w) {
            if (w === kw) {
                ret = true;
            }
        });
    }
    return ret;
}

/**
    Loads the details of a package: its package.json file and
    the paths of all its contained files (js, other like gifs and jpgs)
*/
function loadPackageDetails(packageFile, cb) {
    var details = {
            filename: packageFile.filename,
            // FIXME: this does not use the package info
            dirname: path.dirname(packageFile.filename),
            js: [],
            other: []
        },
        json;
    fs.readFile(packageFile.filename, function (err, data) {
        if (err) {
            return cb(err);
        }
        // FIXME: try catch
        details.json = json = JSON.parse(data.toString());
        details.name = json.name || path.basename(details.dirname);
        if (json.engines && json.engines.pillow) {
            findPackageFiles(details.dirname, details, cb);
        } else if (hasKeyword(json, 'ender')) {
            findEnderPackageFiles(details.dirname, details, cb);
        } else {
            // skip this unknown package
            cb(null, null);
        }
    });
}

/**
    Checks the nomake thing
*/
function checkNoMake(options, packageName) {
    var ret = false;
    if (options.nomake) {
        if (!options.nomakeFast) {
            options.nomakeFast = {};
            options.nomake.forEach(function (o) {
                options.nomakeFast[o] = true;
            });
        }
        ret = (options.nomakeFast[packageName] === true);
    }
    return ret;
}

/**
    Processes a package.json file that has been loaded with its "details".
*/
function processPackageDetails(options, details, packageMap, cb) {
    var dirname = details.dirname,
        // we should use the package.name for the packagename
        packagename = details.name,
        publishdir = path.join(options.dstFolder, packagename);
    // do nothing if the package is in the nomake list
    if (checkNoMake(options, packagename)) {
        return cb(null);
    }

    // create an output dir for this package
    createFolder(publishdir, function (err) {
        if (err) {
            return cb(err);
        }
        makePublishedPackage(
            options,
            details,
            packageMap,
            cb
        );
    });
}

/**
    Processes multiple package details (the packages are given as a package map).
*/
function processMultiplePackageDetails(options, packages, cb) {
    async.forEach(
        Object.keys(packages),
        function (pd, cb) {
            processPackageDetails(options, packages[pd], packages, cb);
        },
        cb
    );
}

/**
    Finds packages from a given folder and calls cb(err, packages) where
    packages is an array of package details.
*/
function findPackagesFromSingleFolder(rootfolder, cb) {
    // read the dir
    function readDir(cb) {
        fs.readdir(rootfolder, cb);
    }
    // stat all files
    function statFiles(files, cb) {
        async.map(files, function (filename, cb) {
            fs.stat(
                path.join(rootfolder, filename),
                function (err, stats) {
                    if (err) {
                        return cb(err);
                    }
                    cb(err, {filename: filename, stats: stats});
                }
            );
        }, cb);
    }
    // for files that are package.json
    function processFiles(stats, cb) {
        var found = [], results = {};
        // process all files
        async.forEach(stats, function (file, cb) {
            var isJs = /package\.json$/;
            if (file.stats.isFile()) {
                if (isJs.test(file.filename)) {
                    found.push({
                        filename: path.join(rootfolder, file.filename),
                        stats: file.stats
                    });
                    cb(null);
                } else {
                    cb(null);
                }
            } else if (file.stats.isDirectory()) {
                findPackagesFromSingleFolder(
                    path.join(rootfolder, file.filename),
                    function (err, res) {
                        if (!err) {
                            concatObject(results, res);
                        }
                        cb(err);
                    }
                );
            }
        }, function (err) {
            if (err) {
                return cb(err);
            }
            return cb(null, found, results);
        });
    }
    // load the package details of the found files and add them to the
    // results
    function loadDetails(found, results, cb) {
        async.map(
            found,
            loadPackageDetails,
            function (err, detailArray) {
                if (err) {
                    return cb(err);
                }
                // map all the results
                detailArray.forEach(function (d) {
                    if (d) {
                        results[d.name] = d;
                    }
                });
                // return the map
                cb(null, results);
            }
        );
    }

    // search folders for package.json
    async.waterfall([ readDir, statFiles, processFiles, loadDetails ], cb);
}

/**
    Finds packages from multiple folders.
    note: folderArray can be a string or an array of strings
*/
function findPackages(folderArray, cb) {
    if (!(folderArray instanceof Array)) {
        findPackagesFromSingleFolder(folderArray, cb);
    } else {
        var packages = {};
        async.map(
            folderArray,
            findPackagesFromSingleFolder,
            function (err, res) {
                if (err) {
                    return cb(err);
                }
                res.forEach(function (r) {
                    concatObject(packages, r);
                });
                cb(null, packages);
            }
        );
    }
}

/**
    This function regenerates all packages.
    note: srcFolder can be a string or an array of strings
*/
function makeAll(options, cb) {
    findPackages(options.srcFolder, function (err, packages) {
        if (err) {
            return cb(err);
        }
        processMultiplePackageDetails(options, packages, cb);
    });
}
/**
    This function regenerates a single package. It prevents excessive
    directory scanning by not rescannign if there are pending scans
    and rebuilding if there is a pending build for the required packageName
    with the current options.

    note: srcFolder can be a string or an array of strings
*/
function makePackage(options, packageName, cb) {
    // keep track of what is currently being built with these options
    options.currentlyBuilding = options.currentlyBuilding || new events.EventEmitter();
    options.currentlySearchingPackages = options.currentlySearchingPackages || new events.EventEmitter();
    // even before we try to find the packages, we want to skip
    // packages that were excluded.
    // Note that this is the only place where it is really beneficial
    // to enforce the nomake thing.
    if (checkNoMake(options, packageName)) {
        // we don't make it
        return cb(null);
    }

    // if we are currently building this package with the same options
    // well, let's simply wait for the end of the build and return at that
    // time.
    options.currentlyBuilding.once(packageName, cb);

    // what to do when the package is built
    function packageBuilt(err) {
        // signal the end of the build to all interested users
        options.currentlyBuilding.emit(packageName, err);
    }
    // what to do when the packages are found
    function packagesFound(err, packages) {
        options.currentlySearchingPackages.emit('found', err, packages);
    }
    // we are the only pending build of this package
    if (options.currentlyBuilding.listeners(packageName).length === 1) {
        // we may already be in the process of finding all packages.
        // again this operation is lengthy and if we are currently doing
        // it why not simply wait for the results and use them
        options.currentlySearchingPackages.once('found', function (err, packages) {
            var deps;
            if (err) {
                return packageBuilt(err);
            }
            try {
                deps = getPackageDependencies(packages, packageName);
            } catch (e) {
                console.log(e);
                return packageBuilt(e);
            }
            processPackageDetails(options, packages[packageName], packages, packageBuilt);
        });
        // there is only one listener? we must initiate the package loading
        if (options.currentlySearchingPackages.listeners('found').length === 1) {
            findPackages(options.srcFolder, packagesFound);
        }
    }
}

/**
    This function regenerates a single file (or a full package if
    a package name is specified).
    note: srcFolder can be a string or an array of strings
*/
function makeFile(options, dstFolderRelativeFilePath, cb) {
    // the provided relative path should be relative to the dstFolder
    // and consequently the first subdir should be the package name
    var assetFolder = path.normalize(dstFolderRelativeFilePath),
        assetFolderRoot,
        splitFolder = assetFolder.split(sep);
    if (splitFolder.length > 1) {
        assetFolderRoot = splitFolder[0];
    } else if (/\.html$/.test(dstFolderRelativeFilePath)) {
        assetFolderRoot = dstFolderRelativeFilePath.slice(0, -5);
    } else if (dstFolderRelativeFilePath.indexOf('.') === -1) {
        assetFolderRoot = dstFolderRelativeFilePath;
    } else {
        // FIXME
        // nothing to regenerate (maybe in fact the pillow.js thing)
        publishPillow(
            options.dstFolder,
            cb
        );
        return;
    }
    // non optimal but ok for now
    makePackage(options, assetFolderRoot, cb);
}


/**
    Library support.
*/
exports.makeAll = makeAll;
exports.makePackage = makePackage;
exports.makeFile = makeFile;
exports.findPackages = findPackages;
