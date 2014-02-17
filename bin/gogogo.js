#!/usr/bin/env node

var fs = require('fs')
var path = require('path')
// can't use __dirname b/c it resolves to symlink not this actual file path :(
var root = path.join(path.dirname(fs.realpathSync(__filename)), '../')
var gogogo = require(path.join(root, 'index'))

// show help if we don't have anything passed
if (process.argv.length < 3) console.log(gogogo.helpInformation())
// kick it off!
gogogo.parse(process.argv)
