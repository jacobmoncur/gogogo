spawn = require('child_process').spawn
fs = require 'fs'
path = require 'path'
assert = require 'assert'

describe 'init command', ->
  after (done) ->
    fs.unlink path.join(__dirname, '..', 'ggg.js'), (err) ->
      done()

  it 'successfully creates a file', (done) ->
    doneCalled = false
    spawnArgs = [path.join(__dirname, '..', 'bin', 'gogogo.js'), 'init']

    cp = spawn 'node', spawnArgs

    cp.on 'exit', (code) ->
      assert.equal code, 0

    cp.stderr.on 'data', (data) ->
      throw new Error('Got data on stderr when I didn\'t expect it:' + data.toString())

    cp.stdout.on 'data', (data) ->
      # we expect stuff to be printed to standard out
      if !doneCalled
        doneCalled = true
        done()
