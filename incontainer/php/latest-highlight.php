<?php

# rm /scripts/php/latest-highlight.php ; nano /scripts/php/latest-highlight.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log

# https://cdnjs.com/libraries/prism
include_once "globals.php";
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
    header("Location: $path/");
    LOG::writeTime("latest-highlight.php", $remote_addr, "redirect to $path/ [$uptoDate->lastHttpStatus]", $time_start);
    exit();
}

$log = (PHP_LOG_ENABLED === "true");
$debugOut = '';
if (isset($_SERVER['HTTP_X_DEBUG_OUT'])) {
    $log = true;
    $debugOut = "| Debug: {$_SERVER['HTTP_X_DEBUG_OUT']} ";
}

$basename = basename($url);
# common_functions.php
$language = determineLanguage($basename);
$content = file_get_contents($url);
//$content = htmlspecialchars($content,ENT_SUBSTITUTE);
$content = mb_convert_encoding($content, 'HTML-ENTITIES', "ISO-8859-1");

// highlight lines
$lineHighlight = "";
if (isset($_REQUEST['l'])){
    $lineHighlight = $_REQUEST['l'];
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title><?php echo $basename;?></title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/themes/prism.min.css" integrity="sha512-tN7Ec6zAFaVSG3TpNAKtk4DOHNpSwKHxxrsiw4GHKESGPs5njn/0sMCUMl2svV4wo4BK/rCP7juYz+zx+l6oeQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/plugins/line-numbers/prism-line-numbers.min.css" integrity="sha512-cbQXwDFK7lj2Fqfkuxbo5iD1dSbLlJGXGpfTDqbggqjHJeyzx88I3rfwjS38WJag/ihH7lzuGlGHpDBymLirZQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/plugins/line-highlight/prism-line-highlight.min.css" integrity="sha512-nXlJLUeqPMp1Q3+Bd8Qds8tXeRVQscMscwysJm821C++9w6WtsFbJjPenZ8cQVMXyqSAismveQJc0C1splFDCA==" crossorigin="anonymous" referrerpolicy="no-referrer" />
</head>
<body>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/components/prism-core.min.js" integrity="sha512-TbHaMJHEmRBDf9W3P7VcRGwEmVEJu7MO6roAE0C4yqoNHeIVo3otIX3zj1DOLtn7YCD+U8Oy1T9eMtG/M9lxRw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/plugins/autoloader/prism-autoloader.min.js" integrity="sha512-sv0slik/5O0JIPdLBCR2A3XDg/1U3WuDEheZfI/DI5n8Yqc3h5kjrnr46FGBNiUAJF7rE4LHKwQ/SoSLRKAxEA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.25.0/plugins/line-numbers/prism-line-numbers.min.js" integrity="sha512-dubtf8xMHSQlExGRQ5R7toxHLgSDZ0K7AunqPWHXmJQ8XyVIG19S1T95gBxlAeGOK02P4Da2RTnQz0Za0H0ebQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>

    <pre data-line="<?php echo $lineHighlight;?>"><code class="<?php echo $language;?> line-numbers"><?php echo $content?></code></pre>
</body>
</html>
<?php
if ($log) {
    LOG::writeTime("latest-highlight.php", $remote_addr, "Name: $basename $language $debugOut| Length: " . strlen($content) . " | Cache: $uptoDate->cacheStatus", $time_start);
}
?>
