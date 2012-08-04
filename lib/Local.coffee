
class Local
  constructor: (@name, config, mainConfig) ->
    @start = config.start || mainConfig.getStart()
    @install = config.install || mainConfig.getInstall()
    cron = if config.cron then mainConfig.normalizeCron config.cron else null
    @cron = cron || mainConfig.getCron()
    @user = config.user

  getStart: ->
    @start || throw new Error "You must specify 'start:' in your config file"

  getInstall: ->
    @install || throw new Error "You must specify 'install:' in your config file"

  getCron: -> @cron

  getUser: -> @user || throw new Error "You must specify 'user:' when using a local"

module.exports = Local
