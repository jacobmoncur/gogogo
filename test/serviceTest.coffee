assert = require 'assert'
Service = require '../lib/Service'

describe 'Service', ->
  describe '.create', ->
    it 'creates the correct upstart and hook and logrotate files', (done) ->
      name = 'mockService'
      repoName = 'someRepo'
      config = {
        getStart: -> 'echo "foo"'
        getUser: -> 'durp'
        getHost: -> ''
        getInstall: -> ''
        getCron: -> ''
      }
      parent = {
        log: ->
      }
      s = new Service name, repoName, config, parent

      expectedCreateRemoteScript = """
echo '
CREATING...'
mkdir -p $HOME/ggg/someRepo_mockService
cd $HOME/ggg/someRepo_mockService
echo "Locating git"
which git
if (( $? )); then
    echo "Could not locate git"
    exit 1
fi
git init
git config receive.denyCurrentBranch ignore

echo "description 'someRepo_mockService'
start on (filesystem and net-device-up)
stop on runlevel [!2345]
limit nofile 10000 15000
respawn
respawn limit 5 5
exec su durp -c 'cd $HOME/ggg/someRepo_mockService && echo "foo"' >> $HOME/ggg/someRepo_mockService/ggg.log 2>&1" | sudo tee /etc/init/someRepo_mockService.conf
echo "$HOME/ggg/someRepo_mockService/ggg.log {
  daily
  copytruncate
  rotate 7
  compress
  notifempty
  missingok
}" | sudo tee /etc/logrotate.d/someRepo_mockService.conf

echo "read oldrev newrev refname
echo 'GOGOGO checking out:'
echo \\$newrev
echo \\`date\\` - \\$newrev >> $HOME/ggg/someRepo_mockService-history.txt
cd $HOME/ggg/someRepo_mockService/.git
GIT_WORK_TREE=$HOME/ggg/someRepo_mockService git reset --hard \\$newrev || exit 1;" > $HOME/ggg/someRepo_mockService/.git/hooks/post-receive
chmod +x $HOME/ggg/someRepo_mockService/.git/hooks/post-receive
echo "[√] created"

"""
      s.runCommand = (createRemoteScript, cb) ->
        assert.equal createRemoteScript, expectedCreateRemoteScript
        cb()

      s.create done
