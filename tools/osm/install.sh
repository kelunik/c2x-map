#!/bin/bash -e -x
# For use on clean Ubuntu 16 only!!!
# MapFig, Inc
# Usage: ./opentileserver.sh [web|ssl] [bright|carto] [pbf_url]"
# Example for Karlsruhe
# ./opentileserver.sh web carto http://download.geofabrik.de/europe/germany/baden-wuerttemberg/karlsruhe-regbez-latest.osm.pbf

set -x

WEB_MODE="${1}"  # no longer supported
OSM_STYLE="${2}" # bright, carto
PBF_URL="${3}";     # e.g. http://download.geofabrik.de/europe/germany-latest.osm.pbf
OSM_STYLE_XML=''

# User for DB and rednerd
OSM_USER='tile'; # system user for renderd and db
OSM_USER_PASS='secret';
OSM_PG_PASS='secret';
OSM_DB='gis'; # OSM database name
VHOST='localhost'

NP=$(grep -c 'model name' /proc/cpuinfo)
osm2pgsql_OPTS="--slim -d ${OSM_DB} --number-processes ${NP} --hstore"

touch /root/auth.txt

function style_osm_bright() {
    cd /usr/local/share/maps/style

    if [ ! -d 'osm-bright-master' ]; then
        wget -q https://github.com/mapbox/osm-bright/archive/master.zip
        unzip master.zip;
        mkdir -p osm-bright-master/shp
        rm master.zip
    fi

    for shp in 'land-polygons-split-3857' 'simplified-land-polygons-complete-3857'; do
        if [ ! -d "osm-bright-master/shp/${shp}" ]; then
            wget -q http://data.openstreetmapdata.com/${shp}.zip
            unzip ${shp}.zip;
            mv ${shp}/ osm-bright-master/shp/
            rm ${shp}.zip
            pushd osm-bright-master/shp/${shp}/
                shapeindex *.shp
            popd
        fi
    done

    if [ ! -d 'osm-bright-master/shp/ne_10m_populated_places' ]; then
        wget -q http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places.zip
        unzip ne_10m_populated_places.zip
        mkdir -p osm-bright-master/shp/ne_10m_populated_places
        rm ne_10m_populated_places.zip
        mv ne_10m_populated_places.* osm-bright-master/shp/ne_10m_populated_places/
    fi


    # 9 Configuring OSM Bright
    if [ $(grep -c '.zip' /usr/local/share/maps/style/osm-bright-master/osm-bright/osm-bright.osm2pgsql.mml) -ne 0 ]; then    #if we have zip in mml
        cd /usr/local/share/maps/style/osm-bright-master
        cp osm-bright/osm-bright.osm2pgsql.mml osm-bright/osm-bright.osm2pgsql.mml.orig
        sed -i.save 's|.*simplified-land-polygons-complete-3857.zip",|"file":"/usr/local/share/maps/style/osm-bright-master/shp/simplified-land-polygons-complete-3857/simplified_land_polygons.shp",\n"type": "shape",|' osm-bright/osm-bright.osm2pgsql.mml
        sed -i.save 's|.*land-polygons-split-3857.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/land-polygons-split-3857/land_polygons.shp",\n"type":"shape"|' osm-bright/osm-bright.osm2pgsql.mml
        sed -i.save 's|.*10m-populated-places-simple.zip"|"file":"/usr/local/share/maps/style/osm-bright-master/shp/ne_10m_populated_places/ne_10m_populated_places.shp",\n"type": "shape"|' osm-bright/osm-bright.osm2pgsql.mml

        sed -i.save '/name":[ \t]*"ne_places"/a"srs": "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"' osm-bright/osm-bright.osm2pgsql.mml
        # Delete
        # "srs": "",
        # "srs_name": "",
        LINE_FROM=$(grep -n '"srs": "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"' osm-bright/osm-bright.osm2pgsql.mml | cut -f1 -d':')
        let LINE_FROM=LINE_FROM+1
        let LINE_TO=LINE_FROM+1
        sed -i.save "${LINE_FROM},${LINE_TO}d" osm-bright/osm-bright.osm2pgsql.mml
    fi

    # 10 Compiling the stylesheet
    if [ ! -f /usr/local/share/maps/style/osm-bright-master/OSMBright/OSMBright.xml ]; then
        cd /usr/local/share/maps/style/osm-bright-master
        cp configure.py.sample configure.py
        sed -i.save 's|config\["path"\].*|config\["path"\] = path.expanduser("/usr/local/share/maps/style")|' configure.py
        sed -i.save "s|config\[\"postgis\"\]\[\"dbname\"\].*|config\[\"postgis\"\]\[\"dbname\"\]=\"${OSM_DB}\"|" configure.py
        ./configure.py
        ./make.py
        cd ../OSMBright/
        carto project.mml > OSMBright.xml
    fi
    OSM_STYLE_XML='/usr/local/share/maps/style/OSMBright/OSMBright.xml'
}

function install_npm_carto(){
    apt-get -y install npm nodejs nodejs-legacy
    # Latest 0.17.2 doesn't install!
    npm install -g carto@0.16.3
    ln -sf /usr/local/lib/node_modules/carto/bin/carto /usr/local/bin/carto
}

PG_VER=$(pg_config | grep '^VERSION' | cut -f4 -d' ' | cut -f1,2 -d.)

# 3 Create system user
if [ $(grep -c ${OSM_USER} /etc/passwd) -eq 0 ]; then    #if we don't have the OSM user
    useradd -m ${OSM_USER}
    echo ${OSM_USER}:${OSM_USER_PASS} | chpasswd
    echo "${OSM_USER} pass: ${OSM_USER_PASS}" >> /root/auth.txt
fi

cat >/etc/postgresql/${PG_VER}/main/pg_hba.conf <<CMD_EOF
local all all trust
host all all 127.0.0.1 255.255.255.255 md5
host all all 0.0.0.0/0 md5
host all all ::1/128 md5
CMD_EOF

/etc/init.d/postgresql start

if [ $(psql -Upostgres -c "select usename from pg_user" | grep -m 1 -c ${OSM_USER}) -eq 0 ]; then
    psql -Upostgres -c "create user ${OSM_USER} with password '${OSM_PG_PASS}';"
else
    psql -Upostgres -c "alter user ${OSM_USER} with password '${OSM_PG_PASS}';"
fi

if [ $(psql -Upostgres -c "select datname from pg_database" | grep -m 1 -c ${OSM_DB}) -eq 0 ]; then
    psql -Upostgres -c "create database ${OSM_DB} owner=${OSM_USER};"
fi

psql -Upostgres ${OSM_DB} <<EOF_CMD
\c ${OSM_DB}
CREATE EXTENSION hstore;
CREATE EXTENSION postgis;
ALTER TABLE geometry_columns OWNER TO ${OSM_USER};
ALTER TABLE spatial_ref_sys OWNER TO ${OSM_USER};
EOF_CMD

# 7 Install modtile and renderd
mkdir -p ~/src
if [ -z "$(which renderd)" ]; then    #if mapnik is not installed
    cd ~/src
    git clone git://github.com/openstreetmap/mod_tile.git
    if [ ! -d mod_tile ]; then "Error: Failed to download mod_tile"; exit 1; fi

    cd mod_tile

    # Fails on the first time for some reason...
    ./autogen.sh || ./autogen.sh
    ./configure

    #install breaks if dir exists
    if [ -d /var/lib/mod_tile ]; then rm -r /var/lib/mod_tile; fi

    make
    make install
    make install-mod_tile

    ldconfig
    cp  debian/renderd.init /etc/init.d/renderd
    #Update daemon config
    sed -i.save 's|^DAEMON=.*|DAEMON=/usr/local/bin/$NAME|' /etc/init.d/renderd
    sed -i.save 's|^DAEMON_ARGS=.*|DAEMON_ARGS="-c /usr/local/etc/renderd.conf"|' /etc/init.d/renderd
    sed -i.save "s|^RUNASUSER=.*|RUNASUSER=${OSM_USER}|" /etc/init.d/renderd

    chmod u+x /etc/init.d/renderd
    # ln -sf /etc/init.d/renderd /etc/rc2.d/S20renderd
    mkdir -p /var/run/renderd
    chown ${OSM_USER}:${OSM_USER} /var/run/renderd

    # Hacky way to start renderd after Postgres, because it doesn't recover otherwise...
    cat >/etc/cron.d/renderd <<CMD_EOF
@reboot root (sleep 30; /etc/init.d/renderd restart) &
CMD_EOF

    cd ../
    rm -rf mod_tile
fi

# 8 Stylesheet configuration
install_npm_carto;
mkdir -p /usr/local/share/maps/style
case $OSM_STYLE in
    bright)
        style_osm_bright
        ;;
    *)
        echo "Error: Unknown style"; exit 1;
        ;;
esac


# 11 Setting up your webserver
MAPNIK_PLUG=$(mapnik-config --input-plugins)
# remove commented lines, because daemon produces warning!
sed -i.save '/^;/d' /usr/local/etc/renderd.conf
sed -i.save 's/;socketname/socketname/' /usr/local/etc/renderd.conf
sed -i.save "s|^plugins_dir=.*|plugins_dir=${MAPNIK_PLUG}|" /usr/local/etc/renderd.conf
sed -i.save 's|^font_dir=.*|font_dir=/usr/share/fonts/truetype/|' /usr/local/etc/renderd.conf
sed -i.save "s|^XML=.*|XML=${OSM_STYLE_XML}|" /usr/local/etc/renderd.conf
sed -i.save 's|^HOST=.*|HOST=localhost|' /usr/local/etc/renderd.conf

mkdir -p /var/run/renderd
chown ${OSM_USER}:${OSM_USER} /var/run/renderd
mkdir -p /var/lib/mod_tile
chown ${OSM_USER}:${OSM_USER} /var/lib/mod_tile

# 12 Configure mod_tile
if [ ! -f /etc/apache2/conf-available/mod_tile.conf ]; then
    echo 'LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so' > /etc/apache2/conf-available/mod_tile.conf

    echo 'LoadTileConfigFile /usr/local/etc/renderd.conf
ModTileRenderdSocketName /var/run/renderd/renderd.sock
# Timeout before giving up for a tile to be rendered
ModTileRequestTimeout 0
# Timeout before giving up for a tile to be rendered that is otherwise missing
ModTileMissingRequestTimeout 30' > /etc/apache2/sites-available/tile.conf

    sed -i.save "/ServerAdmin/aInclude /etc/apache2/sites-available/tile.conf" /etc/apache2/sites-available/000-default.conf

    a2enconf mod_tile
fi

rm -f /var/www/html/index.html

cat >/etc/apache2/sites-available/000-default.conf <<CMD_EOF
<VirtualHost _default_:80>
ServerAdmin webmaster@localhost
Include /etc/apache2/sites-available/tile.conf
DocumentRoot /var/www/html
ServerName ${VHOST}

ErrorLog \${APACHE_LOG_DIR}/error.log
CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
CMD_EOF
ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/

#13 Tuning your system
sed -i 's/#\?shared_buffers.*/shared_buffers = 128MB/' /etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i 's/#\?checkpoint_segments.*/checkpoint_segments = 20/' /etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i 's/#\?maintenance_work_mem.*/maintenance_work_mem = 256MB/' /etc/postgresql/${PG_VER}/main/postgresql.conf

#Turn off autovacuum and fsync during load of PBF
sed -i 's/#\?fsync.*/fsync = off/' /etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i 's/#\?autovacuum.*/autovacuum = off/' /etc/postgresql/${PG_VER}/main/postgresql.conf

if [ $(grep -c 'kernel.shmmax=268435456' /etc/sysctl.conf) -eq 0 ]; then
    echo '# Increase kernel shared memory segments - needed for large databases
kernel.shmmax=268435456' >> /etc/sysctl.conf
    sysctl -w kernel.shmmax=268435456
fi

#13. Loading data into your server
PBF_FILE="/home/${OSM_USER}/${PBF_URL##*/}"
cd /home/${OSM_USER}
if [ ! -f ${PBF_FILE} ]; then
    wget ${PBF_URL}
    chown ${OSM_USER}:${OSM_USER} ${PBF_FILE}
fi

# Get available memory just before we call osm2pgsql!
let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f7 -d' ')-200
su -c "osm2pgsql ${osm2pgsql_OPTS} -C ${C_MEM} ${PBF_FILE}" - ${OSM_USER}

if [ $? -eq 0 ]; then    #If import went good
    rm -rf ${PBF_FILE}
fi

# Turn on autovacuum and fsync during load of PBF
sed -i.save 's/#\?fsync.*/fsync = on/' /etc/postgresql/${PG_VER}/main/postgresql.conf
sed -i.save 's/#\?autovacuum.*/autovacuum = on/' /etc/postgresql/${PG_VER}/main/postgresql.conf

ldconfig

# tiles need to have access without password
sed -i 's/local all all.*/local all all trust/'  /etc/postgresql/${PG_VER}/main/pg_hba.conf

# Fix for encoding, otherwise renderd doesn't start properly, see https://stackoverflow.com/a/5091083/23731
psql -Upostgres -c "update pg_database set encoding = pg_char_to_encoding('UTF8') where datname = 'gis';"
