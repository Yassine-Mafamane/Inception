# escape=`

FROM    alpine:3.21

RUN apk update && `
    apk add --no-cache php php-fpm php-mysqli php-phar php-tokenizer php-mbstring curl jq

ADD https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /bin/

RUN mv /bin/wp-cli.phar /bin/wp && `
    chmod +x /bin/wp

COPY		./tools/configure-wp.sh /bin/configure-wp.sh

WORKDIR /var/www/html/wordpress/

RUN chmod +x /bin/configure-wp.sh

ENTRYPOINT	[ "/bin/configure-wp.sh" ]
