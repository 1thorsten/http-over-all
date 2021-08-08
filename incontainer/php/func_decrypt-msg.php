<?php
# rm -f /scripts/php/func_decrypt-msg.php ; nano /scripts/php/func_decrypt-msg.php

include_once "Log.php";
include "UnsafeCrypto.php";

if (!isset($_REQUEST['m'])) {
    http_response_code(400);
    LOG::writeHost("func_decrypt-msg.php", $_REQUEST['remote_addr'], "param 'm' is missing.");
    return;
}

$message = $_REQUEST['m'];
$remote_addr = $_REQUEST['remote_addr'];

$object = null;
try {
    $dec = UnsafeCrypto::decrypt_ext(strrev($remote_addr), 'BF-ECB', UnsafeCrypto::decrypt($_REQUEST['m'], true));
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
    header("valid: " . date('F j, Y, g:i a', $object->v));
    if (strtotime("now") > $object->v) {
        http_response_code(400);
        echo "not valid";
        return;
    }
}

if ($object->m) {
    echo $object->m;
}

