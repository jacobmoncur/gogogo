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

  describe '.buildCron', ->
    it 'returns a correctly formatted cron job string', ->
      cronConfig = {
        foo: { time: '123', command: 'foo command'}
        bar: { time: '4567', command: 'bar command'}
      }
      id = 'tvdata_import_service'
      repoDir = 'path/to/dir'
      serverUser = 'ubuntu'
      c = new Cron cronConfig, id, repoDir, serverUser
      expectedCron = """
        echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        123 ubuntu cd path/to/dir && (foo command) >> cron_foo.log 2>&1" | sudo tee /etc/cron.d/tvdata_import_service_cron_foo
        sudo chmod 0644 /etc/cron.d/tvdata_import_service_cron_foo
        echo "path/to/dir/cron_foo.log {
          daily
          copytruncate
          rotate 7
          compress
          notifempty
          missingok
        }" | sudo tee /etc/logrotate.d/tvdata_import_service_cron_foo.conf
        sudo chmod 0644 /etc/logrotate.d/tvdata_import_service_cron_foo.conf
        echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        4567 ubuntu cd path/to/dir && (bar command) >> cron_bar.log 2>&1" | sudo tee /etc/cron.d/tvdata_import_service_cron_bar
        sudo chmod 0644 /etc/cron.d/tvdata_import_service_cron_bar
        echo "path/to/dir/cron_bar.log {
          daily
          copytruncate
          rotate 7
          compress
          notifempty
          missingok
        }" | sudo tee /etc/logrotate.d/tvdata_import_service_cron_bar.conf
        sudo chmod 0644 /etc/logrotate.d/tvdata_import_service_cron_bar.conf
      """
      builtCron = c.buildCron()
      assert.equal builtCron, expectedCron
