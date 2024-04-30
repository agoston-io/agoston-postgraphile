FROM postgres:16.2-alpine3.19
RUN apk update
RUN apk add python3 \
            py3-pip \
            postgresql16-plpython3 \
            py3-requests \
            iproute2
COPY ./tc.sh /tc.sh
RUN chmod +x /tc.sh
COPY ./postgresEntrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

