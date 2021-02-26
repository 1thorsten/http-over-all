<?php

# rm /scripts/php/latest-highlight.php ; nano /scripts/php/latest-highlight.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log

include_once "Log.php";
include "common_functions.php";
include "UptoDate.php";

# common_functions.php
denyAccessFromExternal("latest-highlight.php");

$time_start = microtime(true);

$path = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$uptoDate = new UptoDate($path);
$url = $uptoDate->url(true);

if (strstr($uptoDate->lastHttpStatus,'301') === '301 Moved Permanently') {
    header("Location: {$path}/");
    LOG::writeTime("latest-highlight.php",$remote_addr,"redirect to {$path}/ [{$uptoDate->lastHttpStatus}]", $time_start);
    exit();
}

$log = false;
$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $log = true;
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']} ";
}

$basename = basename($url);
# common_functions.php
$language = determineLanguage($basename);
$content = file_get_contents($url);

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title><?php echo $basename;?></title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.23.0/themes/prism.css" rel="stylesheet" />
    <link href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.23.0/plugins/line-numbers/prism-line-numbers.min.css" rel="stylesheet" />
</head>
<body>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.23.0/components/prism-core.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.23.0/plugins/autoloader/prism-autoloader.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.23.0/plugins/line-numbers/prism-line-numbers.min.js"></script>

    <pre><code class="<?php echo $language;?> line-numbers"><?php echo htmlspecialchars($content,ENT_SUBSTITUTE);?></code></pre>
</body>
</html>
<?php
if ($log) {
    LOG::writeTime("latest-highlight.php",$remote_addr,"Name: {$basename} {$language} {$debugOut}| Length: ".strlen($content)." | Cache: {$uptoDate->cacheStatus}", $time_start);
}
?>