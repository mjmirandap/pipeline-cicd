const http = require('http');
const port = 80;

http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hola, Módulo 2 en ejecución !\n');
}).listen(port, () => {
  console.log(`Server running on port ${port}`);
});