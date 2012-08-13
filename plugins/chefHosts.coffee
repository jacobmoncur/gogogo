
{spawn} = require "child_process"
HOUR_IN_MILLI = 3600000
# 
lastCheckInHours = 1

knife = "knife"
buildKnifeArgs = (role, env) ->
  curTime = Date.now()
  freshTime = curTime - (lastCheckInHours * HOUR_IN_MILLI)
  ["search", "node", "--format=json", "role:#{role} AND chef_environment:#{env} AND ohai_time:[#{freshTime} TO #{curTime}]"]

getNodesByRoleAndEnv = (role, env, cb) ->
  res = ''
  knifeProc = spawn knife, buildKnifeArgs(role, env)

  knifeProc.stdout.setEncoding "utf8"
  knifeProc.stderr.setEncoding "utf8"

  knifeProc.stdout.on "data", (data) ->
    res += data
  
  knifeProc.stderr.on "data", (data) ->
    console.log "had an error!", data
    return cb new Error("knife had an error")

  knifeProc.on "exit", (code) ->
    if code
      console.log "output", res
      return cb new Error("knife had an error")

    nodes = JSON.parse res
    cb null, nodes

defaultFindHost = (member) ->
  member.automatic.cloud.public_hostname

module.exports = (opts, cb) ->
  return cb new Error "no role specified" if not opts.role
  return cb new Error "no user specified" if not opts.user
  findHost = opts.findHost || defaultFindHost
  knife = opts.knifePath || knife

  env = opts.env || "_default"
  getNodesByRoleAndEnv opts.role, env, (err, nodes) ->
    return cb err if err?

    return cb new Error("no hosts found!") if not nodes.results
    members = nodes.rows
    hosts = []
    for member in members
      try
        hosts.push "#{opts.user}@#{findHost(member)}"
      catch error
        return cb new Error("failed to find the hostname using method:\n #{findHost.toString()}")

    cb null, hosts
