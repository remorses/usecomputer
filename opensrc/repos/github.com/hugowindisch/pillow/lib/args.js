/**
    args.js

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

var processargs = require('./processargs'),
    path = require('path'),
    helpStr;

exports.argFilters = [
    {
        filter: /^--help$/,
        name: '--help',
        help: 'displays help information',
        action: function (pat, filters) {
            processargs.showHelp(
                filters
            );
            return {
                help: true
            };
        }
    },
    {
        filter: /^-jquery=(.*)$/,
        name: '-jquery=filepath',
        help: 'includes and integrates jquery using the provided sources',
        action: function (pat) {
            return {
                jquery: pat[1]
            };
        }
    },
    {
        filter: /^-only=(.*)$/,
        name: '-only=pathRelativeToWorkGenerated',
        help: 'only remakes the specified file',
        action: function (pat) {
            return {
                only: pat[1]
            };
        }
    },
    {
        filter: /^-cache=(.*)$/,
        name: '-cache=packageName,packageName2',
        help: 'Use http caches for the specified package',
        action: function (pat) {
            return {
                cache: pat[1].split(',')
            };
        }
    },
    {
        filter: /^-cacheext=(.*)$/,
        name: '-cacheext=ext1,ext2,ext3',
        help: 'Use http caches for the specified package',
        action: function (pat) {
            return {
                cacheext: pat[1].split(',')
            };
        }
    },
    {
        filter: /^-nomake=(.*)$/,
        name: '-nomake=package1,package2,package3',
        help: 'Prevents some packages from being regenerated',
        action: function (pat) {
            return {
                nomake: pat[1].split(',')
            };
        }
    },
    {
        filter: /^-css$/,
        name: '-css',
        help: 'Includes all dependent css files in the resulting html',
        action: function (pat) {
            return {
                css: true
            };
        }
    },
    {
        filter: /^-html$/,
        name: '-html',
        help: 'Generate package.html',
        action: function (pat) {
            return {
                html: true
            };
        }
    },
    {
        filter: /^-work=(.*)$/,
        name: '-work=path',
        help: 'Working directory (defaults to the current directory).',
        action: function (pat) {
            return {
                work: pat[1]
            };
        }
    },
    {
        filter: /^-minify$/,
        name: '-minify',
        help: 'Minifies js file while packaging them',
        action: function (pat) {
            return {
                minify: true
            };
        }
    },
    {
        filter: /^-dox$/,
        name: '-dox',
        help: 'Generates documentation',
        action: function (pat) {
            return {
                dox: true
            };
        }
    },
    {
        filter: /^-lint$/,
        name: '-lint',
        help: 'Lints the sources',
        action: function (pat) {
            return {
                lint: true
            };
        }
    },
    {
        filter: /^-test$/,
        name: '-test',
        help: 'Generates a test version of the package (named .test.js)',
        action: function (pat) {
            return {
                test: true
            };
        }
    },
    {
        filter: /^-port=(.*)$/,
        name: '-port=portnumber',
        help: 'Uses the specified port in server mode',
        action: function (pat) {
            return {
                port: pat[1]
            };
        }
    },
    {
        filter: /.*/,
        name: 'srcFolder [srcFolder2...srcFolderN]',
        help: 'src folder',
        action: function (pat) {
            return {
                srcFolder: [pat[0]]
            };
        }
    }
];

exports.fixOptions = function (options) {
    options.work = options.work || '.';
    options.dstFolder = path.join(options.work, 'generated');
    options.srcFolder = options.srcFolder || [];
    options.makeRules = require('./make').makeRules;
    return options;
};
