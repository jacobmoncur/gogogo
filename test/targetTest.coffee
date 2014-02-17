assert = require 'assert'
Target = require '../lib/Target'

describe 'Target', ->
  describe '.list', ->
    it 'returns a string listing all associated processes', (done) ->
      mainConfig = {
        getPlugins: -> undefined
        getStart: -> {
          web: 'start web'
          worker: 'start worker'
        }
        getInstall: -> 'install'
        getCron: -> ''
      }
      targetConfig = {
        hosts: ['foo']
      }
      t = new Target 'durp', targetConfig, 'beans', mainConfig, false
      expectedList = """
        durp
          durp:web
          durp:worker
      """

      t.on 'ready', ->
        res = t.list()
        assert.equal res, expectedList
        done()
