connect = require('connect')
sharejs = require('share').server

server = connect connect.logger(), connect.static(__dirname)

options = {db: {type: 'none'}}

sharejs.attach(server, options)

server.listen(8000)
console.log('Server running at http://127.0.0.1:8000/')
