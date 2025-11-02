<?php

# rm /scripts/php/highlight.php ; nano /scripts/php/highlight.php
# ./scripts/docker-exec.sh bash
# tail -f /tmp/php.log
include_once "globals.php";
include_once "Log.php";
include "common_functions.php";
include "UptoDate.php";

# common_functions.php
denyAccessFromExternal("highlight.php");

$time_start = microtime(true);

$uri = $_REQUEST['uri'];
$remote_addr = $_REQUEST['remote_addr'];

$log = (PHP_LOG_ENABLED === "true");
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
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/themes/prism.min.css" integrity="sha512-tN7Ec6zAFaVSG3TpNAKtk4DOHNpSwKHxxrsiw4GHKESGPs5njn/0sMCUMl2svV4wo4BK/rCP7juYz+zx+l6oeQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/9000.0.1/plugins/line-numbers/prism-line-numbers.min.css" integrity="sha512-3/cdM9qaJ5lBlzRKqwhMw+ZcNCVonz66BO6HgJudG/P1azm9wFrru31SsBa4T4Ew1AOH8HfDXSWS6emWwPl42A==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/plugins/line-numbers/prism-line-numbers.min.css" integrity="sha512-cbQXwDFK7lj2Fqfkuxbo5iD1dSbLlJGXGpfTDqbggqjHJeyzx88I3rfwjS38WJag/ihH7lzuGlGHpDBymLirZQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/plugins/line-highlight/prism-line-highlight.min.css" integrity="sha512-nXlJLUeqPMp1Q3+Bd8Qds8tXeRVQscMscwysJm821C++9w6WtsFbJjPenZ8cQVMXyqSAismveQJc0C1splFDCA==" crossorigin="anonymous" referrerpolicy="no-referrer" />
</head>
<body>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/components/prism-core.min.js" integrity="sha512-Uw06iFFf9hwoN77+kPl/1DZL66tKsvZg6EWm7n6QxInyptVuycfrO52hATXDRozk7KWeXnrSueiglILct8IkkA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/9000.0.1/plugins/line-numbers/prism-line-numbers.min.js" integrity="sha512-QTYXYEniHb1m0ZKtSyfpmw40uH9vPfV07vxsv/plIRMEiON4yOp2qoZiv/FTqFIOym4bdQ4+p9RtHaCMC0ApRw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/plugins/autoloader/prism-autoloader.min.js" integrity="sha512-SkmBfuA2hqjzEVpmnMt/LINrjop3GKWqsuLSSB3e7iBmYK7JuWw4ldmmxwD9mdm2IRTTi0OxSAfEGvgEi0i2Kw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.30.0/plugins/line-numbers/prism-line-numbers.min.js" integrity="sha512-BttltKXFyWnGZQcRWj6osIg7lbizJchuAMotOkdLxHxwt/Hyo+cl47bZU0QADg+Qt5DJwni3SbYGXeGMB5cBcw==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
    <pre data-line="<?php echo $lineHighlight;?>"><code class="<?php echo $language;?> line-numbers"><?php echo $content?></code></pre>
</body>
</html>
<?php
if ($log) {
    LOG::writeTime("highlight.php", $remote_addr, "Name: $basename $language $debugOut| Length: " . strlen($content), $time_start);
}
?>
