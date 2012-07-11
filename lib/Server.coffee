

class Server
  constructor: (@name, @host, config, mainConfig) ->
    @start = config.start || mainConfig.getStart()
    @install = config.install || mainConfig.getInstall()
    cron = if config.cron then mainConfig.normalizeCron cron else null
    @cron = cron || mainConfig.getCron()

  getStart: ->
    @start || throw new Error "You must specify 'start:' in your config file"

  getInstall: ->
    @install || throw new Error "You must specify 'install:' in your config file"

  getCron: -> @cron

  getUser: @host.replace(/@.*$/, "")

  getHost: @host


module.exports = Server
