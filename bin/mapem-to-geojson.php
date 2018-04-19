<?php

require __DIR__ . '/../vendor/autoload.php';

$dissections = json_decode(file_get_contents($argv[1]), true);
$dissection = $dissections[0];

$mapem = $dissection["_source"]["layers"]["itsis"]["itsis.MAPEM_element"];
$mapData = $mapem["itsis.map_element"];

$intersections = $mapData["itsis.intersections_tree"];

$features = [];
$mapLanes = [];

foreach ($intersections as $intersection) {
    $geo = $intersection["itsis.IntersectionGeometry_element"];

    $name = $geo["itsis.name"];
    $refPoint = [
        $geo["itsis.refPoint_element"]["itsis.lat"] / 10000000,
        $geo["itsis.refPoint_element"]["itsis.long"] / 10000000,
    ];

    $lanes = $geo["itsis.laneSet_tree"];

    foreach ($lanes as $lane) {
        $lane = $lane["itsis.GenericLane_element"];
        $nodes = $lane["itsis.nodeList_tree"]["itsis.nodes_tree"];

        $lanePositions = [];
        $lastPosition = $refPoint;

        foreach ($nodes as $node) {
            $delta = $node["itsis.NodeXY_element"]["itsis.delta_tree"];
            $delta = \reset($delta); // first item
            $delta = \array_values($delta); // remove key names

            $position = [
                $lastPosition[0] + ($delta[1] / 100 / 111111),
                $lastPosition[1] + ($delta[0] / 100 / (111111 * cos(deg2rad($lastPosition[0])))),
            ];

            $lanePositions[] = [$position[1], $position[0]];
            $lastPosition = $position;
        }

        if (isset($lane["itsis.connectsTo_tree"])) {
            $mapLanes[$lane["itsis.laneID"]] = [
                "position" => $lanePositions[0],
                "position_next" => $lanePositions[1] ?? $lanePositions[0],
                "connections" => \array_map(function ($connection) {
                    return [
                        "lane" => $connection["itsis.Connection_element"]["itsis.connectingLane_element"]["itsis.lane"],
                        "signal_group" => $connection["itsis.Connection_element"]["itsis.signalGroup"],
                    ];
                }, \array_values($lane["itsis.connectsTo_tree"])),
            ];
        } else {
            $mapLanes[$lane["itsis.laneID"]] = [
                "position" => $lanePositions[0],
                "position_next" => $lanePositions[1] ?? $lanePositions[0],
                "connections" => [],
            ];
        }

        $features[] = [
            "type" => "Feature",
            "properties" => [
                "stroke" => "#000000",
                "stroke-width" => 3,
                "stroke-opacity" => .5,
            ],
            "geometry" => [
                "type" => "LineString",
                "coordinates" => $lanePositions,
            ],
        ];
    }
}

foreach ($mapLanes as $laneId => $lane) {
    $start = $lane["position"];
    $beforeStart = $lane["position_next"];

    foreach ($lane["connections"] as $connection) {
        $end = $mapLanes[$connection["lane"]]["position"];
        $afterEnd = $mapLanes[$connection["lane"]]["position_next"];
        $signalGroup = $connection["signal_group"];

        $coordinates = [$start, $end];

        $features[] = [
            "type" => "Feature",
            "properties" => [
                "stroke" => "#0033dd",
                "stroke-width" => 3,
                "stroke-opacity" => .5,
                "name" => $signalGroup,
            ],
            "geometry" => [
                "type" => "LineString",
                "coordinates" => $coordinates,
            ],
        ];
    }
}

print \json_encode([
    "type" => "FeatureCollection",
    "features" => $features,
]) . PHP_EOL;
