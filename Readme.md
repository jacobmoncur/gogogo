Go Go Go
========

Gogogo is a simple command-line tool designed to let you deploy web applications as easily as possible. It puts files into place on any server with upstart and gets it all configured.

### Goals

1. Easy to setup
2. Easy to redeploy 
3. Deploy to multiple servers
4. Deploy different branches to the same server

Installation
------------

    npm -g install gogogo

Change Log
----------

* 0.3.0 - custom config file, cron support
* 0.2.6 - git push force
* 0.2.5 - Server Environment variables are preserved! Deploy monitors the log for a couple seconds. 
* 0.2.0 - gogogo list, logs, start, stop, restart, deploy

Server Requirements
-------------------

1. Upstart (included with ubuntu)
2. SSH Access
3. Git installed on both local computer and server

Usage
-----

In your local repo

1. `gogogo init`

2. edit ggg.js:

module.exports = {

    # how to start your app
    start: "PORT=5333 node app.js",

    # how to install/configure your app
    install: "npm install",

    servers: {
        dev: "deploy@dev.mycompany.com"
    }
}

3. gogogo deploy dev master

### Redeploy

    # change some stuff and commit
    ...

    # deploy again
    gogogo deploy test master
    
Limitations
-----------

1. Only works on ubuntu (requires upstart to be installed)
2. You must change the port in either the code or an environment variable to run the same app twice on the same server

Roadmap
-------

* gogogo rm
* gogogo ps
* ability to specify sub-folders that contain package.json files

Help
----

### Actions

    gogogo help
    gogogo init - creates a ggg.js config file for you
    gogogo deploy <name> <branch> — deploys branch to named server
    gogogo restart <name>
    gogogo start <name>
    gogogo stop <name>
    gogogo logs <name> — tail remote log
    gogogo list — show available names

### Cron Support

Gogogo currently supports a single cron action.

    module.exports = {
        cron: "0 3 * * * node something.js"
        ...
    }

It will create a script in /etc/cron.d/, set the permissions correctly, and redirect log output to `cron.txt`
 
### Environment variables

If they are the same no matter which server is deployed, put them in your start script. 

    "start":"DB_HOST=localhost node app.js"

If they refer to something about the server you are on, put them in /etc/environment.

    # /etc/environment
    NODE_ENV="production"

### Multiple servers

To deploy to multiple servers, just add multiple servers to the config file

    // ggg.js
    module.exports = {
        servers: {
            dev: "deploy@dev.mycompany.com",
            staging: "deploy@staging.mycompany.com"
        }
    }

Then deploy to them separately

    gogogo deploy dev master
    gogogo deploy staging master

### Multiple branches on the same server

You can deploy any branch over your old remote by pushing to it. To have multiple versions of an app running at the same time, call `gogogo create` with different names and the same server.

    // ggg.js
    module.exports = {
        servers: {
            dev: "deploy@dev.mycompany.com",
            featurex: "deploy@dev.mycompany.com"
        }
    }

Then deploy to them separately

    gogogo deploy dev master
    gogogo deploy featurex featurex

Note that for web servers you'll want to change the port in your featurex branch or it will conflict.

### Reinstall / Upgrade

To reinstall, run `npm install -g gogogo` again, then redo the create step in your repository. 

### Gitignore

Commit ggg.js to your repo, so anyone using the repo can deploy as long as they have ssh access to the server.



