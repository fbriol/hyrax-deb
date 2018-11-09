#!/bin/bash
set -e
apt install software-properties-common unzip
add-apt-repository ppa:webupd8team/java
apt update
apt install oracle-java8-installer

IP='192.168.56.102'
IP_MASK='192.168.56\\.\\d+/'

[ $(getent group tomcat) ] || groupadd tomcat
[ $(getent passwd tomcat) ] || useradd -g tomcat -s /bin/false -d /opt/tomcat -c "Apache Tomcat daemon" tomcat

URL=https://www-us.apache.org/dist/tomcat/tomcat-8/v8.5.34/bin/apache-tomcat-8.5.34.tar.gz
wget $URL
mkdir -p /opt/tomcat
tar xzvf $(basename $URL) -C /opt/tomcat --strip-components=1
chown -R tomcat:tomcat /opt/tomcat
mkdir -p /opt/tomcat/hyrax
chown -R tomcat:tomcat /opt/tomcat/hyrax

cat <<EOF >/etc/systemd/system/tomcat.service 
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment='JAVA_HOME=/usr/lib/jvm/java-8-oracle/'
Environment='OLFS_CONFIG_DIR=/opt/tomcat/hyrax'
Environment='CATALINA_PID=/opt/tomcat/temp/tomcat.pid'
Environment='CATALINA_HOME=/opt/tomcat'
Environment='CATALINA_BASE=/opt/tomcat'
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sed -i '$ d' /opt/tomcat/conf/tomcat-users.xml
cat <<EOF >>/opt/tomcat/conf/tomcat-users.xml
  <role rolename="admin-gui"/>
  <role rolename="manager-gui"/>
  <user username="admin" password="s3cret" roles="manager-gui,admin-gui"/>
</tomcat-users>
EOF

sed -i "s/:1|0:0:0:0:0:0:0:1/:1|0:0:0:0:0:0:0:1|$IP_MASK" /opt/tomcat/webapps/manager/META-INF/context.xml
sed -i "s/:1|0:0:0:0:0:0:0:1/:1|0:0:0:0:0:0:0:1|$IP_MASK" /opt/tomcat/webapps/host-manager/META-INF/context.xml

keytool -genkey -alias tomcat -keyalg RSA -keystore /opt/tomcat/keystore \
    -dname "cn=Unknown, ou=Unknown, o=Unknown, c=Unknown"  \
    -storepass s3cret -keypass s3cret

cat <<EOF >/opt/tomcat/conf/server.xml  
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <!-- Prevent memory leaks due to use of particular java/javax APIs-->
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <!-- Global JNDI resources
       Documentation at /docs/jndi-resources-howto.html
  -->
  <GlobalNamingResources>
    <!-- Editable user database that can also be used by
         UserDatabaseRealm to authenticate users
    -->
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <Executor name="tomcatThreadPool" namePrefix="catalina-exec-"
        maxThreads="200" minSpareThreads="4"/>

    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />

    <Connector protocol="org.apache.coyote.http11.Http11NioProtocol"
            port="8443" maxThreads="200"
            scheme="https" secure="true" SSLEnabled="true"
            KeystoreFile="/opt/tomcat/keystore"
            KeystorePass="s3cret"
            clientAuth="false" sslProtocol="TLS" />

    <!-- Define an AJP 1.3 Connector on port 8009 -->
    <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

      </Host>
    </Engine>
  </Service>
</Server>
EOF

URL="https://www.opendap.org/pub/olfs/olfs-1.18.0-webapp.tgz"
FILENAME=/tmp/$(basename $URL)
DIR="${FILENAME%.*}"
wget $URL -O $FILENAME
tar -C /tmp -xvf $FILENAME
unzip -o $DIR/opendap.war -d /opt/tomcat/webapps/opendap/ 
rm -rfv $FILENAME $DIR
chown tomcat:tomcat -R /opt/tomcat/webapps/opendap/ 
chmod 700 /opt/tomcat/webapps/opendap/WEB-INF/conf/logs 
sed -i "s/binary_button('dap.nc4')/binary_button('nc4')/" /opt/tomcat/webapps/opendap/xsl/dap2_ifh.xsl
sed -i "s/binary_button('dap.nc4')/binary_button('nc4')/" /opt/tomcat/webapps/opendap/xsl/dap4_ifh.xsl
sed -i "s/binary_button('dap.nc')/binary_button('nc')/" /opt/tomcat/webapps/opendap/xsl/dap4_ifh.xsl

URL="https://github.com/Reading-eScience-Centre/ncwms/releases/download/ncwms-2.4.1/ncWMS2.war"
FILENAME=/tmp/$(basename $URL)
wget $URL -O $FILENAME
unzip -o $FILENAME -d /opt/tomcat/webapps/ncWMS2/ 
chown tomcat:tomcat -R /opt/tomcat/webapps/ncWMS2/ 
sed -i '$ d' /opt/tomcat/conf/tomcat-users.xml
cat <<EOF >>/opt/tomcat/conf/tomcat-users.xml
  <role rolename="ncWMS-admin"/>
  <user username="admin" password="s3cret" roles="ncWMS-admin"/>
</tomcat-users>
EOF

cat <<EOF >/opt/tomcat/.ncWMS2/config.xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<config>
    <datasets>
        <!--dataset id="coads_climatology" title="COADS via DAP2" location="http://localhost:8080/opendap/data/nc/coads_climatology.nc" queryable="true" downloadable="false" dataReaderClass="" copyrightStatement="" moreInfo="" disabled="false" updateInterval="-1">
            <variables/>
        </dataset -->
    </datasets>
    <cache enabled="true">
        <inMemorySizeMB>256</inMemorySizeMB>
        <elementLifetimeMinutes>10.0</elementLifetimeMinutes>
    </cache>
    <dynamicServices>
        <dynamicService alias="lds" servicePath="http://localhost/opendap/" datasetIdMatch=".*" dataReaderClass="" copyrightStatement="" moreInfoUrl="" disabled="false" queryable="true" downloadable="false"/>
    </dynamicServices>
    <contact>
        <name>OPeNDAP Docker</name>
        <organization>OPeNDAP</organization>
        <telephone></telephone>
        <email>support@opendap.og</email>
    </contact>
    <server>
        <title>ncWMS Server</title>
        <allowFeatureInfo>true</allowFeatureInfo>
        <maxImageWidth>1024</maxImageWidth>
        <maxImageHeight>1024</maxImageHeight>
        <abstract></abstract>
        <keywords></keywords>
        <url>http://$IP/ncWMS2</url>
        <allowglobalcapabilities>true</allowglobalcapabilities>
    </server>
</config>
EOF
chown tomcat:tomcat /opt/tomcat/.ncWMS2/config.xml

service tomcat start
service tomcat stop

cat <<EOF >/opt/tomcat/hyrax/viewers.xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  ~ /////////////////////////////////////////////////////////////////////////////
  ~ // This file is part of the "Hyrax Data Server" project.
  ~ //
  ~ //
  ~ // Copyright (c) 2013 OPeNDAP, Inc.
  ~ // Author: Nathan David Potter  <ndp@opendap.org>
  ~ //
  ~ // This library is free software; you can redistribute it and/or
  ~ // modify it under the terms of the GNU Lesser General Public
  ~ // License as published by the Free Software Foundation; either
  ~ // version 2.1 of the License, or (at your option) any later version.
  ~ //
  ~ // This library is distributed in the hope that it will be useful,
  ~ // but WITHOUT ANY WARRANTY; without even the implied warranty of
  ~ // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  ~ // Lesser General Public License for more details.
  ~ //
  ~ // You should have received a copy of the GNU Lesser General Public
  ~ // License along with this library; if not, write to the Free Software
  ~ // Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
  ~ //
  ~ // You can contact OPeNDAP, Inc. at PO Box 112, Saunderstown, RI. 02874-0112.
  ~ /////////////////////////////////////////////////////////////////////////////
  -->

<ViewersConfig>

    <JwsHandler className="opendap.webstart.IdvViewerRequestHandler">
        <JnlpFileName>idv.jnlp</JnlpFileName>
    </JwsHandler>

    <JwsHandler className="opendap.webstart.NetCdfToolsViewerRequestHandler">
        <JnlpFileName>idv.jnlp</JnlpFileName>
    </JwsHandler>

    <JwsHandler className="opendap.webstart.AutoplotRequestHandler" />


    <!--
     If you are using Hyrax with our ncWMS release you'll need to configure both
     Hyrax (in the section below) and ncWMS to make it all work. Detailed instructions
     for how to do this can be found at: http://docs.opendap.org/index.php/Hyrax_WMS

     Note: Un-commenting the two WebServiceHandler definitions below will cause Hyrax
     to add links to the WMS service and the Godiva web client to each dataset's "viewers"
     page and to the list of default services used in both static and dynamic THREDDS
     catalogs returned by the server.
     -->

    <WebServiceHandler className="opendap.viewers.NcWmsService" serviceId="ncWms" >
        <applicationName>Web Mapping Service</applicationName>
        <NcWmsService href="http://$IP/ncWMS2/wms" base="http://$IP/ncWMS2/wms" ncWmsDynamicServiceId="lds" />
    </WebServiceHandler>

    <WebServiceHandler className="opendap.viewers.GodivaWebService" serviceId="godiva" >
        <applicationName>Godiva WMS GUI</applicationName>
        <NcWmsService href="http://$IP:8080/ncWMS2/wms" base="/ncWMS2/wms" ncWmsDynamicServiceId="lds"/>
        <Godiva href="http://$IP/ncWMS2/Godiva3.html" base="http://$IP/ncWMS2/Godiva3.html"/>
    </WebServiceHandler>

    <!--
    <WebServiceHandler className="opendap.viewers.WcsService" serviceId="WCS-COADS" >
        <ApplicationName>COADS Climatology WCS Service/</ApplicationName>
        <ServiceEndpoint>http://$IP/opendap/wcs/</ServiceEndpoint>
        <MatchRegex>^.*coads.*\.nc$</MatchRegex>
        <DynamicServiceId>coads</DynamicServiceId>
    </WebServiceHandler>
    -->
</ViewersConfig>
EOF

apt install apache2
mv /etc/apache2/mods-available/proxy.load /etc/apache2/mods-enabled
mv /etc/apache2/mods-available/proxy_ajp.load /etc/apache2/mods-enabled

cat <<EOF >/etc/apache2/sites-enabled/000-default.conf 
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        #ServerName www.example.com

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        <Proxy *>
          AddDefaultCharset Off
          Order deny,allow
          Allow from all
        </Proxy>

        ProxyPass /opendap ajp://localhost:8009/opendap
        ProxyPass /ncWMS2 ajp://localhost:8009/ncWMS2
        ProxyPassReverse /opendap ajp://localhost:8009/opendap
        
        <Location />
          # Insert filter
          SetOutputFilter DEFLATE

          # Netscape 4.x has some problems...
          BrowserMatch ^Mozilla/4 gzip-only-text/html

          # Netscape 4.06-4.08 have some more problems
          BrowserMatch ^Mozilla/4\.0[678] no-gzip

          # MSIE masquerades as Netscape, but it is fine
          # BrowserMatch \bMSIE !no-gzip !gzip-only-text/html

          # NOTE: Due to a bug in mod_setenvif up to Apache 2.0.48
          # the above regex won't work. You can use the following
          # workaround to get the desired effect:
          BrowserMatch \bMSI[E] !no-gzip !gzip-only-text/html

          # Don't compress images
          SetEnvIfNoCase Request_URI \
          \.(?:gif|jpe?g|png)$ no-gzip dont-vary

          # Make sure proxies don't deliver the wrong content
          # Header append Vary User-Agent env=!dont-vary
        </Location>

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOF