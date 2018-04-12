FROM ubuntu:16.04

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get clean
RUN apt-get update
RUN apt-get -y install \
    libboost-all-dev subversion git-core tar unzip wget bzip2 \
    build-essential autoconf libtool libxml2-dev libgeos-dev \
    libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node \
    munin libprotobuf-c-dev protobuf-c-compiler libfreetype6-dev \
    libpng12-dev libtiff5-dev libicu-dev libgdal-dev libcairo2-dev \
    libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev \
    ttf-unifont fonts-arphic-ukai fonts-arphic-uming fonts-thai-tlwg \
    lua5.1 liblua5.1-0-dev libgeotiff-epsg node-carto \
    postgresql postgresql-contrib postgis postgresql-9.5-postgis-2.2 \
    php libapache2-mod-php php-xml systemd dbus

RUN apt-get install -y osm2pgsql python-mapnik libmapnik3.0 mapnik-utils libmapnik-dev

COPY install.sh /root/install.sh
RUN bash /root/install.sh web bright http://download.geofabrik.de/europe/germany/baden-wuerttemberg/karlsruhe-regbez-latest.osm.pbf

RUN systemctl set-default multi-user.target

STOPSIGNAL SIGRTMIN+3

ENV init /lib/systemd/systemd
VOLUME [ "/sys/fs/cgroup" ]
ENTRYPOINT ["/lib/systemd/systemd"]
