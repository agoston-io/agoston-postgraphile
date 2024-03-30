# Use the latest LTS version of node: https://nodejs.org/en
FROM node:20.12.0-alpine3.19 as build
COPY src/ /app/
WORKDIR /app
RUN npm ci --cache .npm --prefer-offline --only=production --silent --no-optional
CMD [ "node", "index.js" ]
