<?php
echo "#SERVICE_ID_";
echo "T143_ID752332";
echo "_SERVICE_ID#<br>";

echo "#HTTP_CLIENT_IP_";
echo getenv('HTTP_CLIENT_IP');
echo "_HTTP_CLIENT_IP#<br>";

echo "#HTTP_X_FORWARDED_FOR_";
echo getenv('HTTP_X_FORWARDED_FOR');
echo "_HTTP_X_FORWARDED_FOR#<br>";

echo "#HTTP_X_FORWARDED_";
echo getenv('HTTP_X_FORWARDED');
echo "_HTTP_X_FORWARDED#<br>";

echo "#HTTP_FORWARDED_FOR_";
echo getenv('HTTP_FORWARDED_FOR');
echo "_HTTP_FORWARDED_FOR#<br>";

echo "#HTTP_FORWARDED_";
echo getenv('HTTP_FORWARDED');
echo "_HTTP_FORWARDED#<br>";

echo "#REMOTE_ADDR_";
echo getenv('REMOTE_ADDR');
echo "_REMOTE_ADDR#<br>";

echo "#REMOTE_ADDR2_";
echo $_SERVER['REMOTE_ADDR'];
echo "_REMOTE_ADDR2#<br>";
?>
