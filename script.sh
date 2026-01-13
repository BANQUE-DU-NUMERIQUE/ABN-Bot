#!/bin/bash
set -e

. main.conf

# Vérifie que whiptail est installé
if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail n'est pas installé : sudo apt install whiptail"
    exit 1
fi

# Vérifie lftp (FTPS)
if ! command -v lftp >/dev/null 2>&1; then
    whiptail --msgbox "lftp n'est pas installé : sudo apt install lftp" 8 50
    exit 1
fi

# Inventaire

ninventaire=$(whiptail --inputbox "Numéro d'inventaire ?" 10 50 --stdout) || exit 1

whiptail --msgbox "Le nom de machine GLPI sera : $ninventaire" 7 50

# Préparation GLPI

(
echo 20
cp inventory.dumb inventory.json
echo 60
sed -i "s/dumbname/${ninventaire}/g" inventory.json
echo 100
) | whiptail --gauge "Préparation de l'inventaire GLPI..." 10 60 0

# APT

(
echo 30
apt update >/dev/null 2>&1
echo 100
) | whiptail --gauge "Mise à jour des dépôts APT..." 10 60 0

# Logs

(
echo 50
rm -f "$logpath"/*.log
echo 100
) | whiptail --gauge "Nettoyage des fichiers log..." 10 60 0

# Agent GLPI

(
echo 20
glpi-agent --server "$glpiserver" \
           --additional-content="inventory.json" \
           --logfile="$logpath/glpi.log"
echo 100
) | whiptail --gauge "Exécution de l'agent GLPI..." 10 60 0

rm -f inventory.json

# Effacement

(
for i in $(seq 1 100); do
    echo $i
    sleep 0.2
done
) | whiptail --gauge "Effacement des données (nwipe)..." 10 60 0

# nwipe
nwipe --method="$nwipemethod" --nousb --autonuke --nowait --logfile="$logpath/nwipe.log"

# Test RAM
ramfree=$(free -m | awk '/Mem:/ {print $4}')
ramtest=$((ramfree - 100))

(
echo 10
memtester "$ramtest" 1 >"$logpath/memtest.log"
echo 100
) | whiptail --gauge "Test RAM en cours..." 10 60 0

# SMART

(
for i in $(seq 1 100); do
    echo $i
    sleep 0.3
done
) | whiptail --gauge "Test SMART (long)..." 10 60 0

bash smart.sh long
grep "#1" "$logpath"/smart-long*.log > "$logpath/smart-result.log"

# Nettoyage logs

(
echo 25
rm -f "$logpath"/*-part*.log
echo 50
rm -f "$logpath"/*DVD*.log
echo 75
rm -f "$logpath"/*CD-ROM*.log
echo 100
) | whiptail --gauge "Nettoyage des logs inutiles..." 10 60 0

# Déchiffrement FTPS

(
echo 50
ftpspassword=$(gpg --decrypt --quiet --batch --passphrase "" ftpspassword.gpg 2>/dev/null)
echo 100
) | whiptail --gauge "Déchiffrement des identifiants FTPS..." 10 60 0

if [ -z "$ftpspassword" ]; then
    whiptail --msgbox "Erreur : impossible de déchiffrer le mot de passe FTPS." 8 50
    exit 1
fi

# Transfert FTPS

(
echo 20

lftp -u "$ftpsuser","$ftpspassword" "ftps://$ftpshost" << EOF
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ssl:verify-certificate no
mkdir -p $ftpsdirectory/$ninventaire
cd $ftpsdirectory/$ninventaire
lcd $logpath
mput *.log
bye
EOF

echo 100
) | whiptail --gauge \
"Transfert des logs vers le serveur FTPS...\n$ftpshost:$ftpsdirectory/$ninventaire" \
11 70 0

whiptail --msgbox \
"Transfert FTPS terminé avec succès.\n\nTous les tests sont finis.\nLa machine va s'éteindre." \
10 60

clear
systemctl poweroff
