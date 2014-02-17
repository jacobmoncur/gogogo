assert = require 'assert'
path = require 'path'

MainConfig = require '../lib/MainConfig'

describe 'MainConfig', ->
  describe 'loadFromFile', ->
    it 'returns a sensible error if the config file doesnt exist', ->
      MainConfig.loadFromFile 'someBogusFile', (err, config) ->
        assert err
        assert.equal undefined, config
        assert /config file/i.test err.message

  describe '.listTargetsAndProcesses', ->
    it 'returns a string listing the targets and their accompanying processes', ->
      MainConfig.loadFromFile path.join(__dirname, 'fixtures', 'testGgg.js'), (err, config) ->
        assert.ifError err
        expectedList = """
          test
          dev:web
          dev:worker
          prod
        """
        list = config.listTargetsAndProcesses()
        assert.equal list, expectedList

