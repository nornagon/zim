argv = require('optimist').argv
connect = require('connect')
sharejs = require('share').server
fs = require 'fs'

server = connect connect.logger(), connect.static(__dirname)

options = {db: {type: 'none'}}

dir = argv._[0] ? '.'
console.log "Indexing #{dir}"


index = (dir, cb) ->
  pads = {}
  nextPadId = 1
  fs.readdir dir, (err, files) ->
    throw err if err
    numToRead = files.length
    finishedAFile = ->
      if !--numToRead
        cb(pads)
    for f in files
      do (f) ->
        fs.stat (path="#{dir}/#{f}"), (err, stats) ->
          if err
            console.error err
            finishedAFile()
            return
          if stats.isFile()
            fs.readFile path, 'utf8', (err, data) ->
              pads[nextPadId++] = {
                lines: data.split(/\n/)
                left: 0, top: 0
                width: 80
                name: f
              }
              finishedAFile()
          else
            finishedAFile()
    console.log files

share = sharejs.attach(server, options)

index dir, (pads) ->
  share.model.create 'workspace', 'json', ->
    share.model.applyOp 'workspace', {
      v:0, op:[{p:[],od:null,oi:{pads}}]
    }

    server.listen(8000)
    console.log('Server running at http://127.0.0.1:8000/')
