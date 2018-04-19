<?php

namespace Kelunik\C2X\Map;

use Amp\Http\Server\Request;
use Amp\Http\Server\Response;
use Amp\Http\Server\Websocket\Application;
use Amp\Http\Server\Websocket\Endpoint;
use Amp\Http\Server\Websocket\Message;
use Amp\Socket\Server;
use Amp\Socket\ServerSocket;
use Amp\Success;
use function Amp\asyncCall;
use function Amp\Socket\listen;

class Publisher implements Application {
    /** @var Endpoint */
    private $endpoint;

    /** @var Server */
    private $socket;

    public function __construct() {
        // nothing to do
    }

    public function onStart(Endpoint $endpoint) {
        $this->endpoint = $endpoint;
        $this->socket = listen('127.0.0.1:8001');

        asyncCall(function () {
            /** @var ServerSocket $client */
            while ($client = yield $this->socket->accept()) {
                asyncCall(function () use ($client) {
                    $buffer = '';

                    while (null !== $chunk = yield $client->read()) {
                        $buffer .= $chunk;

                        while (($pos = \strpos($buffer, "\n")) !== false) {
                            $line = \substr($buffer, 0, $pos);
                            $buffer = \substr($buffer, $pos + 1);

                            yield $this->endpoint->broadcast($line);
                        }
                    }
                });
            }
        });

        return new Success;
    }

    public function onHandshake(Request $request, Response $response) {
        return new Success($response);
    }

    public function onOpen(int $clientId, Request $request) {
        return new Success;
    }

    public function onData(int $clientId, Message $message) {
        return new Success;
    }

    public function onClose(int $clientId, int $code, string $reason) {
        return new Success;
    }

    public function onStop() {
        $this->socket->close();

        return new Success;
    }
}