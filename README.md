<center>

[![](./logo.png)](https://github.com/kelunik/c2x-map)

</center>

This repository contains a visualization tool for several V2X messages.
These messages aren't processed by the tools in this repository, but only visualized.
Another tool needs to parse the received messages and send the relevant information as JSON blobs to the server listening on port `8001` locally.
The server broadcasts those messages to any connected WebSocket client then.
The app is served on port `8000` once the server is started via `php server.php`.

There's visualization support for CAMs and SPATEMs, but currently not for MAPEMs. MAPEMs currently need to be manually imported from a Wireshark JSON export of a received MAPEM.
A script is provided in `bin/mapem-to-geojson.php`.
The result needs to be hardcoded in `public/index.html`.
