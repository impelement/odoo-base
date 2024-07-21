#!/bin/bash

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"

OE_PORT="8069"
OE_SUPERADMIN="admin"
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
OE_SERVICE="${OE_USER}.service"
DOMAIN_NAME="odoo"
WEBSITE_NAME="odoo"
LONGPOLLING_PORT="8072"
ADMIN_EMAIL="admin@impelement.com"
OE_VERSION="17.0"
DEFAULT_DB="odoo"

DEFAULT_MODULE="sale_management,account,crm,stock,contacts,calendar,purchase,om_account_accountant"
UI_MODULE="muk_web_theme,web_theme_classic,os_pwa_backend,web_responsive,web_window_title,web_remember_tree_column_width,web_favicon,web_tree_many2one_clickable"
PLUGIN_MODULE="base_user_role"


#<UDF name="domain" label="Domain name for the instance" default="">
#<UDF name="github_user" label="GITHUB account name" default="">
#<UDF name="github_token" label="Github token" default="">
#<UDF name="enable_logistics" label="Download and setup logictics modules" default="False">
DOMAIN="odoo.impelement.com"
GITHUB_USER="ajamini"
GITHUB_TOKEN="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"
ENABLE_LOGICTICS="True"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
# universe package is for Ubuntu 18.x
sudo add-apt-repository universe -y
# libpng12-0 dependency for wkhtmltopdf for older Ubuntu versions
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install libpq-dev -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
echo -e "\n---- Installing the default postgreSQL version based on Linux version ----"
sudo apt-get install postgresql postgresql-server-dev-all -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing Python 3 + pip3 --"
sudo apt-get install python3 python3-pip -y
sudo apt-get install git python3-cffi build-essential python3-virtualenv wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y

echo -e "\n---- Installing nodeJS NPM and rtlcss for LTR support ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
sudo apt install xfonts-75dpi wkhtmltopdf -y

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

echo -e "\n==== Installing ODOO Server ===="
sudo git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/impelement/odoo-base.git $OE_HOME_EXT/

echo -e "\n---- Creating virtual env ----"
sudo -H virtualenv $OE_HOME_EXT/venv

echo -e "\n---- Install python packages/requirements ----"
sudo $OE_HOME_EXT/venv/bin/python3 -m pip install -r $OE_HOME_EXT/requirements.txt

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir -p $OE_HOME/custom"

CUSTOM_ADDONS=""
if [ $ENABLE_LOGICTICS = "True" ]; then
  sudo git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/impelement/odoo-logictics.git $OE_HOME/custom/logistics
  CUSTOM_ADDONS = ",$OE_HOME/custom/logistic}"
fi


echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Create server config file"
sudo touch /etc/${OE_CONFIG}.conf

echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' > /etc/${OE_CONFIG}.conf"

echo -e "* Generating random admin password"
OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)

sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME_EXT}/custom${CUSTOM_ADDONS}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'list_db = False\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf '#dbfilter = ^%d$\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'db_name = ${DEFAULT_DB}\n' >> /etc/${OE_CONFIG}.conf"

sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf


#--------------------------------------------------
# Install database
#--------------------------------------------------
echo -e "* Creating default database"
sudo -u $OE_USER createdb $DEFAULT_DB
sudo -u $OE_USER ${OE_HOME_EXT}/venv/bin/python3 $OE_HOME_EXT/odoo-bin -d ${DEFAULT_DB} -i ${DEFAULT_MODULE},${UI_MODULE},${PLUGIN_MODULE} --stop-after-init --without-demo=True


#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------
echo -e "* Create init file"
cat <<EOF > ~/$OE_SERVICE
[Unit]
Description=Odoo Service
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=${OE_SERVICE}
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=${OE_HOME_EXT}/venv/bin/python3 ${OE_HOME_EXT}/odoo-bin -c /etc/${OE_CONFIG}.conf
StandardOutput=journal+console
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Security Service File"
sudo mv ~/$OE_SERVICE /etc/systemd/system/$OE_SERVICE
sudo chmod 755 /etc/systemd/system/$OE_SERVICE
sudo chown root: /etc/systemd/system/$OE_SERVICE

echo -e "* Reload Daemon"
sudo systemctl daemon-reload

echo -e "* Starting Service"
sudo systemctl enable --now $OE_SERVICE


#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
echo -e "\n---- Installing and setting up Nginx ----"
sudo apt install nginx -y
cat <<EOF > ~/odoo
server {
  listen 80;

  # set proper server name after domain set
  server_name $DOMAIN_NAME;

    location / {
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Host $DOMAIN;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_pass http://127.0.0.1:$OE_PORT;
        proxy_redirect http://127.0.0.1:$OE_PORT/ http://$DOMAIN/;

        # If the Odoo application generates URLs, this helps rewrite them correctly
        sub_filter 'http://127.0.0.1:$OE_PORT' 'http://$DOMAIN';
        sub_filter_once off;  # Apply all the filters to each part of the response
    }
}
EOF

sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx reload
sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$WEBSITE_NAME"