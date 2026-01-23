// proyecto express-api/index.js 
// proyecto basico express
// puerto obtenido de la variable de entorno PORT o 3000 por defecto
const PORT = process.env.PORT || 3000;
const express = require('express');
const app = express();

// ruta raiz que responde con un mensaje simple
app.get('/', (req, res) => {
  res.send('Hola, mundo! Esta es una API de Express.');
});

// inicia el servidor y escucha en el puerto especificado
app.listen(PORT, () => {
  console.log(`Servidor escuchando en http://localhost:${PORT}`);
});
