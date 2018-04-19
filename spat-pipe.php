<?php

use Amp\ByteStream\ResourceInputStream;
use Amp\Loop;

require __DIR__ . '/vendor/autoload.php';

use Amp\Redis;

Loop::run(function () {
    $redis = new Redis\Client("tcp://127.0.0.1:6379");
    $source = new ResourceInputStream(\STDIN);
    $buffer = "";

    while (null !== $chunk = yield $source->read()) {
        $buffer .= $chunk;

        while (($pos = \strpos($buffer, "\n")) !== false) {
            $line = \substr($buffer, 0, $pos);
            $buffer = \substr($buffer, $pos + 1);

            yield $redis->publish("spat", $line);
        }
    }
});