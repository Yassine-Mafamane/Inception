
# This tells vault to allow swaping memory. Vault usually stores sensitive data in ram only 
# and the data stored on disk is always encrypted using the master key that is splited to useal keys, 
# so by allowing mlock sensitive data may be written to disk on swap such as an uncrypted data.
disable_mlock = true

ui = true

storage "file" {
  path = "/var/lib/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true
}

user_lockout "userpass" {
  lockout_threshold = "3"
  lockout_duration = "5m"
  lockout_counter_reset = "10m"
}
