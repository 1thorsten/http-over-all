<?php
# rm /scripts/php/func_decrypt-by-ip.php ; nano /scripts/php/func_decrypt-by-ip.php

include "UnsafeCrypto.php";

$remote_addr = $_REQUEST['remote_addr'];

// IP: 10.10.1.34 -> 4310101 . KEY
$passphrase = strrev(str_replace('.','',$remote_addr)) . KEY;
if (isset($_REQUEST['m'])) {
    try {
        $dec = UnsafeCrypto::decrypt_p($passphrase, $_REQUEST['m'], true);
    } catch (Exception $e) {
        header("Status: 400 Bad Request");
        $dec = $e->getMessage();
    }
    echo $dec;
} else {
    header("Status: 400 Bad Request");
}
