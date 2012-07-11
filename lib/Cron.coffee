
class Cron

  constructor: (cronConfig, @id, @repoDir, @serverUser, @cronDir = "/etc/cron.d") ->
    @cronJobs = []

    for cf in cronConfig
      @cronJobs.push @validate cf

  makeFileName: (name) -> "#{@cronDir}/#{@id}_cron_#{name}"
  makeLogFile: (name) -> "cron_#{name}.txt"

  validate: (cron) ->
    if not cron.name or not cron.time or not cron.command
      throw new Error "missing a required parameter for cron, try again"
    return cron

  makeCronScript: (cron) ->
    logFile = @makeLogFile cron.name
    """
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      #{cron.time} #{@serverUser} cd #{@repoDir} && #{cron.command} >> #{logFile} 2>&1
    """

  makeScript: (cron) ->
    cronFile = @makeFileName cron.name
    cronScript = @makeCronScript cron
    """
      echo "#{cronScript}" > #{cronFile}
      chmod 0644 #{cronFile}
    """

  buildCron: ->
    res = ''
    for cj in @cronJobs
      res += @makeScript cj
      res += "\n"
    return res

module.exports = Cron
