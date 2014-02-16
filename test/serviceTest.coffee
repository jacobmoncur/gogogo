assert = require 'assert'
Service = require '../lib/Service'

describe 'Service', ->
  name = 'mockService'
  repoName = 'someRepo'
  config = {
    getStart: -> 'echo "foo"'
    getUser: -> 'durp'
    getHost: -> ''
    getInstall: -> ''
    getCron: -> {
      default: {
        time: 'wat'
        command: 'echo "FOO BAR"'
      }
    }
  }
  parent = {
    log: ->
  }
  s = new Service name, repoName, config, parent

  describe '.create', ->
    it 'creates the correct upstart and hook and logrotate files', (done) ->
      expectedCreateRemoteScript = """
        echo '
        CREATING...'
        mkdir -p $HOME/ggg/someRepo_mockService
        cd $HOME/ggg/someRepo_mockService
        echo "Locating git"
        which git
        if (( $? )); then
            echo "Could not locate git"
            exit 1
        fi
        git init
        git config receive.denyCurrentBranch ignore

        echo "description 'someRepo_mockService'
        start on (filesystem and net-device-up)
        stop on runlevel [!2345]
        limit nofile 10000 15000
        respawn
        respawn limit 5 5
        exec su durp -c 'cd $HOME/ggg/someRepo_mockService && echo "foo"' >> $HOME/ggg/someRepo_mockService/ggg.log 2>&1" | sudo tee /etc/init/someRepo_mockService.conf
        echo "$HOME/ggg/someRepo_mockService/ggg.log {
          daily
          copytruncate
          rotate 7
          compress
          notifempty
          missingok
        }" | sudo tee /etc/logrotate.d/someRepo_mockService.conf

        echo "read oldrev newrev refname
        echo 'GOGOGO checking out:'
        echo \\$newrev
        echo \\`date\\` - \\$newrev >> $HOME/ggg/someRepo_mockService-history.txt
        cd $HOME/ggg/someRepo_mockService/.git
        GIT_WORK_TREE=$HOME/ggg/someRepo_mockService git reset --hard \\$newrev || exit 1;" > $HOME/ggg/someRepo_mockService/.git/hooks/post-receive
        chmod +x $HOME/ggg/someRepo_mockService/.git/hooks/post-receive
        echo "[√] created"
        echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        wat durp cd $HOME/ggg/someRepo_mockService && (echo "FOO BAR") >> cron_default.log 2>&1" | sudo tee /etc/cron.d/someRepo_mockService_cron_default
        sudo chmod 0644 /etc/cron.d/someRepo_mockService_cron_default
        echo "$HOME/ggg/someRepo_mockService/cron_default.log {
          daily
          copytruncate
          rotate 7
          compress
          notifempty
          missingok
        }" | sudo tee /etc/logrotate.d/someRepo_mockService_cron_default.conf
        sudo chmod 0644 /etc/logrotate.d/someRepo_mockService_cron_default.conf
      """
      s.runCommand = (createRemoteScript, cb) ->
        assert.equal createRemoteScript, expectedCreateRemoteScript
        cb()

      s.create done

  describe '.restart', ->
    it 'returns the right command', (done) ->
      restartCommand = "sudo restart someRepo_mockService;"
      s.runCommand = (command, cb) ->
        assert.equal command, restartCommand
        cb()

      s.restart done
  describe '.stop', ->
    it 'returns the right command', (done) ->
      stopCommand = "sudo stop someRepo_mockService;"
      s.runCommand = (command, cb) ->
        assert.equal command, stopCommand
        cb()

      s.stop done

  describe '.start', ->
    it 'returns the right command', (done) ->
      startCommand = "sudo start someRepo_mockService;"
      s.runCommand = (command, cb) ->
        assert.equal command, startCommand
        cb()

      s.start done

  describe '.serverLogs', ->
    it 'returns the right log command', (done) ->

      logsCommand = 'tail -n 10 -f $HOME/ggg/someRepo_mockService/ggg.log'
      s.runCommand = (command, cb) ->
        assert.equal command, logsCommand
        cb()

      s.serverLogs 10, done

  describe 'when given a start config with multiple start commands', ->
    name = 'prod'
    repoName = 'foo_service'
    config = {
      getStart: -> {
        web: 'echo "web"'
        worker: 'echo "worker"'
      }
      getUser: -> 'durp'
      getHost: -> ''
      getInstall: -> ''
      getCron: -> {
        default: {
          time: 'wat'
          command: 'echo "FOO BAR"'
        }
      }
    }
    parent = {
      log: ->
    }
    service = new Service name, repoName, config, parent

    describe '.create', ->
      it 'returns a correctly templated create command', (done) ->
        multipleStartCommand = """
          echo '
          CREATING...'
          mkdir -p $HOME/ggg/foo_service_prod
          cd $HOME/ggg/foo_service_prod
          echo "Locating git"
          which git
          if (( $? )); then
              echo "Could not locate git"
              exit 1
          fi
          git init
          git config receive.denyCurrentBranch ignore

          echo "description 'foo_service_prod_web'
          start on (filesystem and net-device-up)
          stop on runlevel [!2345]
          limit nofile 10000 15000
          respawn
          respawn limit 5 5
          exec su durp -c 'cd $HOME/ggg/foo_service_prod && echo "web"' >> $HOME/ggg/foo_service_prod/web.ggg.log 2>&1" | sudo tee /etc/init/foo_service_prod_web.conf
          echo "$HOME/ggg/foo_service_prod/web.ggg.log {
            daily
            copytruncate
            rotate 7
            compress
            notifempty
            missingok
          }" | sudo tee /etc/logrotate.d/foo_service_prod_web.conf
          echo "description 'foo_service_prod_worker'
          start on (filesystem and net-device-up)
          stop on runlevel [!2345]
          limit nofile 10000 15000
          respawn
          respawn limit 5 5
          exec su durp -c 'cd $HOME/ggg/foo_service_prod && echo "worker"' >> $HOME/ggg/foo_service_prod/worker.ggg.log 2>&1" | sudo tee /etc/init/foo_service_prod_worker.conf
          echo "$HOME/ggg/foo_service_prod/worker.ggg.log {
            daily
            copytruncate
            rotate 7
            compress
            notifempty
            missingok
          }" | sudo tee /etc/logrotate.d/foo_service_prod_worker.conf

          echo "read oldrev newrev refname
          echo 'GOGOGO checking out:'
          echo \\$newrev
          echo \\`date\\` - \\$newrev >> $HOME/ggg/foo_service_prod-history.txt
          cd $HOME/ggg/foo_service_prod/.git
          GIT_WORK_TREE=$HOME/ggg/foo_service_prod git reset --hard \\$newrev || exit 1;" > $HOME/ggg/foo_service_prod/.git/hooks/post-receive
          chmod +x $HOME/ggg/foo_service_prod/.git/hooks/post-receive
          echo "[√] created"
          echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
          wat durp cd $HOME/ggg/foo_service_prod && (echo "FOO BAR") >> cron_default.log 2>&1" | sudo tee /etc/cron.d/foo_service_prod_cron_default
          sudo chmod 0644 /etc/cron.d/foo_service_prod_cron_default
          echo "$HOME/ggg/foo_service_prod/cron_default.log {
            daily
            copytruncate
            rotate 7
            compress
            notifempty
            missingok
          }" | sudo tee /etc/logrotate.d/foo_service_prod_cron_default.conf
          sudo chmod 0644 /etc/logrotate.d/foo_service_prod_cron_default.conf
        """

        service.runCommand = (command, cb) ->
          assert.equal command, multipleStartCommand
          cb()

        service.create done
