#!/bin/bash

# Install FreeRadius to work with OpenLDAP
source variables.sh

# Update software packages
sudo yum -y update

# Install FreeRadius and dependencies.
sudo yum -y install \
      wget \
      freeradius \
      freeradius-ldap \
      freeradius-utils

# Download Radius schema for OpenLDAP and copy it to LDAP config folder.
sudo wget http://open.rhx.it/phamm/schema/radius.schema -o /etc/openldap/schema/radius.schema

# Create slapd config file and include radius schema.
SLAPD_FILE=/etc/openldap/slapd.conf
echo "include /etc/openldap/schema/radius.schema" | sudo tee -a $SLAPD_FILE
sudo chown ldap:ldap $SLAPD_FILE

# Copy default and inner-tunnel config.
sudo cp ./config/RadiusDefaultConfig /etc/raddb/sites-available/default
sudo cp ./config/RadiusInTunnelConfig /etc/raddb/sites-available/inner-tunnel
sudo chgrp radiusd /etc/raddb/sites-available/inner-tunnel
sudo chgrp radiusd /etc/raddb/sites-available/default

# Configure Radius to use LDAP module.
sudo cp ./config/RadiusLDAPConfig /etc/raddb/mods-available/ldap
sudo ln -s /etc/raddb/mods-available/ldap /etc/raddb/mods-enabled/ldap

subst_ldap () {
  sudo sed -i -e "s/${1}/${2}/g" /etc/raddb/mods-available/ldap
}

subst_ldap "@LDAP_HOST@" "${LDAP_HOST}"
subst_ldap "@LDAP_PORT@" "${LDAP_PORT}"
subst_ldap "@LDAP_USER@" "${LDAP_USER}"
subst_ldap "@LDAP_PASS@" "${LDAP_PASS}"
subst_ldap "@LDAP_BASE@" "${LDAP_BASE}"
subst_ldap "@LDAP_USER_BASEDN@" "${LDAP_USER_BASEDN}"
subst_ldap "@LDAP_GROUP_BASEDN@" "${LDAP_GROUP_BASEDN}"

# Configure Radius clients.
sudo cp ./config/RadiusClientConfig /etc/raddb/clients.conf

subst_client () {
  sudo sed -i -e "s/${1}/${2}/g" /etc/raddb/clients.conf
}

subst_client "@VPN_CLIENT_IP@" "${VPN_CLIENT_IP}"
subst_client "@VPN_CLIENT_SECRET@" "${VPN_CLIENT_SECRET}"
subst_client "@VPN_CLIENT_SHNAME@" "${VPN_CLIENT_SHNAME}"

# NOTE: LDAP service need to running first or else Radius will not start.
# Start and enable FreeRadius
sudo systemctl start radiusd
sudo systemctl enable radiusd