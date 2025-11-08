
length=10

rule "charset" {
    charset = "abcdefghij0123456789"
    minchar = 1
}

# Backslash (`\`) is intentionally excluded to avoid shell escaping
# and expansion issues when passing the generated password in commands.

rule "charset" {
    charset = "#%!-_+?/|.:"
    minchar = 1
}