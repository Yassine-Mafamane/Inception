# escape=`

FROM	alpine:3.21

RUN apk update && `
    apk add --no-cache php php83-session php-mysqli

RUN mkdir -p /var/www/html

COPY ./html/*   /var/www/html

ENTRYPOINT [ "php", "-S", "0.0.0.0:3334", "-t", "/var/www/html/" ]