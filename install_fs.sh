# Author:      Rodrigo Cuadra
# Date:        April-2025
# Support:     rcuadra@aplitel.com
# Description: This script automates the installation of FreeSWITCH with PostgreSQL integration from source.

# Color codes for terminal output
green="\033[00;32m"
red="\033[0;31m"
txtrst="\033[00;0m"

# Welcome message
echo -e "****************************************************"
echo -e "*     Welcome to the FreeSWITCH Installation       *"
echo -e "*         All options are mandatory                *"
echo -e "****************************************************"

# Set default values for FreeSWITCH configuration
fs_database="freeswitch"
fs_user="freeswitch"
fs_password="fs2025"
fs_cdr_database="freeswitch_cdr"
fs_cdr_user="freeswitch"
fs_cdr_password="fs2025"
fs_default_password="r2a2025"

# Load configuration from file if it exists
filename="config.txt"
if [ -f "$filename" ]; then
    echo -e "Config file found. Loading settings..."
    n=1
    while read -r line; do
        case $n in
            1) fs_database=${line:-$fs_database} ;;
            2) fs_user=${line:-$fs_user} ;;
            3) fs_password=${line:-$fs_password} ;;
            4) fs_cdr_database=${line:-$fs_cdr_database} ;;
            5) fs_cdr_user=${line:-$fs_cdr_user} ;;
            6) fs_cdr_password=${line:-$fs_cdr_password} ;;
            7) fs_default_password=${line:-$fs_default_password} ;;
        esac
        n=$((n+1))
    done < "$filename"
fi

# Prompt user to confirm or change default values
echo -e "Please confirm or change the following configuration settings:"
read -p "FreeSWITCH Database Name [$fs_database]: " input && fs_database="${input:-$fs_database}"
read -p "FreeSWITCH User Name [$fs_user]: " input && fs_user="${input:-$fs_user}"
read -p "FreeSWITCH Password [$fs_password]: " input && fs_password="${input:-$fs_password}"
read -p "Ring2All CDR Database Name [$fs_cdr_database]: " input && fs_cdr_database="${input:-$fs_cdr_database}"
read -p "Ring2All CDR User Name [$fs_cdr_user]: " input && fs_cdr_user="${input:-$fs_cdr_user}"
read -p "Ring2All CDR Password [$fs_cdr_password]: " input && fs_cdr_password="${input:-$fs_cdr_password}"
read -p "FreeSWITCH Default Password for SIP [$fs_default_password]: " input && fs_default_password="${input:-$fs_default_password}"

# Display confirmed configuration
echo -e "Confirmed Configuration:"
echo -e "FreeSWITCH Database Name.............> $fs_database"
echo -e "FreeSWITCH User Name.................> $fs_user"
echo -e "FreeSWITCH Password..................> $fs_password"
echo -e "Ring2All CDR Database Name...........> $fs_cdr_database"
echo -e "Ring2All CDR User Name...............> $fs_cdr_user"
echo -e "Ring2All CDR Password................> $fs_cdr_password"
echo -e "FreeSWITCH Default Password for SIP..> $fs_default_password"

# Confirm configuration before proceeding
echo -e "***************************************************"
echo -e "*          Check Information                      *"
echo -e "***************************************************"
while [[ "$veryfy_info" != "yes" && "$veryfy_info" != "no" ]]; do
    read -p "Are you sure to continue with these settings? yes,no > " veryfy_info
done

if [ "$veryfy_info" = "yes" ]; then
    echo -e "*****************************************"
    echo -e "*   Starting to run the scripts         *"
    echo -e "*****************************************"
else
    echo -e "*   Exiting the script. Please restart.  *"
    exit 1
fi

# Save configuration to file
echo -e "$fs_database" > config.txt
echo -e "$fs_user" >> config.txt
echo -e "$fs_password" >> config.txt
echo -e "$fs_cdr_database" >> config.txt
echo -e "$fs_cdr_user" >> config.txt
echo -e "$fs_cdr_password" >> config.txt

echo -e "************************************************************"
echo -e "*              Installing essential packages               *"
echo -e "************************************************************"
# Install basic dependencies
apt update && apt upgrade -y
apt install -y sudo gnupg2 wget lsb-release curl sngrep net-tools unzip software-properties-common

# Install PostgreSQL
echo -e "************************************************************"
echo -e "*                    Installing PostgreSQL                 *"
echo -e "************************************************************"
sudo apt install -y postgresql postgresql-contrib lua-sql-postgres
sudo apt install -y odbc-postgresql
sudo apt install -y unixodbc

# Enable and start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Setup PostgreSQL
echo -e "************************************************************"
echo -e "*          Create the freeswitch database and user.        *"
echo -e "************************************************************"
# Create databases and user
cd /tmp
sudo -u postgres psql -c "CREATE ROLE $fs_user WITH LOGIN PASSWORD '$fs_password'";
sudo -u postgres psql -c "CREATE DATABASE $fs_database OWNER $fs_user";
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $fs_database TO $fs_user";

# Create fs_cdr database
echo -e "************************************************************"
echo -e "*                Create fs_cdr database              *"
echo -e "************************************************************"
wget https://raw.githubusercontent.com/rodrigocuadra/Freeswitch-Stress-Test/refs/heads/main/fs_cdr.sql
sed -i "s/\\\$fs_cdr_database/$fs_cdr_database/g; \
        s/\\\$fs_cdr_user/$fs_cdr_user/g" fs_cdr.sql
sudo -u postgres psql -f fs_cdr.sql

# Download and Install FreeSWITCH from source
echo -e "************************************************************"
echo -e "*     Installing FreeSWITCH version 1.10.12 from source     *"
echo -e "************************************************************"

# Install required packages
echo -e "************************************************************"
echo -e "* Install dependencies required for running FreeSwitch     *"
echo -e "************************************************************"
sudo apt install --yes build-essential pkg-config uuid-dev git zlib1g-dev \
  libjpeg-dev libsqlite3-dev libcurl4-openssl-dev libpcre3-dev libspeexdsp-dev \
  libldns-dev libedit-dev libtiff5-dev yasm libopus-dev libsndfile1-dev unzip \
  libavformat-dev libswscale-dev liblua5.2-dev liblua5.2-0 cmake \
  unixodbc-dev autoconf automake ntpdate libxml2-dev libpq-dev libpq5 sngrep \
  libswresample-dev libspeex-dev git dpkg-dev automake autoconf libtool \
  libncurses5-dev libssl-dev python3-dev libspandsp-dev libgsm1-dev libvpx-dev

# Clone and build dependencies
echo -e "************************************************************"
echo -e "*                   Install libks.                         *"
echo -e "************************************************************"
cd /usr/src/ 
sudo git clone https://github.com/signalwire/libks.git
cd /usr/src/libks/
sudo cmake . && sudo make && sudo make install
sudo ldconfig && sudo ldconfig -p | sudo  grep libks

echo -e "************************************************************"
echo -e "*                   Install signalwire                     *"
echo -e "************************************************************"
cd /usr/src/ 
sudo git clone https://github.com/signalwire/signalwire-c.git
cd /usr/src/signalwire-c/
sudo cmake . && sudo make && sudo make install
sudo ldconfig && sudo ldconfig -p | sudo  grep signalwire

echo -e "************************************************************"
echo -e "*              Install spandsp (optional ):                *"
echo -e "************************************************************"
cd /usr/src/ 
sudo git clone https://github.com/freeswitch/spandsp
cd /usr/src/spandsp/
sudo ./bootstrap.sh && sudo ./configure && sudo make && sudo make install
sudo ldconfig && sudo ldconfig -p | sudo  grep spandsp

echo -e "************************************************************"
echo -e "*                     Install Sofia-sip:                   *"
echo -e "************************************************************"
cd /usr/src/ 
sudo git clone https://github.com/freeswitch/sofia-sip
cd /usr/src/sofia-sip/
sudo ./bootstrap.sh && sudo ./configure && sudo make && sudo make install
sudo ldconfig && sudo ldconfig -p | sudo  grep sofia

# Clone from the official FreeSWITCH GitHub repository Download Freeswitch Version 1.10.12
echo -e "************************************************************"
echo -e "*   Clone from the official FreeSWITCH GitHub repository   *"
echo -e "************************************************************"
cd /usr/src/ 
git clone https://github.com/signalwire/freeswitch.git -bv1.10.12 freeswitch
cd freeswitch
git config pull.rebase true
# ./bootstrap.sh -j
./bootstrap.sh
./configure

# Compiling and installing FreeSwitch from source
echo -e "************************************************************"
echo -e "*       Compiling and installing FreeSwitch from source    *"
echo -e "************************************************************"
./configure --disable-dependency-tracking --enable-core-odbc-support --enable-core-odbc-support --enable-core-pgsql-support
sudo make clean
sudo make
sudo make install
sudo make samples

# Install audio files and music on hold
echo -e "************************************************************"
echo -e "*            Now compile sounds and music on hold          *"
echo -e "************************************************************"
sudo make cd-sounds-install cd-moh-install

# Create simlinks to use services easily.
echo -e "************************************************************"
echo -e "*           Create simlinks to use services easily.        *"
echo -e "************************************************************"
sudo ln -sf /usr/local/freeswitch/conf /etc/freeswitch
sudo ln -sf /usr/local/freeswitch/bin/fs_cli /usr/bin/fs_cli
sudo ln -sf /usr/local/freeswitch/bin/freeswitch /usr/sbin/freeswitch

# Add new group and user with less privileges to run FreeSWITCH service
echo -e "************************************************************"
echo -e "*        Add new group and user with less privileges       *"
echo -e "*                to run FreeSWITCH service.                *"
echo -e "************************************************************"
sudo groupadd freeswitch
sudo adduser --quiet --system --home /usr/local/freeswitch --gecos 'FreeSWITCH open source softswitch' --ingroup freeswitch freeswitch --disabled-password
sudo chown -R freeswitch:freeswitch /usr/local/freeswitch/
sudo chmod -R ug=rwX,o= /usr/local/freeswitch/
# Check if the directory /usr/local/freeswitch/bin/ exists before applying chmod
if [ -d "/usr/local/freeswitch/bin/" ]; then
  sudo chmod -R u=rwx,g=rx /usr/local/freeswitch/bin/
else
  echo "Directorio /usr/local/freeswitch/bin/ no existe. Creando..."
  sudo mkdir -p /usr/local/freeswitch/bin/
  sudo chown freeswitch:freeswitch /usr/local/freeswitch/bin/
  sudo chmod -R u=rwx,g=rx /usr/local/freeswitch/bin/
fi

# Finally, You can Run and connect to Freeswitch
echo -e "************************************************************"
echo -e "*       Finally, You can Run and connect to Freeswitch     *"
echo -e "************************************************************"
sudo freeswitch -u freeswitch -g freeswitch -c -ncwait
sudo freeswitch -stop

# Add FreeSwitch Service(dameon)
echo -e "************************************************************"
echo -e "*               Add FreeSwitch Service(dameon).            *"
echo -e "************************************************************"
cat << 'EOF' > /etc/systemd/system/freeswitch.service
    [Unit]
    Description=freeswitch
    Wants=network-online.target
    Requires=network.target local-fs.target
    After=network.target network-online.target local-fs.target

    [Service]
    ; service
    Type=forking
    PIDFile=/usr/local/freeswitch/run/freeswitch.pid
    Environment="DAEMON_OPTS=-nonat"
    Environment="USER=freeswitch"
    Environment="GROUP=freeswitch"
    EnvironmentFile=-/etc/default/freeswitch
    ExecStartPre=/bin/chown -R ${USER}:${GROUP} /usr/local/freeswitch
    ExecStart=/usr/local/freeswitch/bin/freeswitch -u ${USER} -g ${GROUP} -ncwait ${DAEMON_OPTS}
    TimeoutSec=45s
    Restart=always

    [Install]
    WantedBy=multi-user.target
EOF
    
echo -e "************************************************************"
echo -e "*          Reload systemd dameon Start FreeSwitch          *"
echo -e "*               service and enable it on boot              *"
echo -e "************************************************************"
sudo chmod ugo+x /etc/systemd/system/freeswitch.service
sudo systemctl daemon-reload
sudo systemctl enable freeswitch.service

# Enabling Logging in FreeSwitch
echo -e "************************************************************"
echo -e "*              Enabling Logging in FreeSwitch.             *"
echo -e "************************************************************"
sed -i 's/^\(\s*\)<!--\(<param name="logfile" value="\/var\/log\/freeswitch.log"\/>\)-->/\1\2/' /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml
sed -i 's|/var/log/freeswitch.log|/var/log/freeswitch/freeswitch.log|g' /usr/local/freeswitch/conf/autoload_configs/logfile.conf.xml
sudo mkdir -p /var/log/freeswitch
sudo chown -R freeswitch:freeswitch /var/log/freeswitch
chmod 755 /var/log/freeswitch

# Install LUA
echo -e "************************************************************"
echo -e "*              Install LUA 5.2 and pgsql driver            *"
echo -e "************************************************************"
sudo apt-get -y install lua5.2 luarocks libpq-dev liblua5.2-dev
sudo luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql
chown freeswitch:freeswitch /usr/local/lib/lua/5.2/luasql/postgres.so
# Verify that the module is installed correctly
lua -e "require('luasql.postgres'); print('Lua PostgreSQL installed successfully')"

# Enable and start FreeSWITCH service
echo -e "************************************************************"
echo -e "*           Enabling and starting FreeSWITCH              *"
echo -e "************************************************************"
systemctl enable freeswitch
systemctl start freeswitch

# Adding database connection data for CDRs
echo -e "************************************************************"
echo -e "*          Adding database connection data for CDRs        *"
echo -e "************************************************************"
# Path to configuration file
cdr_pg_csv_conf="/etc/freeswitch/autoload_configs/cdr_pg_csv.conf.xml"
# Check if file exists before modifying it
if [ -f "$cdr_pg_csv_conf" ]; then
  # Adding the Connection lines to the database
  sed -i '/<settings>/a\ \ \ \ <param name="db-info" value="host=127.0.0.1 port=5432 dbname='$fs_cdr_database' user='$fs_cdr_user' password='$fs_cdr_password' connect_timeout=10"/>\n\ \ \ \ <param name="db-table" value="cdr"/>' "$cdr_pg_csv_conf"
  # Comment out the original connection line
  sed -i 's#^\(\s*\)<param name="db-info" value="host=localhost dbname=cdr connect_timeout=10" />#\1<!-- <param name="db-info" value="host=localhost dbname=cdr connect_timeout=10" /> -->#' "$cdr_pg_csv_conf"
  echo "✅ $cdr_pg_csv_conf file updated successfully."
else
  echo "❌ The file $cdr_pg_csv_conf does not exist."
fi

echo -e "************************************************************"
echo -e "*  Inserting core-db-dsn on line 181 of switch.conf.xml    *"
echo -e "************************************************************"
# Path to configuration file
switch_conf="/etc/freeswitch/autoload_configs/switch.conf.xml"
# Check if file exists before modifying it
if [ -f "$switch_conf" ]; then
  # Adding the Connection lines to the database on line 181
  sed -i "181i\    <param name=\"core-db-dsn\" value=\"odbc://freeswitch\" />" "$switch_conf"
  echo "✅ Line successfully inserted on line 181 of $switch_conf."
else
  echo "❌ The $switch_conf file does not exist."
fi

echo -e "************************************************************"
echo -e "*Change context from public to default in internal profiles*"
echo -e "************************************************************"
# Path to configuration file
internal_xml="/etc/freeswitch/sip_profiles/internal.xml"
sed -i 's|<param name="context" value="public"/>|<param name="context" value="default"/>|' "$internal_xml"

internal_xml="/etc/freeswitch/sip_profiles/internal-ipv6.xml"
sed -i 's|<param name="context" value="public"/>|<param name="context" value="default"/>|' "$internal_xml"

# Configure ODBC for PostgreSQL
echo -e "************************************************************"
echo -e "*    Configuring ODBC for PostgreSQL (odbc.ini setup)     *"
echo -e "************************************************************"

cat << EOF > /etc/odbc.ini
[freeswitch]
Description         = PostgreSQL
Driver              = PostgreSQL Unicode
Trace               = No
TraceFile           = /tmp/psqlodbc.log
Database            = $fs_database
Servername          = 127.0.0.1
UserName            = $fs_user
Password            = $fs_password
Port                = 5432
ReadOnly            = No
RowVersioning       = No
ShowSystemTables    = No
ShowOidColumn       = No
FakeOidIndex        = No

[fs_cdr]
Description         = PostgreSQL
Driver              = PostgreSQL Unicode
Trace               = No
TraceFile           = /tmp/psqlodbc.log
Database            = $fs_cdr_database
Servername          = 127.0.0.1
UserName            = $fs_cdr_user
Password            = $fs_cdr_password
Port                = 5432
ReadOnly            = No
RowVersioning       = No
ShowSystemTables    = No
ShowOidColumn       = No
FakeOidIndex        = No
EOF

# Create Freeswitch certificate for TLS handling
echo -e "************************************************************"
echo -e "*      Create Freeswitch certificate for TLS handling      *"
echo -e "************************************************************"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/freeswitch/tls/wss.pem \
    -out /etc/freeswitch/tls/wss.pem \
    -subj "/C=US/ST=FL/L=Miami/O=Ring2All/OU=Unit/CN=$LOCAL_IP"

# Security risk, prevents unauthorized access.
echo -e "************************************************************"
echo -e "*       Security risk, prevents unauthorized access,       *"
echo -e "*  avoids call restrictions, protects system integrity.    *"
echo -e "************************************************************"
# Path to configuration file
switch_conf="/etc/freeswitch/vars.xml"
# Check if file exists before modifying it
if [ -f "$switch_conf" ]; then
  # Change the default password that Freeswitch comes with to register devices
  sed -i "s/\(<X-PRE-PROCESS cmd=\"set\" data=\"default_password=\)[^\"]*\"/\1$fs_default_password\"/" "$switch_conf"
  echo "✅ The key was changed in the file $switch_conf."
else
  echo "❌ The $switch_conf file does not exist."
fi

# DNS cashing
echo -e "************************************************************"
echo -e "*     Debian lacks DNS caching; Unbound provides           *"
echo -e "*         a lightweight and secure solution.               *"
echo -e "************************************************************"
apt -y install unbound
systemctl start unbound
systemctl enable unbound

# Proper entropy source
echo -e "************************************************************"
echo -e "*     Debian may lack entropy; Haveged generates           *"
echo -e "*      randomness without standard dependencies.           *"
echo -e "************************************************************"
apt -y install haveged
systemctl start haveged
systemctl enable haveged

# Automatic time synchronization
echo -e "************************************************************"
echo -e "*       Chrony is a fast, secure, and easy-to-use          *"
echo -e "*             time synchronization daemon.                 *"
echo -e "************************************************************"
apt -y install chrony
systemctl start chrony
systemctl enable chrony

# Restart Freeswitch Service
echo -e "************************************************************"
echo -e "*                 Restart Freeswitch Service               *"
echo -e "************************************************************"
systemctl restart freeswitch

echo -e "************************************************************"
echo -e "*                 Installation Completed!                  *"
echo -e "************************************************************"
