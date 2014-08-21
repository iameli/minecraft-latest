#
# Hi! I'm a tiny script that redirects you to the latest Minecraft version on each channel.
#
# I include a couple kinda nice features like rate limiting -- no matter how many people are
# spamming me I'm only going to hit mojang's version.json once every five seconds.
#

BASE_URL = 'https://s3.amazonaws.com/Minecraft.Download/versions'
VERSIONS_URL = "#{BASE_URL}/versions.json"
REQUEST_INTERVAL = 5000

http = require 'http'
request = require 'request'
q = require 'q'

cache =
  versions: null
  lastAttempt: (new Date 0).getTime()

currentRequest = null

serverUrl = (version) -> "#{BASE_URL}/#{version}/minecraft_server.#{version}.jar"

getVersions = ->
  deferred = q.defer()
  if cache.versions? and ((new Date()).getTime() - cache.lastAttempt) < REQUEST_INTERVAL
    deferred.resolve cache.versions
  else # no fresh data
    if currentRequest?
      return currentRequest
    else
      currentRequest = deferred.promise
      request VERSIONS_URL, (err, ..., versions) ->
        currentRequest = null
        if err?
          return deferred.reject err
        versions = JSON.parse versions
        cache.versions = versions
        cache.lastAttempt = (new Date()).getTime()
        deferred.resolve versions
  return deferred.promise

cache = 
  versions: null
  lastAttempt: new Date(0)


app = http.createServer (req, res) ->
  [channel] = (x for x in req.url.split '/' when x.length > 0)
  getVersions().then (versions) ->
    if versions.latest[channel]
      res.writeHead 302,
        Location: serverUrl versions.latest[channel]
      res.end()
    else
      res.writeHead 404
      res.write "#{channel} is not a valid channel.\n"
      res.end()
  .catch (err) ->
    res.writeHead 503
    res.end()

port = if process.env.PORT? then process.env.PORT else 3000
app.listen port
console.log "Listening on port #{port}."
