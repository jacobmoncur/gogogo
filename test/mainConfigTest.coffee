MainConfig = require '../lib/MainConfig'
assert = require 'assert'

describe 'MainConfig', ->
  describe 'loadFromFile', ->
    it 'returns a sensible error if the config file doesnt exist', ->
      MainConfig.loadFromFile 'someBogusFile', (err, config) ->
        assert err
        assert.equal undefined, config
        assert /config file/i.test err.message
