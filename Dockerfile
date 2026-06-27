FROM node:18-alpine
WORKDIR /application
COPY ./package.json ./package-lock.json .
RUN npm ci
COPY . .
RUN chown -R node:node /application
EXPOSE 5000
USER node
CMD ["node","src/server.js"]
