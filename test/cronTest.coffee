assert = require 'assert'

Cron = require '../lib/Cron'

describe 'Cron', ->
  describe '.makeCronScript', ->
    it 'returns a correctly escaped string when given a command that contains a string', ->
      self = {
        serverUser: 'root'
        repoDir: 'hurp'
        makeLogFile: (n) -> n
      }
      cronConfig = {
        name: 'what the poop'
        time: 'wat'
        command: 'echo "FOO BAR"'
      }

      res = Cron.prototype.makeCronScript.call self, cronConfig
      expected = 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\nwat root cd hurp && (echo "FOO BAR") >> what the poop 2>&1'
      assert res, expected
