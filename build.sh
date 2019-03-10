set -e
#!/bin/bash
export PREFIX="/opt/bes"
export LOCAL="$HOME/local"
export PKG_CONFIG_PATH=$LOCAL/lib/pkgconfig:$PREFIX/lib/pkgconfig
export PATH=$LOCAL/bin:$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib
export NPROCESSORS=$(getconf _NPROCESSORS_ONLN)
sudo apt install -y build-essential bison flex libjpeg-turbo8-dev zlib1g-dev autoconf \
   libopenjp2-7-dev libtool-bin uuid-dev libcurl4-gnutls-dev libxml2-dev \
   libcppunit-dev libcppunit-1.14-0  git libreadline7 libncurses5-dev libreadline-dev \
   libcfitsio-dev libbz2-dev bc ruby ruby-dev rubygems
sudo mkdir /opt/bes
sudo chown $LOGNAME:$LOGNAME /opt/bes
sudo gem install --no-ri --no-rdoc fpm

#
# HDF4
#
URL="https://github.com/OPENDAP/hyrax-dependencies/raw/master/downloads/hdf-4.2.10.tar.gz"
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
./configure CFLAGS="-fPIC -w" \
    --disable-fortran --enable-production --disable-netcdf \
    --with-pic  --prefix=$LOCAL --disable-shared
make -j $NPROCESSORS
make -j install
# deletion of the hdf4 programs.
rm -rf $LOCAL/bin
cd ..

#
# HDF5
#
URL="https://github.com/OPENDAP/hyrax-dependencies/raw/master/downloads/hdf5-1.10.5.tar.bz2"
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
./configure CFLAGS="-O2 -fPIC -w" --prefix=$LOCAL --disable-shared
make -j $NPROCESSORS
make -j install
cd ..

#
# NETCDF
#
URL="https://github.com/Unidata/netcdf-c/archive/v4.6.2.tar.gz"
TAR=$(basename $URL)
DIR="netcdf-c-4.6.2"
if [ ! -e $TAR ]; then
    wget $URL
fi
if [ -d $DIR ]; then
    rm -rf $DIR
fi
tar -xvf $TAR
cd $DIR
./configure --prefix=$LOCAL CPPFLAGS=-I$LOCAL/include LIBS="-ldl" \
    CFLAGS="-fPIC -O2" LDFLAGS=-L$LOCAL/lib --disable-dap --disable-shared \
    --disable-filter-testing
make -j $NPROCESSORS all
make install
cd ..

#
# GDAL
#
URL="http://download.osgeo.org/gdal/2.3.3/gdal-2.3.3.tar.xz"
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
make -j $NPROCESSORS all
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
./configure --disable-netcdf --disable-shared --prefix=$LOCAL CXXFLAGS="-fPIC -O2"
make -j $NPROCESSORS all
make install
cd ..

#
# LIBDAP4
#
URL=https://github.com/OPENDAP/libdap4/archive/version-3.20.3.tar.gz
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
make -j $NPROCESSORS
make -j $NPROCESSORS check
make install
cd ..

#
# BES
#
git clone https://github.com/OPENDAP/bes.git
cd bes
git submodule init
git checkout version-3.20.3 -b version-3.20.3
git submodule update

cat <<EOF >patch
diff --git configure.ac configure.ac
index 7e674a84..7aa7a9b9 100644
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
diff --git modules/dmrpp_module/Makefile.am modules/dmrpp_module/Makefile.am
index 83385c59..c085161d 100644
--- modules/dmrpp_module/Makefile.am
+++ modules/dmrpp_module/Makefile.am
@@ -55,7 +55,7 @@ build_dmrpp_CPPFLAGS = $(AM_CPPFLAGS) $(H5_CPPFLAGS)
 build_dmrpp_SOURCES = $(BES_SRCS) $(BES_HDRS) $(BUILD_DMRPP) build_dmrpp.cc

 build_dmrpp_LDADD = $(BES_DISPATCH_LIB) $(DAP_MODULE_OBJS) $(BES_EXTRA_LIBS) \
-$(H5_LDFLAGS) $(H5_LIBS) $(DAP_SERVER_LIBS) $(DAP_CLIENT_LIBS) $(XML2_LIBS) -lz
+$(H5_LDFLAGS) $(H5_LIBS) $(XML2_LIBS) $(DAP_SERVER_LIBS) $(DAP_CLIENT_LIBS) -lz

 EXTRA_PROGRAMS =

diff --git modules/dmrpp_module/unit-tests/Makefile.am modules/dmrpp_module/unit-tests/Makefile.am
index d5d722f6..aadb1711 100644
--- modules/dmrpp_module/unit-tests/Makefile.am
+++ modules/dmrpp_module/unit-tests/Makefile.am
@@ -8,7 +8,7 @@ AM_CPPFLAGS = $(H5_CPPFLAGS) -I$(top_srcdir)/modules -I$(top_srcdir)/modules/dmr

 # Added -lz for ubuntu
 LIBADD = $(BES_DISPATCH_LIB) $(BES_DAP_LIB) $(BES_EXTRA_LIBS) \
-$(H5_LDFLAGS) $(H5_LIBS) $(DAP_SERVER_LIBS) $(DAP_CLIENT_LIBS) $(XML2_LIBS) -lz
+$(H5_LDFLAGS) $(H5_LIBS) $(XML2_LIBS) $(DAP_SERVER_LIBS) $(DAP_CLIENT_LIBS) -lz


 if CPPUNIT
EOF
patch -p0 < patch
autoreconf -i
./configure --prefix=$PREFIX \
    --with-gdal=$PREFIX --with-hdf5=$LOCAL --with-hdf4=$LOCAL \
    --with-cfits-inc=/usr/include \
    --with-cfits-libdir=/usr/lib/x86_64-linux-gnu \
    --with-netcdf=$LOCAL --with-libdap=$PREFIX
make -j $NPROCESSORS
make -j $NPROCESSORS check
make install
rm -rf $PREFIX/lib/pkgconfig
rm -rf $PREFIX/include
rm -rf $PREFIX/bin/gdal*
rm -rf $PREFIX/bin/dap*
rm -rf $PREFIX/bin/ogr*
rm -rf $PREFIX/bin/testepsg
rm -rf $PREFIX/bin/nearblack
find $PREFIX -name "*.a" -exec rm -rfv {} \;
find $PREFIX -name "*.la" -exec rm -rfv {} \;


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
Environment='LD_LIBRARY_PATH=/opt/bes/lib'
Type=forking
ExecStart=/opt/bes/bin/besctl start
ExecStop=/opt/bes/bin/besctl stop
ExecReload=/opt/bes/bin/besctl restart

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/profile.d/10-bes.sh
#!/bin/bash
export PATH=$PATH:/opt/bes/bin
EOF
chmod u+x /etc/profile.d/10-bes.sh

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
    -v 3.2.3 \
    --url https://opendap.org/software/hyrax-data-server \
    -m fbriol@groupcls.com \
    -d libcfitsio5 -d libcurl3-gnutls \
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

