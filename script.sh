#!/bin/bash
. main.conf

# Vérifie que whiptail est installé
if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail n'est pas installé : sudo apt install whiptail"
    exit 1
fi

# Saisie du numéro d'inventaire
ninventaire=$(whiptail --inputbox "Numéro d'inventaire ?" 10 50 --stdout)
if [ $? -ne 0 ] || [ -z "$ninventaire" ]; then
    whiptail --msgbox "Inventaire annulé." 6 40
    clear
    exit 1
fi

whiptail --msgbox "Le nom de machine GLPI sera : $ninventaire" 7 50

# Préparation de l'agent GLPI
(
echo 10 ; sleep 0.2
cp inventory.dumb inventory.json
echo 40 ; sleep 0.2
sed -i "s/dumbname/${ninventaire}/g" inventory.json
echo 100 ; sleep 0.2
) | whiptail --gauge "Préparation de l'inventaire GLPI..." 10 60 0

# Mise à jour APT
(
echo 20 ; sleep 0.2
sudo apt update >/dev/null 2>&1
echo 100 ; sleep 0.2
) | whiptail --gauge "Mise à jour des dépôts APT..." 10 60 0

# Nettoyage logs
(
echo 30 ; sleep 0.2
rm -f $logpath/*.log
echo 100 ; sleep 0.2
) | whiptail --gauge "Nettoyage des fichiers log..." 10 60 0

# Exécution de l'agent GLPI
(
echo 10 ; sleep 0.2
glpi-agent --server "$glpiserver" \
           --additional-content="inventory.json" \
           --logfile="$logpath/glpi.log"
echo 100 ; sleep 0.2
) | whiptail --gauge "Exécution de l'agent GLPI..." 10 60 0

rm inventory.json

# Effacement (Nwipe)
(
for i in $(seq 1 100); do
    echo $i
    sleep 1
done
) | whiptail --gauge "Effacement des données (nwipe)...\nCela peut prendre plusieurs minutes." 10 60 0

# pour que je ne détruise pas ma machine virtuelle
# nwipe --method="$nwipemethod" --nousb --autonuke --nowait --logfile="$logpath/nwipe.log"

# Test RAM
ramfree=$(free -m | grep Mem | awk '{print $4}')
ramtest=$(($ramfree - 100))

(
echo 10
memtester $ramtest 1 >"$logpath/memtest.log"
echo 100
) | whiptail --gauge "Test RAM en cours..." 10 60 0

# Test SMART
(
for i in $(seq 1 100); do
  echo $i
  sleep 0.5
done
) | whiptail --gauge "Test SMART (long)...\nPatientez..." 10 60 0

bash smart.sh long
grep "#1" "$logpath"/smart-long*.log > "$logpath/smart-result.log"

# Nettoyage
(
echo 25 ; sleep 0.2
rm -f $logpath/*-part*.log
echo 50 ; sleep 0.2
rm -f $logpath/*DVD*.log
echo 75 ; sleep 0.2
rm -f $logpath/*CD-ROM*.log
echo 100 ; sleep 0.2
) | whiptail --gauge "Nettoyage des logs inutiles..." 10 60 0

# Déchiffrement du mot de passe SFTP
(
echo 50 ; sleep 0.2
sftppassword=$(gpg --decrypt --quiet --batch --passphrase "" sftppassword.gpg 2>/dev/null)
echo 100 ; sleep 0.2
) | whiptail --gauge "Déchiffrement des identifiants SFTP..." 10 60 0

# Vérification du déchiffrement
if [ -z "$sftppassword" ]; then
    whiptail --msgbox "Erreur : Impossible de déchiffrer le mot de passe SFTP." 8 50
    clear
    exit 1
fi

# Transfert des logs via SFTP
(
echo 10 ; sleep 0.3

# Création du fichier batch SFTP
cat > /tmp/sftp_batch_$$.txt << EOF
mkdir $sftpdirectory/$ninventaire
cd $sftpdirectory/$ninventaire
lcd $logpath
mput *.log
bye
EOF

echo 50 ; sleep 0.2

# Transfert via SFTP
sshpass -p "$sftppassword" sftp -oBatchMode=no -oStrictHostKeyChecking=no -b /tmp/sftp_batch_$$.txt "$sftpuser@$sftphost" 2>/dev/null

echo 100 ; sleep 0.3
) | whiptail --gauge "Transfert des logs vers le serveur SFTP...\n$sftphost:$sftpdirectory/$ninventaire" 11 70 0

# Vérification du transfert
if [ $? -eq 0 ]; then
    whiptail --msgbox "Transfert SFTP réussi vers :\n$sftphost:$sftpdirectory/$ninventaire" 8 60
else
    whiptail --msgbox "Attention : Erreur lors du transfert SFTP.\nVérifiez les identifiants et la connexion réseau." 9 60
fi

# Nettoyage du fichier batch
rm -f /tmp/sftp_batch_$$.txt

# Fin
whiptail --msgbox "Tous les tests sont terminés.\nLa machine va maintenant s'éteindre." 8 50
clear
systemctl poweroff