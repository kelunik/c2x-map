<?php

namespace Kelunik\C2X\Map;

use Amp\Http\Server\Request;
use Amp\Http\Server\Response;
use Amp\Http\Server\Websocket\Application;
use Amp\Http\Server\Websocket\Endpoint;
use Amp\Http\Server\Websocket\Message;
use Amp\Redis;
use Amp\Success;
use function Amp\asyncCall;

class CamPublisher implements Application {
    /** @var Endpoint */
    private $endpoint;

    /** @var Redis\SubscribeClient */
    private $redis;

    public function __construct(Redis\SubscribeClient $redis) {
        $this->redis = $redis;
    }

    public function onStart(Endpoint $endpoint) {
        $this->endpoint = $endpoint;

        asyncCall(function () {
            /** @var Redis\Subscription $subscription */
            $subscription = yield $this->redis->subscribe('cam');

            while (yield $subscription->advance()) {
                $cam = $subscription->getCurrent();
                $this->endpoint->broadcast($cam);
            }
        });

        asyncCall(function () {
            /** @var Redis\Subscription $subscription */
            $subscription = yield $this->redis->subscribe('spat');

            while (yield $subscription->advance()) {
                $spat = $subscription->getCurrent();
                $this->endpoint->broadcast($spat);
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
        return new Success;
    }
}