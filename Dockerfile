FROM kkpkishan/alpine:3.17.0
LABEL Kishan Khatrani <kkpkishan@gmail.com>
# Add Production Dependencies
RUN apk add --update --no-cache \
    nano \
    icu-dev \
    nginx 

