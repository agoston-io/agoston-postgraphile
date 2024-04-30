FROM node:21.7.3-alpine3.19 as build
COPY ../src/ /app/
WORKDIR /app
RUN npm ci --cache .npm --prefer-offline --only=production --silent --no-optional
run apk add iproute2
COPY ./tc.sh /tc.sh
RUN chmod +x /tc.sh
COPY ./postgraphileEntrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "node", "index.js" ]
