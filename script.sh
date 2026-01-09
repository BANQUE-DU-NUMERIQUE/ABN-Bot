#!/bin/bash

. main.conf

# Vérification de dialog
if ! command -v dialog >/dev/null 2>&1; then
    echo "dialog n'est pas installé : sudo apt install dialog"
    exit 1
fi

# Saisie du numéro d'inventaire
ninventaire=$(dialog --stdout --inputbox "Numéro d'inventaire ?" 10 50)
if [ $? -ne 0 ] || [ -z "$ninventaire" ]; then
    dialog --msgbox "Inventaire annulé." 6 40
    clear
    exit 1
fi

dialog --msgbox "Le nom de machine GLPI sera : $ninventaire" 7 50

# Préparation de l'agent GLPI
(
echo 10 ; sleep 0.2
cp inventory.dumb inventory.json
echo 40 ; sleep 0.2
sed -i "s/dumbname/${ninventaire}/g" inventory.json
echo 100 ; sleep 0.2
) | dialog --gauge "Préparation de l'inventaire GLPI..." 10 60 0

# Mise à jour APT
(
echo 20 ; sleep 0.2
sudo apt update >/dev/null 2>&1
echo 100 ; sleep 0.2
) | dialog --gauge "Mise à jour des dépôts APT..." 10 60 0

# Nettoyage logs
(
echo 30 ; sleep 0.2
rm -f $logpath/*.log
echo 100 ; sleep 0.2
) | dialog --gauge "Nettoyage des fichiers log..." 10 60 0

# Exécution de l'agent GLPI
(
echo 10 ; sleep 0.2
glpi-agent --server "$glpiserver" \
           --additional-content="inventory.json" \
           --logfile="$logpath/glpi.log"
echo 100 ; sleep 0.2
) | dialog --gauge "Exécution de l'agent GLPI..." 10 60 0

rm inventory.json

# Préparation du stockage SFTP
(
echo 10 ; sleep 0.2
echo "Préparation du stockage SFTP..."
echo 30 ; sleep 0.2
# Utilisation de SFTP pour transférer les logs vers le serveur distant
echo "put $logpath/*" | sftp -oBatchMode=no -b - "$sftpuser@$sftphost:$sftpdirectory/$ninventaire" 2>/dev/null
echo 100 ; sleep 0.2
) | dialog --gauge "Transfert des logs vers le serveur SFTP..." 10 60 0

# Effacement (Nwipe)
(
for i in $(seq 1 100); do
    echo $i
    sleep 1
done
) | dialog --gauge "Effacement des données (nwipe)...\nCela peut prendre plusieurs minutes." 10 60 0

# pour que je détruit pas ma machine virtuelle
# nwipe --method="$nwipemethod" --nousb --autonuke --nowait --logfile="$logpath/nwipe.log"

# Test RAM
ramfree=$(free -m | grep Mem | awk '{print $4}')
ramtest=$(($ramfree - 100))

(
echo 10
memtester $ramtest 1 >"$logpath/memtest.log"
echo 100
) | dialog --gauge "Test RAM en cours..." 10 60 0

# Test SMART
(
for i in $(seq 1 100); do
  echo $i
  sleep 0.5
done
) | dialog --gauge "Test SMART (long)...\nPatientez..." 10 60 0

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
) | dialog --gauge "Nettoyage des logs inutiles..." 10 60 0

# Copie vers SFTP
(
echo 30 ; sleep 0.2
echo "Transfert des logs vers SFTP..."
echo "put $logpath/* /mnt/nfs/logs/$ninventaire/" | sftp -oBatchMode=no -b - "$sftpuser@$sftphost:$sftpdirectory"
echo 100 ; sleep 0.2
) | dialog --gauge "Transfert des logs vers le serveur SFTP..." 10 60 0

# Fin
dialog --msgbox "Tous les tests sont terminés.\nLa machine va maintenant s'éteindre." 8 50
clear
systemctl poweroff
