# a single process that can be independantly started, stopped, restarted, and logged
# one Service can have multiple Processes

createSingleUpstartInstall = (upstart, upstartFile, logRotateCommand, logRotateFile) ->
  if upstart
    """
    echo "#{upstart}" | sudo tee #{upstartFile}
    echo "#{logRotateCommand}" | sudo tee #{logRotateFile}
    """
  else
    ""

makeUpstartScript = (serviceName, serverUser, repoDir, startCommand, logFile) ->
  # upstart service
  # we use 'su root -c' because we need to keep our environment variables
  # http://serverfault.com/questions/128605/have-upstart-read-environment-from-etc-environment-for-a-service
  """
    description '#{serviceName}'
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

class Process
  constructor: ({@repoName, @repoDir, @processName, @target, @startCommand}) ->

  makeLogUpstartAndLogRotateFilesCommand: (serverUser) ->
    upstartFile = "/etc/init/#{@serviceName()}.conf"
    logRotateFile = "/etc/logrotate.d/#{@serviceName()}.conf"
    upstartScript = makeUpstartScript @serviceName(), serverUser, @repoDir, @startCommand, @logFile()
    logRotateScript = makeLogRotate @logFile()
    createSingleUpstartInstall upstartScript, upstartFile, logRotateScript, logRotateFile

  makeRestartCommand: ->
    """
      echo '\nRESTARTING'
      sudo stop #{@serviceName()}
      sudo start #{@serviceName()}
      echo '[√] restarted'
    """

  start: ->
    "sudo start #{@serviceName()};"

  stop: ->
    "sudo stop #{@serviceName()};"

  restart: ->
    "sudo restart #{@serviceName()};"

  serviceName: ->
    serviceName = "#{@repoName}_#{@target}"
    if @processName
      serviceName += "_#{@processName}"
    serviceName

  logFile: ->
    if @processName
      "#{@repoDir}/#{@processName}.ggg.log"
    else
      "#{@repoDir}/ggg.log"

module.exports = Process
