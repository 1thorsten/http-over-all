<?php
# rm -f /scripts/php/func_decrypt-msg.php ; nano /scripts/php/func_decrypt-msg.php

include_once "Log.php";
include "UnsafeCrypto.php";

if (!isset($_REQUEST['m']) && !isset($_REQUEST['m1'])) {
    http_response_code(400);
    LOG::writeHost("func_decrypt-msg.php", $_REQUEST['remote_addr'], "param 'm' or 'm1' is missing.");
    return;
}

$cipher_algo = null;
$message = null;
if (isset($_REQUEST['m'])) {
    $cipher_algo = 'BF-ECB';
    $message = $_REQUEST['m'];
} else if (isset($_REQUEST['m1'])) {
    $cipher_algo = 'BF-OFB';
    $message = $_REQUEST['m1'];
}
$remote_addr = $_REQUEST['remote_addr'];

$object = null;
try {
    $dec = UnsafeCrypto::decrypt_ext(strrev($remote_addr), $cipher_algo, UnsafeCrypto::decrypt($message, true));
    $object = json_decode($dec);
} catch (Exception $e) {
    http_response_code(400);
    echo $e->getMessage();
    LOG::writeHost("func_decrypt-msg.php", $_REQUEST['remote_addr'], "error decrypt: " . $e->getMessage());
    return;
}

if ($object === null) {
    http_response_code(400);
    return;
}
if ($object->v) {
    header("Valid: " . date('F j, Y, g:i a', $object->v));
    if (strtotime("now") > $object->v) {
        http_response_code(400);
        echo "not valid";
        return;
    }
}

if ($object->m) {
    echo $object->m;
}

