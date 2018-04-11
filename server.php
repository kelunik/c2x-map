<?php

require __DIR__ . '/vendor/autoload.php';

use Amp\ByteStream\ResourceOutputStream;
use Amp\Http\Server\Options;
use Amp\Http\Server\Router;
use Amp\Http\Server\StaticContent\DocumentRoot;
use Amp\Http\Server\Websocket\Websocket;
use Amp\Log\ConsoleFormatter;
use Amp\Log\StreamHandler;
use Amp\Loop;
use Amp\Redis\SubscribeClient;
use Amp\Socket;
use Amp\Http\Server\Server;
use Kelunik\C2X\Map\CamPublisher;
use Monolog\Logger;

Loop::run(function () {
    $documentRoot = new DocumentRoot(__DIR__ . '/public');

    $redis = new SubscribeClient("tcp://127.0.0.1:6379");

    $router = new Router;
    $router->addRoute("GET", "/cams", new Websocket(new CamPublisher($redis)));
    $router->setFallback($documentRoot);

    $logHandler = new StreamHandler(new ResourceOutputStream(\STDOUT));
    $logHandler->setFormatter(new ConsoleFormatter);
    $logger = new Logger('server');
    $logger->pushHandler($logHandler);

    $options = (new Options)->withDebugMode();

    $server = new Server([
        Socket\listen("127.0.0.1:8000"),
        Socket\listen("[::1]:8000"),
    ], $router, $logger, $options);

    yield $server->start();
});