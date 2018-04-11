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

            list($stationId, $longitude, $latitude) = \explode(", ", \trim($line));

            $longitude /= 10000000;
            $latitude /= 10000000;

            yield $redis->publish("cam", \json_encode([
                "stationId" => $stationId,
                "position" => [$latitude, $longitude]
            ]));
        }
    }
});