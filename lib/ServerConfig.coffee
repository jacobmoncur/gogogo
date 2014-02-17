# wrap config object to do a bit of logic for special cases and such
class ServerConfig
  constructor: (@name, @host, config, mainConfig) ->
    # if they override with an empty string, we want to use it, otherwise, do normal logic
    if typeof config.start == 'string' and not config.start
      @start = null
    else
      @start = config.start || mainConfig.getStart()

    @install = config.install || mainConfig.getInstall()
    cron = if config.cron then mainConfig.normalizeCron config.cron else null
    @cron = cron || mainConfig.getCron()

  getStart: ->
    if not @start
      console.log 'no start specified, start, stop and restart commands disabled!'
      return
    else
      @start

  getInstall: ->
    @install || throw new Error "You must specify 'install:' in your config file"

  getCron: -> @cron

  getUser: -> @host.replace(/@.*$/, "")

  getHost: -> @host

module.exports = ServerConfig
