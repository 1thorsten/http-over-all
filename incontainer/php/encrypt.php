<?php

# rm /scripts/php/encrypt.php ; nano /scripts/php/encrypt.php

include_once "Log.php";
include "Crypto.php";
include "common_functions.php";

denyAccessFromExternal("encrypt.php");

$time_start = microtime(true);

# http://localhost:8338/php/encrypt.php?path=/ibe_and_more/java/security/README.txt&scheme=http&http_host=localhost:8338&crypt

$uri = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];
$cache = $_REQUEST['cache'];

$object = (object)['uri' => $uri, 'cache' => $cache];
$json = json_encode((array)$object);

$encrypted = Crypto::encrypt($json, true);

$filename = basename($uri);

#$decryptUrl="{$_REQUEST['scheme']}://{$_REQUEST['http_host']}/php/decrypt.php?v={$encrypted}&f={$filename}";
#echo "<br><a href='$decryptUrl'>$decryptUrl</a>";
$encryptedUrl = "{$_REQUEST['scheme']}://{$_REQUEST['http_host']}/decrypt/$encrypted/$filename";

LOG::writeTime("encrypt.php", $remote_addr, "create url: $encryptedUrl", $time_start);

# curl -i -H "Accept: application/json" http://localhost:8338/git_aerintapi/docker/http-over-all/docker-compose.yml?share
if ($_SERVER['HTTP_ACCEPT'] == "application/json") {
    header('Content-Type: application/json; charset=utf-8');
    $responseArray = array('url' => $encryptedUrl, 'path' => '/decrypt', 'cipher' => $encrypted, 'resourceName' => $filename);
    echo json_encode($responseArray, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    return;
}
if (!accessFromBrowser()) {
    echo $encryptedUrl;
    return;
}

$encryptedLen = strlen($encryptedUrl);
$linkDecryptionUrl = "{$_REQUEST['scheme']}://{$_REQUEST['http_host']}/decrypt-link/$encrypted/$filename";

?>
<html lang="en">
<body style="background-color: lightgrey;">
<h1>SDS Link encryption</h1>
<span style="font-family: monospace;">
        <?php echo $encryptedUrl; ?><br/>
    </span>
<p>
    <a href="<?php echo $encryptedUrl; ?>" target="_blank"><?php echo "encrypted link (len: $encryptedLen)"; ?></a><br>
    <a href="<?php echo $linkDecryptionUrl; ?>" target="_blank"><?php echo "decrypt link"; ?></a>
</p>
</body>
</html>
