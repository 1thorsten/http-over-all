<?php
# rm /scripts/php/func_encrypt-ip.php ; nano /scripts/php/func_encrypt-ip.php

include_once "Log.php";
include "UnsafeCrypto.php";

$remote_addr = $_REQUEST['remote_addr'];

if (isset($_REQUEST['h'])) {
    $remote_addr = $_REQUEST['h'];
}

LOG::writeHost("func_encrypt-ip.php", $_REQUEST['remote_addr'], "ADDR: $remote_addr");
// IP: 10.10.1.34 -> 4310101 . KEY
$passphrase = strrev(str_replace('.', '', $remote_addr)) . KEY;
$enc = $remote_addr;
if (isset($_REQUEST['m'])) {
    $enc = UnsafeCrypto::encrypt_ext($passphrase,UnsafeCrypto::METHOD, $_REQUEST['m'], true);
}

echo $enc;
