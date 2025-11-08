# escape=`

FROM	alpine:3.21

RUN apk add --no-cache vsftpd

COPY tools/init.sh /bin/init.sh

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf

RUN chmod +x /bin/init.sh

ENTRYPOINT [ "init.sh"]