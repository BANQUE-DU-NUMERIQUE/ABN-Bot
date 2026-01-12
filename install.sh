#!/bin/bash
# Ce script permet d'installer tous les paquets nécessaires pour l'inventaire

# Appel du fichier de configuration
. main.conf

# Une mise à jour des dépôts ne fait jamais de mal
apt update
apt upgrade

# Installation de SNAP (obligatoire pour glpi-agent)
apt install -y -f snap

# Installation de l'interface whiptail
apt install -y whiptail

# Installation des outils SFTP
apt install -y sshpass openssh-client

# Création du répertoire log
mkdir -p $logpath

# Installation de l'agent glpi inventory
rm -f glpi-agent-*-with-snap-linux-installer.pl
wget $glpiagentinstallurl
perl glpi-agent-*-with-snap-linux-installer.pl
rm -f glpi-agent-*-with-snap-linux-installer.pl

# Déchiffrement du mot de passe HTTP
httppassword=$(gpg --decrypt --quiet httppassword.gpg)

# On rajoute les identifiants dans le fichier de configuration glpi-agent
sed -i "s|user =|user = $httpuser|g" /etc/glpi-agent/agent.cfg
sed -i "s|password =|password = $httppassword|g" /etc/glpi-agent/agent.cfg

# Installation de NWipe, logiciel d'effacement de disques
apt install -y -f nwipe

# Installation de memtester, logiciel de test de la mémoire RAM
apt install -y -f memtester

# Installation de smartmontools pour les tests SMART
apt install -y -f smartmontools

# Nettoyage et installation du script principal et du script de test des disques durs
rm -f script.sh
rm -f smart.sh
wget $downloadsource/script.sh
wget $downloadsource/smart.sh
wget $downloadsource/inventory.dumb

# Rendre les scripts exécutables
chmod +x script.sh
chmod +x smart.sh

echo "Installation terminée avec succès."