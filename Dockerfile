FROM node:22.5.1-alpine3.20 as build
COPY ../src/ /app/
WORKDIR /app
RUN npm ci --cache .npm --prefer-offline --only=production --silent --no-optional
run apk add iproute2
COPY ./tc.sh /tc.sh
RUN chmod +x /tc.sh
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "node", "index.js" ]
