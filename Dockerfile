FROM node:18-alpine

# Instala dependencias y prepara el entorno
WORKDIR /app
COPY src/package*.json ./
RUN npm install

# Copia el codigo de la aplicacion (index.js, etc.)
COPY src/ .

# El puerto 80 debe coincidir con el puerto del Target Group
EXPOSE 80

# El comando de inicio
CMD [ "node", "index.js" ]