#!/bin/bash
set -e
export PREFIX="/opt/bes"
export PKG_CONFIG_PATH=/opt/bes/lib/pkgconfig
export PATH=/opt/bes/bin:$PATH

#
# HDF5
#
URL="https://github.com/OPENDAP/hyrax-dependencies/raw/master/downloads/hdf5-1.8.17-chunks.tar.bz2"
TAR=$(basename $URL)
DIR="${TAR%.*.*}"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
autoreconf -i
./configure CFLAGS="-O2 -fPIC -w" --prefix=$PREFIX
make -j 4
sudo make -j 4 install
cd ..

#
# NETCDF
#
URL="https://github.com/OPENDAP/hyrax-dependencies/raw/master/downloads/netcdf-c-4.4.1.1.tar.gz"
TAR=$(basename $URL)
DIR="${TAR%.*.*}"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
./configure --prefix=$PREFIX CPPFLAGS=-I$PREFIX/include	\
	CFLAGS="-fPIC -O2" --disable-dap LDFLAGS=-L$PREFIX/lib
make -j 4 all
sudo make install
cd ..

#
# GDAL
#
URL="http://download.osgeo.org/gdal/2.3.2/gdal-2.3.2.tar.xz"
TAR=$(basename $URL)
DIR="${TAR%.*.*}"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
./configure \
    --prefix=${PREFIX} \
    --with-geos \
    --with-geotiff=internal \
    --with-hide-internal-symbols \
    --with-libtiff=internal \
    --with-libz=internal \
    --with-threads \
    --without-bsb \
    --without-cfitsio \
    --without-cryptopp \
    --without-curl \
    --without-ecw \
    --without-expat \
    --without-fme \
    --without-freexl \
    --without-gif \
    --without-gif \
    --without-gnm \
    --without-grass \
    --without-hdf4 \
    --without-hdf5 \
    --without-idb \
    --without-ingres \
    --without-jasper \
    --without-jp2mrsid \
    --without-jpeg \
    --without-kakadu \
    --without-libgrass \
    --without-libkml \
    --without-libtool \
    --without-mrf \
    --without-mrsid \
    --without-mysql \
    --without-netcdf \
    --without-odbc \
    --without-ogdi \
    --without-pcidsk \
    --without-pcraster \
    --without-pcre \
    --without-perl \
    --without-pg \
    --without-php \
    --without-png \
    --without-python \
    --without-qhull \
    --without-sde \
    --without-sqlite3 \
    --without-webp \
    --without-xerces \
    --without-xml2 \
    --with-openjpeg 
make -j 8 all
make install
cd ..

#
# gridfields
#
URL=https://github.com/OPENDAP/hyrax-dependencies/raw/master/downloads/gridfields-1.0.5.tar.gz
TAR=$(basename $URL)
DIR="${TAR%.*.*}"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
sed -i '/AC_FUNC_MALLOC/ d' configure.ac 
autoreconf -i
./configure --disable-netcdf --prefix=$PREFIX CXXFLAGS="-fPIC -O2"
make -j 8 all
sudo make install
cd ..

#
# LIBDAP4
#
URL=https://github.com/OPENDAP/libdap4/archive/version-3.20.0.tar.gz
TAR=$(basename $URL)
DIR="libdap4-${TAR%.*.*}"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
autoreconf -i
./configure --prefix=$PREFIX
make -j 8 all
make check
sudo make install
cd ..

#
# BES
#
git clone https://github.com/OPENDAP/bes.git
cd bes
git checkout version-3.20.0 -b version-3.20.0

cat <<EOF >patch
diff --git configure.ac configure.ac
index beec0041..e7175ae8 100644
--- configure.ac
+++ configure.ac
@@ -54,7 +54,7 @@ AC_ARG_ENABLE([asan], [AS_HELP_STRING([--enable-asan], [Use the address sanitize
 
 AC_ARG_WITH([cmr], [AS_HELP_STRING([--with-cmr], [Build and include the CMR Module (built by default in developer mode)])], 
     [AM_CONDITIONAL([WITH_CMR], [true])],
-    [AM_CONDITIONAL([WITH_CMR], [AM_COND_IF([BES_DEVELOPER], [true], [flase])])])
+    [AM_CONDITIONAL([WITH_CMR], [AM_COND_IF([BES_DEVELOPER], [true], [false])])])
 
 dnl Only set CXXFLAGS if the caller didn't supply a value
 AS_IF([test -z "${CXXFLAGS+set}"], [CXXFLAGS="$cxx_debug_flags"])
diff --git dispatch/unit-tests/pvolT.cc dispatch/unit-tests/pvolT.cc
index 58e03364..8fe5c8fb 100644
--- dispatch/unit-tests/pvolT.cc
+++ dispatch/unit-tests/pvolT.cc
@@ -175,7 +175,7 @@ public:
             ostringstream c;
             c << "type" << i;
 
-            DBG(cerr << "    looking for " << s << endl);
+            DBG(cerr << "    looking for " << s.str() << endl);
 
             BESContainer *d = cpv->look_for(s.str());
             CPPUNIT_ASSERT(d);
@@ -220,7 +220,7 @@ public:
                 ostringstream c;
                 c << "type" << i;
 
-                DBG(cerr << "    looking for " << s << endl);
+                DBG(cerr << "    looking for " << s.str() << endl);
 
                 BESContainer *d = cpv->look_for(s.str());
                 CPPUNIT_ASSERT(d);
EOF
patch -p0 < patch
autoreconf -i
./configure --prefix=$PREFIX \
    --with-gdal=$PREFIX --with-hdf5=$PREFIX \
    --with-cfits-inc=/usr/include \
    --with-cfits-libdir=/usr/lib/x86_64-linux-gnu \
    --with-hdf4-include=/usr/include/hdf \
    --with-netcdf=$PREFIX
make -j 8
make check
sudo make install

cat <<EOS >/tmp/after_install.sh
#!/bin/bash
set -e
[ \$(getent group bes) ] || groupadd bes
[ \$(getent passwd bes) ] || useradd -g bes -s /bin/false -d /opt/bes -c "BES daemon" bes
chown -R bes:bes /opt/bes
sed -i 's/user_name/bes/' /opt/bes/etc/bes/bes.conf
sed -i 's/group_name/bes/' /opt/bes/etc/bes/bes.conf

cat <<EOF >/etc/systemd/system/bes.service
[Unit]
Description=OPeNDAP BES is a modular framework allowing access to data files
After=network.target auditd.service

[Service]
Type=forking
ExecStart=/opt/bes/bin/besctl start
ExecStop=/opt/bes/bin/besctl stop
ExecReload=/opt/bes/bin/besctl restart

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable bes
systemctl start bes
EOS
chmod u+x /tmp/after_install.sh

cat <<EOS >/tmp/before_remove.sh
#!/bin/bash
set -e
systemctl stop bes
systemctl disable bes
EOS
chmod u+x /tmp/before_remove.sh

cat <<EOS >/tmp/after_remove.sh
#!/bin/bash
set -e
rm -rf /etc/systemd/system/bes.service
systemctl daemon-reload
systemctl reset-failed
userdel bes
EOS
chmod u+x /tmp/after_remove.sh

fpm --prefix /opt/bes \
    -t deb \
    -n bes \
    -p $HOME \
    -s dir \
    -v 3.2.0 \
    --url https://opendap.org/software/hyrax-data-server \
    -m fbriol@groupcls.com \
    -d libcfitsio5 -d libcurl3 -d libcurl3-gnutls -d libhdf4-0 \
    -d libicu60 -d libjpeg-turbo8 -d libopenjp2-7 -d libuuid1 -d libxml2 \
    --description "Back-end server software framework for OPeNDAP
BES is a high-performance back-end server software framework for
OPeNDAP that allows data providers more flexibility in providing end
users views of their data. The current OPeNDAP data objects (DAS, DDS,
and DataDDS) are still supported, but now data providers can add new data
views, provide new functionality, and new features to their end users
through the BES modular design. Providers can add new data handlers, new
data objects/views, the ability to define views with constraints and
aggregation, the ability to add reporting mechanisms, initialization
hooks, and more." \
    --vendor OPeNDAP \
    --category network \
    --deb-priority extra \
    --deb-no-default-config-files \
    --deb-compression xz \
    --after-install=/tmp/after_install.sh \
    --before-remove=/tmp/before_remove.sh \
    --after-remove=/tmp/after_remove.sh \
    -C /opt/bes

