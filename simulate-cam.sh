while true; do
    echo '{"type":"cam","data":{"orientation":105,"stationId": 6, "position": [49.00536,8.436]}}' | nc -w0 localhost 8001

    sleep 2
done
