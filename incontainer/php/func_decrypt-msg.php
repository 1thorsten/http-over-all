<?php
# rm -f /scripts/php/func_decrypt-msg.php ; nano /scripts/php/func_decrypt-msg.php

include_once "Log.php";
include "UnsafeCrypto.php";

$remote_addr = $_REQUEST['remote_addr'];
$message = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $message = file_get_contents('php://input');
} else if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_REQUEST['m'])) {
    $message = $_REQUEST['m'];
}

if ($message === null) {
    http_response_code(400);
    LOG::writeHost("func_decrypt-msg.php", $remote_addr, "param 'm' is missing.");
    return;
}

$rev_remote_addr = strrev($remote_addr);
$object = null;

try {
    // first try OFB (than encryption for multiple hosts)
    $dec = UnsafeCrypto::decrypt_ext($rev_remote_addr, 'BF-OFB', $message, true);
    $object = json_decode($dec);

    if ($object === null) {
        $dec = UnsafeCrypto::decrypt($message, true);
        $object = json_decode($dec);
        if ($object !== null && !evaluateResponseForHosts($object, $remote_addr)) {
            // querying host not valid
            $object = null;
        }
    }
} catch (Exception $e) {
    http_response_code(400);
    echo $e->getMessage();
    LOG::writeHost("func_decrypt-msg.php", $remote_addr, "error decrypt: " . $e->getMessage());
    return;
}

if ($object === null) {
    http_response_code(400);
    return;
}

header('Content-Type: text/plain; charset=utf-8');
if (property_exists($object, 'v')) {
    header("Valid: " . date('F j, Y, g:i a', $object->v));
    if (strtotime("now") > $object->v) {
        http_response_code(400);
        echo "not valid";
        return;
    }
}

if (property_exists($object, 'm')) {
    echo $object->m;
}

/**
 * evaluate response and check if host value suits for the querying host
 * @param object $object
 * @param string $remote_addr
 * @return bool
 */
function evaluateResponseForHosts(object $object, string $remote_addr): bool
{
    if (property_exists($object, 'h')) {
        $for_hosts = $object->h;

        // for ALL = *
        if ($for_hosts === "*") {
            header("For-hosts: ALL");
            return true;
        }

        // for equality and existing
        $host_array = explode(",", $for_hosts);

        foreach ($host_array as $value) {
            if ($value === $remote_addr) {
                header("For-hosts: $remote_addr");
                return true;
            }
            $value = trim($value, " ");
            if (substr($remote_addr, 0, strlen($value)) === $value) {
                header("For-hosts: $remote_addr ($value)");
                return true;
            }
        }
    }
    header("For-hosts: not found");
    return false;
}

