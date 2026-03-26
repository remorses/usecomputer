#Pillow: A CommonjS Package Loader for the Browser
Pillow scans directories for commonJS packages and makes them accessible in the browser with the require() function (the source packages are converted to a directory that can be served statically).

Pillow can operate from the command line, as a server or as a middleware. When running as a server or as a middleware it will remake the packages automatically every time they are loaded by http, only rebuilding what has actually changed.

#Features
* Multiple js files per package
* Support for package resources (png, jpg, gif, json, css, html, md)
* Minify, dox and lint of source files
* Runtime loading of packages
* Optional separate application domains
* Command line operation (build using the command line)
* Server operation (packages are rebuilt when they are loaded through http)
* Middleware operation
* Support for ender packages

##Limitations
* Currently, pillow will generate one js file per package (but a package can contain multiple modules). There is no option in the current version to generate a single js file containing all the packages

* The ender runtime api (e.g. provide()) is not currently supported.

#Installation
npm install -g pillow

#Operation
##Command Line Operation: pillowscan
This assumes the package was installed globally. If not, pillowscan aliases to bin/pillowscan.js.

**pillowscan [options] folder1 [folder2..foldern]**

Options:

+ **--help**: displays help information
+ **-jquery=filepath**: includes and integrates jquery using the provided sources
+ **-only=pathRelativeToDstFolder**: only remakes the specified file
+ **-cache=packageName,packageName2**: Use http caches for the specified package
+ **-cacheext=ext1,ext2,ext3**: Use http caches for the specified package
+ **-nomake=package1,package2,package3**: Prevents some packages from being regenerated
+ **-css**: Includes all dependent css files in the resulting html
+ **-html**: Generate a package.html
+ **-work=path**: Working directory (defaults to the current directory).
+ **-minify**: Minifies js file while packaging them
+ **-dox**: Generates documentation
+ **-lint**: Lints the sources
+ **-test**: Generates a test version of the package (named .test.js)
+ **-port=portnumber**: Uses the specified port in server mode (instead of 1337)
+ **-work=path**: Working directory (defaults to the current directory).

###example
```
    pillowscan mypackages
```

Will scan mypackages and its subdirectories and generate or update ./generated that will contain properly packaged sources and assets. The ./generated can be served statically.

##Server Operation: pillowserve
This assumes the package was installed globally. If not, pillowserve aliases to bin/pillowserve.js.

**pillowserve [options] folder1 [folder2..foldern]**
Will make all packages loadable at http://localhost:1337/make/packageName/packageName.js, letting you do curl -X GET http://localhost:1337/make/packageName/packageName.js to retrieve the code. The resources (pngs, gifs, etc) will be loadable at: http://localhost:1337/make/packageName/path/to/your/image.png, where path/to/your/image.png is the path, relative to the package.json file.

(see pillowscan for the list of options)

##Middleware Operation
Here is how pillow can run in Express or Connect:
```javascript
    var app = require('express').createServer(),
        pillow = require('pillow'),
        options = {
            srcFolder: __dirname,
            dstFolder: path.join(__dirname, 'generated')
        },
        mw = pillow.getMiddleWare(options);
    app.use(mw);

    // Do something with the app
    app.listen(1337);
```

This lets you use the remake-on-request feature from within your own server. If you don't use Express, you can do the same from a bare bones node application:

```javascript
    var pillow = require('pillow'),
        options = {
            srcFolder: __dirname,
            dstFolder: path.join(__dirname, 'generated')
        },
        mw = pillow.getMiddleWare(options),
        srv = http.createServer(mw).listen(port, '0.0.0.0');
```


#Input: Packages
Pillow takes packages in input and produces an output directory that can be served statically.

Packages should follow the CommonJS Package 1.0 specification. The following fields of a package are currently used by pillow:

* **name:** Lets you define the name of the package. You will then be able to require it using this name.
* **dependencies:** Lets you define the dependencies of the package. When a package is loaded dynamically (using define.pillow.loadPackage), all its recursive dependencies will also be loaded. When an html file is created for a package (-html option), all its dependencies will have a link tag.
* **testDependencies:** Lets you define special dependencies that are only needed when your package is used in test mode (i.e. with the -test switch, for generating a packageName.test.js file). This is expressed an array of package names.
* **main:** Lets you define the main module of the package. If this is omitted, './lib/packageName.js' will be used by default.
* **engines:** The pillow engine MUST be defined to tell pillow to use the package. Alternately, if the keywords field contains the 'ender' keyword, the package will also be used (but treated differently, only exporting the main file).
* **keywords:** The 'ender' keyword designates an ender package. Other keywords are ignored.

## Example of a Pillow Package
This would be the package.json file
```json
    {
        "name": "http",
        "version": "0.0.1",
        "dependencies": {
            "utils": ">=0.0.1",
            "events": ">=0.0.1",
            "visual": ">=0.0.1",
            "url": ">=0.0.1"
        },
        "testDependencies": [ "assert" ],
        "main": "./lib/http.js",
        "scripts": {
            "test": "testviewer test/test.js"
        },
        "engines": {
            "pillow": "*"
        }
    }
```

And the source files are no different from normal nodeJS sourcefiles. For example, http.js could be something like:

```javascript
    var utils = require('utils'),
        // we could require another file from the same folder:
        another = require('./another'),
        // or from a subfolder
        fromsub = require('./sub/fromsub');

    function hello() {
        utils.doSomething();
    }
    exports.hello = hello;
```

##Special Behaviors:
* **test folder**: all the files in the directory where the package.json file was found and all subdirectories of this directory are scanned, and all js files are included in the package. The only **exception** is the test folder. The test folder will only be scanned for js files if the -test switch is used. In this case, a packageName.test.js file will be generated and will contain the normal files and the test files.

* **ender packages**: ender packages are supported, but the 'ender.js' file is not used and ender specific runtime functions are not supported. You can install an ender package by doing npm install packageName and then adding the node_modules directory to the list of directories used by pillowscan or pillowserve. Note that only one js module is included, the 'main' module.

##Existing Packages
+ Ender Packages: There already exists many different ender packages: bonzo, qwery and others.

+ Node Packages: Since there is no special way of writing pillow packages (js files are the same as in Node, and there are no magic wrapper files of any kind), a lot of general purpose NodeJS packages should work directly with pillow. The only thing to do is to add the 'pillow' engine declaration to the package.json file.

+ Swallowapps Packages: Pillow is the foundation of my other project, swallowapps, that is very roughly similar to the Flash (TM) authoring tool but that targets html5 (i.e. it is a no-css, no-html, graphic development tool targetting browsers). Inside the swallowapps project, there are many pillow packages (client side versions of Node's http, event, assert and url among others), and all swallowapps applications are packages. I will probably break the swallowapps projects in smaller parts (make the general purpose packages available independently) in the next months, and this will add to the list of existing packages compatible with pillow.

#Output: Structure of the Generated Folder
The generated folder will have the following structure:

```
    generated/
        pillow.js
        package1/
            package1.js
            some/
                subdir/
                    for/
                        images/
                            img1.png
```

Assuming that img1.png was located at ./some/subdir/for/images/img1.png relative
to the package.json file.


So, here's a summary of what you will find in the 'generated' folder:

* a pillow.js file that you must include in your html file
* for each package, a subdirectory, named after the package that contains a packageName.js file (that includes all your package's modules), and optionally asset files (png, gif, jpg etc) organized in the same way they were in your source folder, relative to the package.json file.

The generated folder can be served statically.

#Using Pillow in HTML Files
This section explains how to use the output files and directories generated by pillow.

##Using define.pillow.loadPackage
Assuming that your application wants to use 'myPackage1' and 'myPackage2', you can do something like:

```html
<html>
    <head>
        <script src = "pillow.js"></script>
        <script>
            window.onload = function () {
                define.pillow.run(['myPackage1', 'myPackage2'], function (err, require) {
                    require('myPackage1').doDomething();
                });
            };
        </script>
    </head>
</html>
```

Note that this html file will need to be in the same folder ass pillow.js for this to work.

##Automatically Generating an HTML File
You can tell pillowscan or pillowserve to automatically generate an html file for your package with the -html switch. This html will be placed in your generated folder, will be named yourPackage.html, and will look like:

```html
    <html>
    <head>
        <title>test1</title>

        <script src = "pillow.js"></script>
        <script src = "test1/test1.js"></script>
        <script src = "test2/test2.js"></script>

        <script>
            window.onload = function () {
                var pillow = define.pillow,
                    require = pillow.makeRequire(pillow.createApplicationDomain(), '');

                require('test1');
            }
        </script>
    </head>
    <body>
    </body>
    </html>
```

##Using Application Domains
You can load additional packages at execution time by calling define.pillow.loadPackage. This function takes an application domain as its second argument. An application domain contains the 'exports' of all the modules that were loaded in it. Using application domains can be useful for managing dependencies (unloading them at execution time).

###Runtime Loading in the Same Application Domain
This is how an additional package can be loaded at runtime, in the same application domain:

```jsavascript
    define.pillow.loadPackage(
        'myPackage',
        null,
        false,
        false,
        function (err) {
            // myPackage and all its dependencies are now loaded
            // everyone in the default domain will be able to require this
            // package from now on.
        }
    );
```
###Runtime Loading in a Different Application Domain
This is how an additional package can be loaded at runtime, in a new application domain (that, inherits from the topmost domain).

```javascript
    var myDomain = define.pillow.createApplicationDomain();
    define.pillow.loadPackage(
        'myPackage',
        myDomain,
        false,
        false,
        function (err) {
            // myPackage and all its dependencies are now loaded
            // We need a specific require function to require in the new
            // domain.
            var require = define.pillow.makeRequire(myDomain, '');
            require('myPackage').doSomething();
        }
    );
```

#Other Remarks
##Relationship with NPM
Pillow is very different from NPM. NPM publishes packages to a central repository or installs packages retrieved from a central repository. Pillow takes a package and makes it compatible with the browser. It is possible to install ender packages or pillow packages with NPM and then 'use' them with pillow.

##Relationship with NodeJS
Pillow packages are written the same way as NodeJS packages. A NodeJS package can be made compatible with pillow (assuming all its dependencies are also available in pillow) by adding 'pillow' to the list of engines in the package.json file.

##Other Similar Loaders
The other similar loaders that I know are:
+ ender
+ requireJS

##Browser Compatibility
The client side of pillow consists of very little code but has only been tested so far in recent versions of safari, firefox and chrome (i.e. no validation on ie so far).

##Why Another Loader
I wrote pillow as a foundation for swallowapps. I needed a loader that would make multiple js modules per package possible (something I did not find in ender at the time), and that would let me bundle graphic assets with js files in a package: swallowapps applications are graphic applications that are fully contained (code and visual assets, a bit like a swf file) in a CommonJS package. I also wanted something like the application domains that exist in Flash to ease the process of unloading swallowapps application (if an app is loaded in its own domain, and that its specific dependencies are also loaded in this domain, when the app is removed nothing remains). So my final conclusion was that having a complete control on the package loading system was pretty much a requirement of my swallowapps project.

I'm pretty certain that the existing loaders already solve the vast majority of normal use cases. But, if your project shares some of swallowapps' requirements, maybe you can take a look at pillow. And of course, thanks in advance for helping me improve this thing!

#License
MIT License

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
