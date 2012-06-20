###
CLI to automatically deploy stuff, kind of like heroku. 
Ubuntu only! (upstart)

TODO remember last command again
TODO multiple services
TODO multiple cron
TODO multiple servers

###

CONFIG = "ggg"

LOGS_LINES = 40
VERSION = "0.3.1"

fs = require 'fs'
path = require 'path'

program = require 'commander'

MainConfig = require "./lib/MainConfig"
Service = require "./lib/Service"

program
  .version(VERSION)

program
  .command("init")
  .description("creates a ggg.js config file for you")
  .action ->
    init finish


program
  .command("deploy <name> [branch]")
  .description("deploys a branch (defaults to origin/master) to named server")
  .action (name, branch) ->
    getService name, (err, service) ->
      return finish err if err?

      branch = branch || "origin/master"

      service.deploy branch, finish


program
  .command("restart <name>")
  .description("restarts named server")
  .action (name) ->
    getService name, (err, service) ->
      return finish err if err?
      service.restart finish


program
  .command("start <name>")
  .description("starts named server")
  .action (name) ->
    getService name, (err, service) ->
      return finish err if err?
      service.start finish

program
  .command("stop <name>")
  .description("stops named server")
  .action (name) ->
    getService name, (err, service) ->
      return finish err if err?
      service.stop finish

program
  .command("logs <name>")
  .description("Logs #{LOGS_LINES} lines of named servers log files")
  .option("-l, --lines <num>", "the number of lines to log")
  .action (name) ->
    getService name, (err, service) ->
      return finish err if err?
      lines = program.lines || LOGS_LINES
      service.logs lines, finish

program
  .command("list")
  .description("lists all the servers")
  .action ->
    getConfig (err, repoName, mainConfig) ->
      return finish err if err?

      list mainConfig, finish

program
  .command("*")
  .action ->
    finish new Error "bad command!"

## ACTIONS #########################################################

# creates the init file for you
init = (cb) ->
  initConfigContent = """
    // example ggg.js. Delete what you don't need
    module.exports = {

      // services
      start: "node app.js",

      // install
      install: "npm install",

      // cron jobs (from your app folder)
      cron: "0 3 * * * node sometask.js",

      // servers to deploy to
      servers: {
        dev: "deploy@dev.mycompany.com",
        staging: "deploy@staging.mycompany.com"
      }
    }
  """

  console.log "GOGOGO INITIALIZING!"
  console.log "*** Written to ggg.js ***"
  console.log initConfigContent

  fs.writeFile mainConfigPath() + ".js", initConfigContent, 0o0755, cb

list = (mainConfig, cb) ->
  console.log "GOGOGO servers (see ggg.js)"
  console.log " - " + mainConfig.getServerNames().join("\n - ")

## HELPERS #################################################
# gets the repo url for the current directory
# if it doesn't exist, use the directory name
reponame = (dir, cb) ->
  exec "git config --get remote.origin.url", {cwd:dir}, (err, stdout, stderr) ->
    if err?
      cb null, path.basename(dir)
    else
      url = stdout.replace("\n","")
      cb null, path.basename(url).replace(".git","")


# write a config file
writeConfig = (f, obj, cb) ->
  fs.mkdir path.dirname(f), (err) ->
    fs.writeFile f, "module.exports = " + JSON.stringify(obj), 0o0775, cb

# gets the main path for config
mainConfigPath = -> path.join process.cwd(), CONFIG

# returns the config object and the repoName
getConfigRepo = (cb) ->
  reponame process.cwd(), (err, repoName) ->
    return cb err if err?
    MainConfig.loadFromFile (err, mainConfig) ->
      if err then return cb new Error "Bad gogogo config file, ggg.js. Run 'gogogo init' to create one. Err=#{err.message}"

      cb null, repoName, mainConfig

#returns the service object
getService = (name, cb) ->
  getConfigRepo (err, repoName, mainConfig) ->
    return cb err if err?

    server = mainConfig.getServerByName name
    if !server then return cb new Error("Invalid Server Name: #{name}")

    service = new Service name, server, mainConfig, repoName

    cb null, service

# our handler on the finish
finish = (err) ->
  if err?
    console.log "!!! " + err.message
    process.exit 1
  console.log "OK"

# just export our program object
module.exports = program
