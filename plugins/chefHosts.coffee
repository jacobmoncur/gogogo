
{exec} = require "child_process"

knife = "knife"
buildKnifeCommand = (role, env) ->
  if env
    "#{knife} search node --format=json 'role:#{role} AND chef_environment:#{env}' --format=json"


getNodesByRoleAndEnv = (role, env, cb) ->
  exec buildKnifeCommand(role, env), (err, stdout) ->
    return cb err if err?
    nodes = JSON.parse stdout
    cb null, nodes

defaultFindHost = (member) ->
  member.automatic.cloud.public_hostname

module.exports = (opts, cb) ->
  return cb new Error "no role specified" if not opts.role
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
        hosts.push findHost(member)
      catch error
        return cb new Error("failed to find the hostname using method:\n #{findHost.toString()}")

    cb null, hosts
