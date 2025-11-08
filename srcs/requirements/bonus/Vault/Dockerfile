# escape=`

FROM		debian:bookworm AS builder

RUN			apt update && apt install -y wget gpg

RUN			wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

RUN 		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo $VERSION_CODENAME) main" `
			| tee /etc/apt/sources.list.d/hashicorp.list

RUN 		apt update && apt install -y vault

FROM 		debian:bookworm

COPY 		--from=builder /usr/bin/vault /usr/bin/vault

COPY		--from=builder /etc/vault.d /etc/vault.d

RUN			mkdir -p /var/lib/vault/data

ENTRYPOINT	[ "vault", "server", "-config=/etc/vault.d/server-config.hcl" ]
