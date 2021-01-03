<?php

# rm /scripts/php/highlight.php ; nano /scripts/php/highlight.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log

include_once "Log.php";
include "common_functions.php";
include "UptoDate.php";

# common_functions.php
denyAccessFromExternal("highlight.php");

$time_start = microtime(true);

$uri = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$log = false;
$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $log = true;
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']} ";
}

$url = "http://127.0.0.1".$uri;
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

    <pre><code class="<?php echo $language;?> line-numbers"><?php echo htmlspecialchars($content,ENT_SUBSTITUTE, "UTF-8");?></code></pre>
</body>
</html>
<?php
if ($log) {
    LOG::writeTime("highlight.php",$remote_addr,"Name: {$basename} {$language} {$debugOut}| Length: ".strlen($content), $time_start);
}
?>