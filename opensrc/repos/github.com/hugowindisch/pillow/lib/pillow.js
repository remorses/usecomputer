/**
    pillow.js

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
/*globals jQuery */
function define(id, dependencies, fcn) {
    define.pillow.addModuleFile(id, dependencies, fcn);
}
define.amd = {};
define.pillow = {
    // this creates an application domain
    createApplicationDomain: function (parentDomain) {
        return {
            packages: {},
            modules: {},
            parentDomain: parentDomain || this.getTopmostDomain()
        };
    },
    // this is where loaded packages go
    packages: {
    },
    // this creates a package
    ensurePackage: function (packageName) {
        var pack = this.packages[packageName];
        if (!pack) {
            pack = this.packages[packageName] = {
                files: {
                },
                mainFile: null,
                dependencies: []
            };
        }
        return pack;
    },
    // returns (and optionally creates) the topmost application domain
    getTopmostDomain: function () {
        var v, packages = this.packages, td = this.topmostDomain, tdp;

        if (!td) {
            td = this.topmostDomain = {
                packages: {},
                modules: {},
                parentDomain: null
            };
            tdp = td.packages;
            // populate it with the currently loaded packages.
            for (v in packages) {
                if (packages.hasOwnProperty(v)) {
                    tdp[v] = packages[v];
                }
            }
            // we reserve the packages thing for the sole purpose of loading
            // so now we can clean it.
            this.packages = {};
        }
        return td;
    },
    // this will integrate with jQuery
    supportJQuery: function (require) {
        if (jQuery) {
            jQuery.noConflict();
            // now we can integrate ourself to jquery
            this.addModuleFile(
                'jQuery',
                [],
                function (require, exports, module) {
                    exports.jQuery = jQuery;
                }
            );
            // we can also allow any jQuery code to see our modules,
            // through jQuery.fn.pillow(modulename, function, args)
            if (require) {
                var args = [], i;
                for (i = 2; i < arguments.length; i += 1) {
                    args.push(arguments[i]);
                }
                jQuery.fn.pillow = function (thePackage, method) {
                    return require(thePackage)[method].apply(this, arguments);
                };
            }
        }
        // this has been done, no reason to do it again
        this.supportJQuery = function () {};
    },
    // this adds a module file to the loaded modules
    addModuleFile: function (id, dependencies, fcn) {
        var splitId = id.split('/'),
            packageName = splitId[0],
            pack = this.ensurePackage(packageName);
        // add the dependencies
        pack.dependencies = dependencies;
        // if the nonstandard defineMain is never called, we assume that the
        // main file of a package is the first one that we see that is named
        // with the sme name as the package
        if (!pack.mainFile &&
                (splitId.length > 1) &&
                (splitId[0] === splitId[splitId.length - 1])) {
            pack.mainFile = id;
        }
        pack.files[splitId.slice(1).join('/')] = fcn;
    },
    defineMain: function (packageName, modulepath) {
        this.ensurePackage(packageName);
        this.packages[packageName].mainFile = modulepath;
    },
    // transforms a relative path to an absolute path
    resolvePathArray: function (path, currentPath) {
        var spl = path.split('/'),
            cps = currentPath === '' ? [] : currentPath.split('/'),
            result = currentPath,
            l = spl.length,
            i,
            c;
        if (l > 0) {
            c = spl[0];
            // is it a relative path?
            if (c !== '.' && c !== '..') {
                // no:
                cps = [];
            }
            // process the path
            for (i = 0; i < l; i += 1) {
                c = spl[i];
                if (c === '..') {
                    cps.pop();
                } else if (c !== '.' && c !== '') {
                    cps.push(c);
                }
            }
        }
        return cps;
    },
    // finds a package in the application domain stack
    findPackage: function (applicationDomain, packageName) {
        var dom = applicationDomain,
            p;
        while (dom) {
            p = dom.packages[packageName];
            if (p) {
                return p;
            }
            dom = dom.parentDomain;
        }
        return null;
    },
    // this is the top level require
    makeRequire: function (applicationDomain, currentPath, mainModule) {
        var that = this;
        function require(moduleName) {
            var pathArray,
                path,
                fullPathDirectory,
                fullPath,
                packageName,
                exports,
                module,
                p,
                dom,
                m;

            // if the moduleName is a package name
            p = that.findPackage(applicationDomain, moduleName);
            if (p) {
                // replace the moduleName by the mainFile of the package
                path = p.mainFile;
            } else {
                p = null;
                path = moduleName;
            }
            pathArray = that.resolvePathArray(path, currentPath);
            fullPath = pathArray.join('/');
            packageName = pathArray[0];
            path = pathArray.slice(1).join('/');
            fullPathDirectory = pathArray.slice(
                0,
                pathArray.length - 1
            ).join('/');

            // if the module can't be found
            exports = applicationDomain.modules[fullPath];
            if (!exports) {
                // search the chain of application domains
                p = p || that.findPackage(applicationDomain, packageName);
                if (!p) {
                    throw new Error('Unavailable package ' + packageName);
                }
                m = p.files[path];
                if (!m) {
                    throw new Error('Unavailable module ' + path);
                }
                exports = applicationDomain.modules[fullPath] = {};
                module = { id: fullPath, exports: exports };
                // the main module is the first one to be required
                if (!mainModule) {
                    mainModule = module;
                }
                // according to the spec we would also pass the
                // dependencies as arguments
                m(
                    that.makeRequire(
                        applicationDomain,
                        fullPathDirectory,
                        mainModule
                    ),
                    exports,
                    module
                );
                // just like node does, allow to replace exports
                exports = applicationDomain.modules[fullPath] = module.exports;
            }
            return exports;
        }
        // setup main (this will depend on what topmost module is required)
        require.main = mainModule;
        require.applicationDomain = applicationDomain;
        return require;
    },
    purgeModules: function (applicationDomain, packageName) {
        var modules = applicationDomain.modules,
            newmods = {},
            module,
            m,
            path;
        for (m in modules) {
            if (modules.hasOwnProperty(m)) {
                path = m.split('/');
                if (path[0] !== packageName) {
                    newmods[m] = modules[m];
                }
            }
        }
        applicationDomain.modules = newmods;
    },
    // load dependencies for the specified package
    loadDependencies: function (deps, optionalApplicationDomain, cb) {
        var i,
            l = deps.length,
            loaded = 0,
            loadError = null;
        function onLoaded(err) {
            loaded += 1;
            if (err) {
                loadError = err;
                // we should probably abort everything, in fact...
                // (removing script tags or whatever)
            }
            if (loaded === l) {
                cb(loadError);
            }
        }
        if (l > 0) {
            for (i = 0; i < l; i += 1) {
                this.loadPackage(
                    deps[i],
                    optionalApplicationDomain,
                    false,
                    false,
                    onLoaded
                );
            }
        } else {
            cb(null);
        }
    },
    // load a package
    loadPackage: function (
        packageName,
        optionalApplicationDomain,
        reload,
        forTesting,
        cb
    ) {
        optionalApplicationDomain = optionalApplicationDomain ||
            this.getTopmostDomain();
        var script,
            that = this,
            // this will only find a loaded package
            loadedPack = this.findPackage(
                optionalApplicationDomain,
                packageName
            ),
            pack = this.packages[packageName];
        // if the pack is already loaded, we are done.
        if (loadedPack && !reload) {
            return cb(null);
        }

        function onComplete(err) {
            var i, loading = pack.loading, l = loading.length, li;
            delete pack.loading;
            // put the package in the appropriate application Domain
            if (!err) {
                optionalApplicationDomain.packages[packageName] = pack;
                that.purgeModules(optionalApplicationDomain, packageName);
            }
            // this is the loading package... it can now be removed.
            delete that.packages[packageName];
            // call all the callbacks
            for (i = 0; i < l; i += 1) {
                li = loading[i];
                li(err);
            }
        }
        // FIXME: reloading with a script tag really really sucks.
        // If we reload, we want to be able to abort any pending load,
        // and restart it. (because if someone reloads a second time,
        // very proabably it is for a good reason (he knows the thing
        // is outdated)
        if (!pack) {
            pack = this.ensurePackage(packageName);
            pack.loading = [cb];
            script = document.createElement('script');
            document.getElementsByTagName('head')[0].appendChild(script);
            script.src = packageName +
                '/' +
                packageName +
                (forTesting ? '.test.js' : '.js');

            script.onload = function () {
                // we should load the dependencies
                that.loadDependencies(
                    pack.dependencies.slice(3),
                    optionalApplicationDomain,
                    onComplete
                );
            };
            script.onerror = function () {
                onComplete(new Error('could not load ' + packageName));
            };
        } else {
            // the package may be currently loading
            if (pack.loading) {
                pack.loading.push(cb);
            } else {
                // We should not be there
                throw new Error('Unexpected state');
            }
        }
    },
    /**
    * Loads one or more packages, and returns a require function.
    * @param {String|Array} packageName The package to load
    * @param {Function} cb A callback that will receive (err, require).
    */
    run: function (packageName, cb) {
        var t = typeof packageName,
            that = this,
            topmost = this.getTopmostDomain(),
            toLoad;
        if (t === 'String') {
            toLoad = [packageName];
        } else if (t === 'object' && t.length > 0) {
            toLoad = packageName;
        } else {
            return cb(new Error('Invalid packageName ' + packageName));
        }
        this.loadDependencies(toLoad, topmost, function (err) {
            if (err) {
                return cb(err);
            }
            cb(null, that.makeRequire(topmost, ''));
        });
    }
};
