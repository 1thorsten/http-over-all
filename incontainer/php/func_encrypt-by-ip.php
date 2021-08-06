<?php
# rm /scripts/php/func_encrypt-by-ip.php ; nano /scripts/php/func_encrypt-by-ip.php

include "UnsafeCrypto.php";

$remote_addr = $_REQUEST['remote_addr'];

// IP: 10.10.1.34 -> 4310101 . KEY
$passphrase = strrev(str_replace('.','',$remote_addr)) . KEY;
$enc = $remote_addr;
if (isset($_REQUEST['m'])) {
    $enc = UnsafeCrypto::encrypt_p($passphrase,$_REQUEST['m'],true);
}

echo $enc;
