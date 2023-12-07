const express = require('express');
const app = express();
const server = require('http').createServer(app);
const { Server } = require("socket.io");
const io = new Server(server);
var i = 0

io.on('connection', (socket) => {
	console.log(`${i}. User connect`);
	i += 1

	socket.on('disconnect', () => {
	  console.log(`${i}. User disconnect`);
	  i += 1
	});

	socket.on('chat message', (data) => {
	  socket.broadcast.emit('chat message', data);
	  i += 1
	  console.log(`${i}. Chat message ${data}`)
	});


	socket.on('stream',function(data){
		var packet = JSON.parse(data);
        console.log(`${i}. Я получил ${packet['type']}`)
		i += 1
		socket.broadcast.emit('stream',data);
	});
});

const port = 8080

server.listen(port, () => {
  	console.log(`${i}. listening on *:${port}`);
	i += 1
});
