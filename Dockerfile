FROM kkpkishan/alpine:nginx.1.22.1
LABEL Kishan Khatrani <kkpkishan@gmail.com>
# Add Production Dependencies
RUN apk update && apk upgrade --no-cache
RUN apk add --update --no-cache \
    nano \
    icu-dev \
    nginx 

