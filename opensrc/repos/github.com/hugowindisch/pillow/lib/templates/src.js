{{verbatim}}
{{/verbatim}}
define('${filepath}', [ {{each dependencies}}'${$value}',{{/each}} ], function (require, exports, module) {
{{html code}}
});
