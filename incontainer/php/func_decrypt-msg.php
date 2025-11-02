<?php
# rm -f /scripts/php/func_decrypt-msg.php ; nano /scripts/php/func_decrypt-msg.php

include_once "Log.php";
include "Crypto.php";
include "Ip4Range.php";

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
    // first try for multiple hosts
    $object = json_decode(Crypto::decrypt($message, true));
    if ($object !== null && !evaluateResponseForHosts($object, $remote_addr)) {
        // querying host not valid
        $object = null;
    } else if ($object === null) {
        // second try AES with extended passphrase
        $object = json_decode(Crypto::decrypt_ext($rev_remote_addr . KEY, Crypto::METHOD, $message, true));
        if ($object === null) {
            // third try OFB without extended passphrase
            $object = json_decode(Crypto::decrypt_ext($rev_remote_addr, 'BF-OFB', $message, true));
            if ($object !== null) {
                LOG::writeHost("func_decrypt-msg.php", $remote_addr, "WARN: detecting old cipher: $message");
            }
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
            header("for-hosts: ALL");
            return true;
        }

        $validHost = (new Ip4Range($for_hosts))->isIncluded($remote_addr);
        if ($validHost) {
            header("for-hosts: $for_hosts");
            return true;
        }
    }
    header("for-hosts: not found");
    return false;
}

