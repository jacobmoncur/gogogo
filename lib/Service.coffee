
{spawn} = require 'child_process'

Cron = require "./Cron"

PREFIX = "ggg"

isSingleStartCommand = (startCommand) ->
  typeof startCommand is 'string'

createSingleUpstartInstall = (upstart, upstartFile, logRotateCommand, logRotateFile) ->
  if upstart
    """
    echo "#{upstart}" | sudo tee #{upstartFile}
    echo "#{logRotateCommand}" | sudo tee #{logRotateFile}
    """
  else
    ""

makeUpstartScript = (id, serverUser, repoDir, startCommand, logFile) ->
  # upstart service
  # we use 'su root -c' because we need to keep our environment variables
  # http://serverfault.com/questions/128605/have-upstart-read-environment-from-etc-environment-for-a-service
  """
    description '#{id}'
    start on (filesystem and net-device-up)
    stop on runlevel [!2345]
    limit nofile 10000 15000
    respawn
    respawn limit 5 5
    exec su #{serverUser} -c 'cd #{repoDir} && #{startCommand}' >> #{logFile} 2>&1
  """


makeLogRotate = (logFile) ->
  """
  #{logFile} {
    daily
    copytruncate
    rotate 7
    compress
    notifempty
    missingok
  }
  """


makeCreateScript =  (hook, upstartInstall, cronInstallScript, repoDir, hookFile) ->
  # denyCurrentBranch ignore allows it to accept pushes without complaining
  """
    echo '\nCREATING...'
    mkdir -p #{repoDir}
    cd #{repoDir}
    echo "Locating git"
    which git
    if (( $? )); then
        echo "Could not locate git"
        exit 1
    fi
    git init
    git config receive.denyCurrentBranch ignore

    #{upstartInstall}

    echo "#{hook}" > #{hookFile}
    chmod +x #{hookFile}
    echo "[√] created"
    #{cronInstallScript}
  """

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
    @localCommand 'ssh', ["-o StrictHostKeyChecking=no", @host, commands], (err) ->
      if err? then return cb new Error "SSH Command Failed"
      cb()

  # runs the commands and dumps output as we get it
  localCommand: (command, args, cb) ->
    proc = spawn command, args, {env: process.env}
    proc.stdout.on 'data', (data) => @log data.toString().replace(/\n$/, "")
    proc.stderr.on 'data', (data) => @log data.toString().replace(/\n$/, "")

    proc.on 'exit', (code) ->
      if code then return cb(new Error("Command Failed"))
      cb()

    return proc

  constructor: (@name, @repoName, @config, @parent, @isLocal = false) ->
    # pre compute all the fields we might need
    @id = @repoName + "_" + @name
    @processes = @parseStartCommands @config, @id

    @repoDir = "$HOME/#{PREFIX}/#{@id}"
    @historyFile = "$HOME/#{PREFIX}/#{@id}-history.txt"
    @serverUser = @config.getUser()
    @hookFile = "#{@repoDir}/.git/hooks/post-receive"
    #@logFile = "#{@repoDir}/ggg.log"
    #@upstartFile = "/etc/init/#{@id}.conf"
    #@logRotateFile = "/etc/logrotate.d/#{@id}.conf"
    @noUpstart = !@config.getStart()

    if @isLocal
      @host = "localhost"
      # for some reason, things aren't preserved, so manually make sure this is
      # set!
      @repoDir = "#{process.env.HOME}/#{PREFIX}/#{@id}"
      @repoUrl = @repoDir
    else
      @host = @config.getHost()
      @repoUrl = "ssh://#{@host}/~/#{PREFIX}/#{@id}"

  parseStartCommands: (config, defaultName) ->
    start = config.getStart()
    # some people have no start
    return {} unless start
    if isSingleStartCommand start
      startCmd = start
      start = {}
      start[defaultName] = startCmd
    start

  idForCommand: (commandName, baseId) ->
    # for the cases where we only have one command, so the baseId is the same
    # as the command name
    return commandName if commandName is baseId
    "#{baseId}_#{commandName}"

  create: (cb) ->
    @log " - id: #{@id}"
    @log " - repo: #{@repoDir}"
    @log " - remote: #{@repoUrl}"
    @log " - start: #{@config.getStart()}"
    @log " - install: #{@config.getInstall()}"

    hookScript = @makeHookScript @historyFile, @repoDir
    # CRON SUPPORT
    cronConfig = @config.getCron()
    cronScript = ''

    if cronConfig
      cron = new Cron cronConfig, @id, @repoDir, @serverUser
      cronScript = cron.buildCron()

    upstartInstall = @createUpstartInstall @processes, @serverUser, @repoDir

    createRemoteScript = makeCreateScript hookScript, upstartInstall, cronScript,  @repoDir, @hookFile

    @runCommand createRemoteScript, (err) ->
      if err? then return cb err
      cb()

  # return the string to create one or more upstart and logrotate commands
  # for runProcesses
  #
  # @param runProcesses Object - hash of process name to start command
  # @param serverUser String - username to use to create these files
  # @param repoDir String - location of the github repo
  #
  # @return String a string to be run with exec that will generate the
  #   upstart and logrotate files
  createUpstartInstall: (processes, serverUser, repoDir) ->
    return '' if @noUpstart
    upstartInstall = ''
    for commandName, command of processes
      commandId = @idForCommand commandName, @id
      logFile = "#{@repoDir}/#{commandName}.ggg.log"
      upstartFile = "/etc/init/#{commandId}.conf"
      logRotateFile = "/etc/logrotate.d/#{commandId}.conf"

      upstartScript = makeUpstartScript commandId, serverUser, repoDir, command, logFile
      logRotateScript = makeLogRotate logFile

      upstartInstall += '\n' + createSingleUpstartInstall upstartScript, upstartFile,
        logRotateScript, logRotateFile

    upstartInstall

  makeHookScript: (historyFile, repoDir) ->
    # http://toroid.org/ams/git-website-howto
    # this hook ensures that we check out the right revision and also keep
    # track of what we have deploy
    """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      echo \\`date\\` - \\$newrev >> #{historyFile}
      cd #{repoDir}/.git
      GIT_WORK_TREE=#{repoDir} git reset --hard \\$newrev || exit 1;
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
        installCommand = @makeInstallCommand() + "\n" + @makeRestartCommands(@processes)
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

  makeRestartCommand: (commandName=@id) ->
    return "" if @noUpstart
    """
      echo '\nRESTARTING'
      sudo stop #{commandName}
      sudo start #{commandName}
      echo '[√] restarted'
    """

  restart: (commandName, cb) ->
    if typeof commandName is 'function'
      cb = commandName
      commandName = @id
    return @log "nothing to restart" if @noUpstart
    @log "RESTARTING"
    @runCommand @makeRestartCommand(idForCommand(commandName)), cb

  stop: (commandName, cb) ->
    if typeof commandName is 'function'
      cb = commandName
      commandName = @id
    return @log "nothing to stop" if @noUpstart
    @log "STOPPING"
    @runCommand "sudo stop #{idForCommand(commandName)};", cb

  start: (commandName, cb) ->
    if typeof commandName is 'function'
      cb = commandName
      commandName = @id
    return @log "nothing to start" if @noUpstart
    @log "STARTING"
    @runCommand "sudo start #{idForCommand(commandName)};", cb

  logFileForCommandName: (commandName) ->
    commandId = @idForCommand commandName, @id
    "#{@repoDir}/#{commandName}.ggg.log"

  # this will never exit. You have to Command-C it, or stop the spawned process
  serverLogs: (lines, commandName, cb) ->
    if typeof commandName is 'function'
      cb = commandName
      commandName = @id
    logFile = logFileForCommandName commandName
    @log "Tailing #{logFile}... Control-C to exit"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{lines} -f #{logFile}", cb

  getHistory: (revisions, cb) ->
    @log "Retrieving last #{revisions} deploys, most recent first!"
    @log "-------------------------------------------------------------"
    @runCommand "tail -n #{revisions} #{@historyFile} | tac", cb

  runCommandInRepo: (command, cb) ->
    @log "Running command #{command} in #{@repoDir}"
    @runCommand "cd #{@repoDir} && #{command}", cb

module.exports = Service
