
class Server

  constructor: (@address) ->
    @user = @address.replace(/@.*$/, "")

