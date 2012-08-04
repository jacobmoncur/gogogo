
{spawn} = require 'child_process'

Cron = require "./Cron"

PREFIX = "ggg"

class Service
  # we let the host group handle the logging
  log: (msg) ->
    @parent.log @host, msg

  runCommand: (commands, cb) =>
    if @isLocal
      @localCommand "bash", ["-c", commands], cb
    else
      @sshCommand commands, cb

  sshCommand: (commands, cb) =>
    @localCommand 'ssh', [@host, commands], (err) ->
      if err? then return cb new Error "SSH Command Failed"
      cb()

  # runs the commands and dumps output as we get it
  localCommand: (command, args, cb) ->
    process = spawn command, args
    process.stdout.on 'data', (data) => @log data.toString().replace(/\n$/, "")
    process.stderr.on 'data', (data) => @log data.toString().replace(/\n$/, "")

    process.on 'exit', (code) ->
      if code then return cb(new Error("Command Failed"))
      cb()

    return process

  constructor: (@name, @repoName, @config, @parent, @isLocal = false) ->
    # pre compute all the fields we might need
    @id = @repoName + "_" + @name
    @repoDir = "$HOME/#{PREFIX}/#{@id}"
    @historyFile = "$HOME/#{PREFIX}/#{@id}-history.txt"
    @serverUser = @config.getUser()
    @hookFile = "#{@repoDir}/.git/hooks/post-receive"
    @logFile = "#{@repoDir}/ggg.log"
    @upstartFile = "/etc/init/#{@id}.conf"

    if @isLocal
      @host = "localhost"
      @repoUrl = @repoDir
    else
      @host = @config.getHost()
      @repoUrl = "ssh://#{@host}/~/#{PREFIX}/#{@id}"
      


  create: (cb) ->
    @log " - id: #{@id}"
    @log " - repo: #{@repoDir}"
    @log " - remote: #{@repoUrl}"
    @log " - start: #{@config.getStart()}"
    @log " - install: #{@config.getInstall()}"

    upstartScript = @makeUpstartScript()
    hookScript = @makeHookScript()
    # CRON SUPPORT
    cronConfig = @config.getCron()
    cronScript = ''

    if cronConfig
      cron = new Cron cronConfig, @id, @repoDir, @serverUser
      cronScript = cron.buildCron()

    createRemoteScript = @makeCreateScript upstartScript, hookScript, cronScript

    @runCommand createRemoteScript, (err) ->
      if err? then return cb err
      cb()

  makeUpstartScript: ->
    # upstart service
    # we use 'su root -c' because we need to keep our environment variables
    # http://serverfault.com/questions/128605/have-upstart-read-environment-from-etc-environment-for-a-service
    """
      description '#{@id}'
      start on startup
      respawn
      respawn limit 5 5 
      exec su #{@serverUser} -c 'cd #{@repoDir} && #{@config.getStart()}' >> #{@logFile} 2>&1
    """

  makeHookScript: ->
    # http://toroid.org/ams/git-website-howto
    # this hook ensures that we check out the right revision and also keep track of what we have deploy
    """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      echo \\`date\\` - \\$newrev >> #{@historyFile}
      cd #{@repoDir}/.git
      GIT_WORK_TREE=#{@repoDir} git reset --hard \\$newrev || exit 1;
    """

  makeCreateScript: (upstart, hook, cronInstallScript) ->
    # command
    # denyCurrentBranch ignore allows it to accept pushes without complaining
    """
      echo '\nCREATING...'
      mkdir -p #{@repoDir}
      cd #{@repoDir}
      echo "Locating git"
      which git 
      if (( $? )); then
          echo "Could not locate git"
          exit 1
      fi
      git init
      git config receive.denyCurrentBranch ignore

      echo "#{upstart}" > #{@upstartFile}

      echo "#{hook}" > #{@hookFile}
      chmod +x #{@hookFile}
      echo "[√] created"
      #{cronInstallScript}
    """

  deploy: (branch, cb) ->

    @log " - name: #{@name}"
    @log " - server: #{@host}"
    @log " - branch: #{branch}"

    # create first
    @create (err) =>
      if err? then return cb err

      @log "\nPUSHING"

      @localCommand "git", ["push", @repoUrl, branch, "-f"], (err) =>
        if err? then return cb err
        @log "[√] pushed"

        # now install and run
        installCommand = @makeInstallCommand() + "\n" + @makeRestartCommand()
        @runCommand installCommand, (err) =>
          if err? then return cb err

          # no op this so the kill doesn't cause an error!
          command = @serverLogs 10, ->

          # for some reason it takes a while to actually kill it, like 10s
          kill = -> 
            command.kill()
            cb()
          setTimeout kill, 2000

  makeInstallCommand: ->
    """
      echo '\nINSTALLING'
      cd #{@repoDir}
      #{@config.getInstall()} || exit 1;
      echo '[√] installed'
    """

  makeRestartCommand: -> 
    """
      echo '\nRESTARTING'
      stop #{@id}
      start #{@id}
      echo '[√] restarted'
    """

  restart: (cb) ->
    @log "RESTARTING"
    @runCommand @makeRestartCommand(), cb

  stop: (cb) ->
    @log "STOPPING"
    @runCommand "stop #{@id};", cb

  start: (cb) ->
    @log "STARTING"
    @runCommand "start #{@id};", cb

  # this will never exit. You have to Command-C it, or stop the spawned process
  serverLogs: (lines, cb) ->
    @log "Tailing #{@logFile}... Control-C to exit"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{lines} -f #{@logFile}", cb

  getHistory: (revisions, cb) ->
    @log "Retrieving last #{revisions} deploys, most recent first!"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{revisions} #{@historyFile} | tac", cb

module.exports = Service
