#!/bin/sh

if ! id $FTP_LOCAL_USER > /dev/null 2>&1 ; then
	adduser -D $FTP_LOCAL_USER
fi

echo "$FTP_LOCAL_USER:$FTP_USER_PW"  | chpasswd

chown -R $FTP_LOCAL_USER:$FTP_LOCAL_USER /var/www/html

exec vsftpd /etc/vsftpd/vsftpd.conf
