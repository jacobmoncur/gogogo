class Cron

  constructor: (cronConfig, @id, @repoDir, @serverUser,
  @logRotateDir = "/etc/logrotate.d", @cronDir = "/etc/cron.d") ->
    @cronJobs = []

    for name, cf of cronConfig
      cf.name = name
      @cronJobs.push @validate cf

  makeFileName: (name) -> "#{@cronDir}/#{@id}_cron_#{name}"
  makeLogFile: (name) -> "cron_#{name}.log"
  makeLogPath: (name) -> "#{@repoDir}/#{@makeLogFile name}"
  makeRotateFile: (name) -> "#{@logRotateDir}/#{@id}_cron_#{name}.conf"

  validate: (cron) ->
    if not cron.name or not cron.time or not cron.command
      throw new Error 'cron must have .name, .time and .command properties but doesn\'t'
    return cron

  makeCronScript: (cron) ->
    logFile = @makeLogFile cron.name
    """
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      #{cron.time} #{@serverUser} cd #{@repoDir} && (#{cron.command}) >> #{logFile} 2>&1
    """

  makeRotateScript: (name) ->
    """
    #{@makeLogPath name} {
      daily
      copytruncate
      rotate 7
      compress
      notifempty
      missingok
    }
    """

  makeScript: (cron) ->
    cronFile = @makeFileName cron.name
    cronScript = @makeCronScript cron
    rotateFile = @makeRotateFile cron.name
    rotateScript = @makeRotateScript cron.name
    """
      echo "#{cronScript}" | sudo tee #{cronFile}
      sudo chmod 0644 #{cronFile}
      echo "#{rotateScript}" | sudo tee #{rotateFile}
      sudo chmod 0644 #{rotateFile}
    """

  buildCron: ->
    @cronJobs.map(@makeScript.bind(@)).join('\n')

module.exports = Cron
