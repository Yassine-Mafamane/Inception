# escape=`

FROM	alpine:3.21

RUN		apk update && `
		apk add --no-cache mariadb mariadb-client

COPY	--chmod=644	./conf/mariadb-server.cnf etc/my.cnf.d/mariadb-server.cnf

COPY	--chmod=555 ./tools/init-db.sh	/bin/

ENTRYPOINT [ "/bin/init-db.sh" ]
