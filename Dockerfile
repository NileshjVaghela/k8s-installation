FROM kkpkishan/alpine:3.13.7
LABEL Kishan Khatrani <kkpkishan@gmail.com>
# Add Production Dependencies
RUN apk update && apk upgrade --no-cache
RUN apk add --update --no-cache \
    nano \
    icu-dev \
    nginx 

