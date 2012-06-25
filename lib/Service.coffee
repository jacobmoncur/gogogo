
{spawn} = require 'child_process'

PREFIX = "ggg"

class Service
  log: (msg) ->
    if @withPrefix
      console.log "#{@server}: #{msg}"
    else 
      console.log msg

  sshCommand: (commands, cb) =>
    @localCommand 'ssh', [@server, commands], (err) ->
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

  constructor: (@name, @server, @mainConfig, @repoName, @withPrefix = false) ->
    # pre compute all the fields we might need
    @id = @repoName + "_" + @name
    @repoDir = "$HOME/#{PREFIX}/#{@id}"
    @repoUrl = "ssh://#{@server}/~/#{PREFIX}/#{@id}"
    @hookFile = "#{@repoDir}/.git/hooks/post-receive"
    @logFile = "#{@repoDir}/log.txt"
    @upstartFile = "/etc/init/#{@id}.conf"

    @cronFile = "/etc/cron.d/#{@id}"
    @cronLogFile = "cron.txt"

    @serverUser = @server.replace(/@.*$/, "")

  create: (cb) ->
    @log " - id: #{@id}"
    @log " - repo: #{@repoDir}"
    @log " - remote: #{@repoUrl}"
    @log " - start: #{@mainConfig.getStart()}"
    @log " - install: #{@mainConfig.getInstall()}"

    upstartScript = @makeUpstartScript()
    hookScript = @makeHookScript()
    # CRON SUPPORT
    cronInstallScript = ""
    cron = @mainConfig.getCronConfig()

    if cron
      cronScript = @makeCronScript cron
      cronInstallScript = @makeCronInstallScript cronScript

    createRemoteScript = @makeCreateScript upstartScript, hookScript, cronInstallScript

    @sshCommand createRemoteScript, (err) ->
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
      exec su #{@serverUser} -c 'cd #{@repoDir} && #{@mainConfig.getStart()}' >> #{@logFile} 2>&1
    """

  makeHookScript: ->
    # http://toroid.org/ams/git-website-howto
    # we don't use the hook for anything, except making sure it checks out.
    # you still need the hook. It won't check out otherwise. Not sure why
    """
      read oldrev newrev refname
      echo 'GOGOGO checking out:'
      echo \\$newrev
      cd #{@repoDir}/.git
      GIT_WORK_TREE=#{@repoDir} git reset --hard \\$newrev || exit 1;
    """

  makeCronScript: (cron) ->
    """
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      #{cron.time} #{@serverUser} cd #{@repoDir} && #{cron.command} >> #{@cronLogFile} 2>&1
    """

  makeCronInstallScript: (cronScript) ->
    """
      echo "#{cronScript}" > #{@cronFile}
      chmod 0644 #{@cronFile}
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
    @log " - server: #{@server}"
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
        @sshCommand installCommand, (err) =>
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
      #{@mainConfig.getInstall()} || exit 1;
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
    @sshCommand @makeRestartCommand(), cb

  stop: (cb) ->
    @log "STOPPING"
    @sshCommand "stop #{@id};", cb

  start: (cb) ->
    @log "STARTING"
    @sshCommand "start #{@id};", cb

  # this will never exit. You have to Command-C it, or stop the spawned process
  serverLogs: (lines, cb) ->
    @log "Tailing #{@logFile}... Control-C to exit"
    @log "-------------------------------------------------------------"
    @sshCommand "tail -n #{lines} -f #{@logFile}", cb

module.exports = Service
