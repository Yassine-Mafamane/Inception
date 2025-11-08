# escape=`

FROM alpine:3.21

RUN			apk update && `
			apk add --no-cache `
			nginx `
			curl `
			jq

COPY		--chmod=555 ./tools/init-nginx.sh	/bin/init-nginx.sh

RUN			mkdir /etc/nginx/ssl

RUN 		rm -f /etc/nginx/nginx.conf /etc/nginx/http.d/default.conf

ENTRYPOINT	[ "/bin/init-nginx.sh" ]
