sudo docker run --tmpfs /tmp --tmpfs /run --tmpfs /run/lock --cap-add SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro -p 80:80 --restart unless-stopped -d --name osm --tty --security-opt=seccomp:unconfined --security-opt apparmor:unconfined osm
