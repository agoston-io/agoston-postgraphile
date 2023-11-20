FROM node:16.14-alpine as build
COPY src/ /app/
WORKDIR /app
RUN npm ci --cache .npm --prefer-offline --only=production --silent --no-optional
CMD [ "node", "index.js" ]
