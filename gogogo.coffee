###
CLI to automatically deploy stuff, kind of like heroku. 
Ubuntu only! (upstart)

TODO remember last command again
TODO multiple services
TODO multiple cron
TODO multiple servers

###

APP = "gogogo"
PREFIX = "ggg"
CONFIG = "ggg"

LOGS_LINES = 40

{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'


## RUN #############################################################

# figure out what to call, and with which arguments
# args = actual args
run = (args, cb) ->
  action = args[0]
  name = args[1]
  switch action
    when undefined then help cb
    when "init" then init cb
    when "--version" then version cb
    when "help" then help cb
    when "--help" then help cb
    when "-h" then help cb
    else
      reponame process.cwd(), (err, repoName) ->
        if err? then return cb err
        readMainConfig (err, mainConfig) ->
          if err then return cb new Error "Bad gogogo config file, ggg.js. Run 'gogogo init' to create one. Err=#{err.message}"
          switch action
            when "list" then list mainConfig, cb
            else
              server = configServer mainConfig, name
              if !server then return cb new Error("Invalid Server Name: #{name}")
              console.log "GOGOGO #{action} #{name}"

              switch action
                when "logs" then logs name, server, repoName, LOGS_LINES, cb
                when "restart" then restart name, server, repoName, cb
                when "start" then start name, server, repoName, cb
                when "stop" then stop name, server, repoName, cb
                when "deploy"
                  # branch = args[2] || lastBranch
                  branch = args[2]
                  deploy name, branch, mainConfig, repoName, cb
                else
                  cb new Error("Invalid Action #{action}")

## ACTIONS #########################################################

# creates the init file for you
init = (cb) ->
  initConfigContent = """
    // example ggg.js. Delete what you don't need
    module.exports = {

      // services
      start: "node app.js",

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


# PATHS AND HELPERS
serviceId = (repoName, name) -> repoName + "_" + name
hookFile = (id) -> "#{repoDir(id)}/.git/hooks/post-receive"
logFile = (id) -> path.join repoDir(id), "log.txt"
parentDir = -> "$HOME/" + PREFIX
upstartFile = (id) -> "/etc/init/#{id}.conf"
repoDir = (id) -> "#{parentDir()}/#{id}"
repoUrl = (id, server) -> "ssh://#{server}/~/#{PREFIX}/#{id}"
serverUser = (server) -> server.replace(/@.*$/, "")
cronFile = (id) -> "/etc/cron.d/#{id}"
cronLogFile = (id) -> "cron.txt" # assume already in the directory

# DEPLOY!!
create = (name, server, mainConfig, repoName, cb) ->

  # names and paths
  id = serviceId repoName, name

  console.log " - id: #{id}"
  console.log " - repo: #{repoDir id}"
  console.log " - remote: #{repoUrl id, server}"
  console.log " - start: #{configStart mainConfig}"
  console.log " - install: #{configInstall mainConfig}"

  # upstart service
  # we use 'su root -c' because we need to keep our environment variables
  # http://serverfault.com/questions/128605/have-upstart-read-environment-from-etc-environment-for-a-service
  service = """
    description '#{id}'
    start on startup
    chdir #{repoDir id}
    respawn
    respawn limit 5 5 
    exec su #{serverUser server} -c '#{configStart mainConfig}' >> #{logFile id} 2>&1
  """

  # CRON SUPPORT
  cronRemoteScript = ""
  cron = configCron mainConfig

  if cron
    cronScript = """
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      #{cron.time} #{serverUser server} cd #{repoDir id} && #{cron.command} >> #{cronLogFile id} 2>&1
    """
    cronRemoteScript += """
      echo "#{cronScript}" > #{cronFile id}
      chmod 0644 #{cronFile id}
    """

  # http://toroid.org/ams/git-website-howto
  # we don't use the hook for anything, except making sure it checks out.
  # you still need the hook. It won't check out otherwise. Not sure why
  hook = """
    read oldrev newrev refname
    echo 'GOGOGO checking out:'
    echo \\$newrev
    cd #{repoDir id}/.git
    GIT_WORK_TREE=#{repoDir id} git reset --hard \\$newrev || exit 1;
  """

  # command
  # denyCurrentBranch ignore allows it to accept pushes without complaining
  createRemoteScript = """
    echo '\nCREATING...'
    mkdir -p #{repoDir id}
    cd #{repoDir id}
    echo "Locating git"
    which git 
    if (( $? )); then
        echo "Could not locate git"
        exit 1
    fi
    git init
    git config receive.denyCurrentBranch ignore

    echo "#{service}" > #{upstartFile id}

    echo "#{hook}" > #{hookFile id}
    chmod +x #{hookFile id}
    echo "[√] created"
    #{cronRemoteScript}
  """

  ssh server, createRemoteScript, (err) ->
    if err? then return cb err
    cb()

# pushes directly to the url and runs the post stuff by hand. We still use a post-receive hook to checkout the files. 
deploy = (name, branch, mainConfig, repoName, cb) ->

  server = configServer(mainConfig, name)

  console.log " - name: #{name}"
  console.log " - server: #{server}"
  console.log " - branch: #{branch}"

  # create first
  create name, server, mainConfig, repoName, (err) ->
    if err? then return cb err

    id = serviceId repoName, name
    console.log "\nPUSHING"

    local "git", ["push", repoUrl(id, server), branch, "-f"], (err) ->
      if err? then return cb err

      console.log "[√] pushed"

      # now install and run
      command = installCommand(id, mainConfig) + "\n" + restartCommand(id)
      ssh server, command, (err) ->
        if err? then return cb err

        console.log ""
        command = logs name, server, repoName, 1, cb

        # for some reason it takes a while to actually kill it, like 10s
        kill = -> command.kill()
        setTimeout kill, 2000


## SIMPLE CONTROL ########################################################

installCommand = (id, mainConfig) -> """
    echo '\nINSTALLING'
    cd #{repoDir id}
    #{configInstall mainConfig} || exit 1;
    echo '[√] installed'
  """

restartCommand = (id) -> """
    echo '\nRESTARTING'
    stop #{id}
    start #{id}
    echo '[√] restarted'
  """

restart = (name, server, repoName, cb) ->
  id = serviceId repoName, name
  ssh server, restartCommand(id), cb

stop = (name, server, repoName, cb) ->
  console.log "STOPPING"
  id = serviceId repoName, name
  ssh server, "stop #{id};", cb

start = (name, server, repoName, cb) ->
  console.log "STARTING"
  id = serviceId repoName, name
  ssh server, "start #{id};", cb

version = (cb) ->
  pckg (err, info) ->
    console.log "GOGOGO v#{info.version}"

help = (cb) ->
  console.log "--------------------------"
  console.log "gogogo help"
  console.log "gogogo init - creates a ggg.js config file for you"
  console.log "gogogo deploy <name> <branch> — deploys branch to named server"
  console.log "gogogo restart <name>"
  console.log "gogogo start <name>"
  console.log "gogogo stop <name>"
  console.log "gogogo logs <name> — tail remote log"
  console.log "gogogo list — show available names"
  cb()

# this will never exit. You have to Command-C it, or stop the spawned process
logs = (name, server, repoName, lines, cb) ->
  id = serviceId repoName, name
  log = logFile id

  console.log "Tailing #{log}... Control-C to exit"
  console.log "-------------------------------------------------------------"
  ssh server, "tail -n #{lines} -f #{log}", ->

list = (mainConfig, cb) ->
  console.log "GOGOGO servers (see ggg.js)"
  console.log " - " + configServerNames(mainConfig).join("\n - ")


usage = -> console.log "Usage: gogogo create NAME USER@SERVER"























## HELPERS #################################################

pckg = (cb) ->
  fs.readFile path.join(__dirname, "package.json"), (err, data) ->
    if err? then return cb err
    cb null, JSON.parse data

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

# read a config file
readConfig = (f, cb) ->
  try
    m = require f
    cb null, m
  catch e
    console.log "BAD", e
    throw e
    cb e

class MainConfig
  constructor: ({@start, @install, @cron, @servers}) ->
    @servers ?= {}

# parse 0 1 * * * node stuff.js into: {time: "0 1 * * *", command: "node stuff.js"}
configCron = (cfg) ->
  return if not cfg.cron?
  matches = cfg.cron.match(/([0-9\s\*]+)\s+(.*)/)
  if not matches? then throw new Error "Invalid Cron: #{cfg.cron}"
  return {time: matches[1], command: matches[2]}

configServer = (cfg, name) -> cfg.servers[name] || throw new Error "Cannot find server named #{name}. Check your config file"
configStart = (cfg) -> cfg.start || throw new Error "You must specify 'start:' in your config file"
configInstall = (cfg) -> cfg.install || throw new Error "You must specify 'install:' in your config file"
configServerNames = (cfg) -> Object.keys cfg.servers

mainConfigPath = -> path.join process.cwd(), CONFIG
readMainConfig = (cb) ->
  readConfig mainConfigPath(), (err, config) ->
    if err? then return cb err
    cb null, new MainConfig config


# namedConfig = (name) -> path.join process.cwd(), CONFIG, name+".js"
# mainConfig = -> path.join process.cwd(), CONFIG, "_main.js"

# readNamedConfig = (name, cb) ->
#   readConfig namedConfig(name), cb

# readMainConfig = (cb) ->
#   readConfig namedConfig("_main"), (err, config) ->
#     if err? then return cb()
#     cb config.name, config.branch

# writeMainConfig = (name, branch, cb) ->
#   writeConfig namedConfig("_main"), {name, branch}, cb


# add a git remote
# NOT IN USE (you can push directly to a git url)
addGitRemote = (name, url, cb) ->
  exec "git remote rm #{name}", (err, stdout, stderr) ->
    # ignore errs here, the remote might not exist
    exec "git remote add #{name} #{url}", (err, stdout, stderr) ->
      if err? then return cb err
      cb()

ssh = (server, commands, cb) ->
  local 'ssh', [server, commands], (err) ->
    if err? then return cb new Error "SSH Command Failed"
    cb()


# runs the commands and dumps output as we get it
local = (command, args, cb) ->
  process = spawn command, args
  process.stdout.on 'data', (data) -> console.log data.toString().replace(/\n$/, "")
  process.stderr.on 'data', (data) -> console.log data.toString().replace(/\n$/, "")

  process.on 'exit', (code) ->
    if code then return cb(new Error("Command Failed"))
    cb()

  return process





# RUN THE THING
run process.argv.slice(2), (err) ->
  if err?
    console.log "!!! " + err.message
    process.exit 1
  console.log "OK"

