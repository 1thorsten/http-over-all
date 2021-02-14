<?php

# https://stackoverflow.com/questions/9262109/simplest-two-way-encryption-using-php
# docker run --rm php:cli-alpine php -r 'echo "CRYPT_KEY:".base64_encode(openssl_random_pseudo_bytes(32))."\n";'
# php -r "echo base64_encode(openssl_random_pseudo_bytes(32));" ; echo
define('KEY', '__CRYPT_KEY__');

?>