#!/usr/bin/env node

var fs = require("fs")
var path = require('path')
var root = path.join(path.dirname(fs.realpathSync(__filename)), '../')

var gogogo = require(root + "/index")

// kick it off!
gogogo.parse(process.argv)
