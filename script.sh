#!/bin/bash

#
# Script d’inventaire & diagnostics
#

# Chargement paramètres
. main.conf

# Dimensions standard dialog
H=10
W=60
BACKTITLE="La Banque du Numerique - GLPI - "

clear

# Saisie Inventaire

ninventaire=$(dialog \
    --backtitle "$BACKTITLE" \
    --title "Saisie du numéro d'inventaire" \
    --inputbox "Veuillez entrer le numéro d'inventaire :" $H $W \
    3>&1 1>&2 2>&3)

# Si annulation

if [ -z "$ninventaire" ]; then
    dialog --backtitle "$BACKTITLE" --title "Annulation" \
           --msgbox "Aucun numéro d'inventaire fourni.\nArrêt du script." $H $W
    clear
    exit 1
fi

dialog --clear --backtitle "$BACKTITLE" --title "Inventaire confirmé" \
       --msgbox "Le nom de la machine dans GLPI sera :\n\n$ninventaire" $H $W

# Préparation GLPI

dialog --infobox "Préparation du fichier d’inventaire..." 5 50
cp inventory.dumb inventory.json
sed -i "s/dumbname/${ninventaire}/g" inventory.json
sleep 1

# Mise à jour dépôts
dialog --infobox "Mise à jour des dépôts APT..." 5 50
sudo apt update >/dev/null 2>&1

# Nettoyage logs
rm -f $logpath/*.log

# Inventaire GLPI

dialog --infobox "Exécution de l'agent GLPI..." 5 50
glpi-agent --server "$glpiserver" \
           --additional-content="inventory.json" \
           --logfile="$logpath/glpi.log"

rm -f inventory.json
sleep 1


# Effacement sécurisé Nwipe

if dialog --backtitle "$BACKTITLE" --title "Effacement des données" \
          --yesno "Souhaitez-vous lancer un effacement sécurisé (Nwipe) ?" $H $W; then

    dialog --infobox "Montage du stockage NFS..." 5 50
    mkdir -p /mnt/nfs/logs
    mount -t nfs "$nfspath" /mnt/nfs/logs

    mkdir -p "/mnt/nfs/logs/$ninventaire"

    dialog --infobox "Lancement de Nwipe (méthode : $nwipemethod)..." 5 50
    nwipe --method="$nwipemethod" --nousb --autonuke --nowait \
          --logfile="$logpath/nwipe.log"
else
    dialog --msgbox "Effacement sécurisé ignoré." $H $W
fi



# Test RAM

dialog --infobox "Lancement du test mémoire (memtester)..." 5 50
ramfree=$(free -m | awk '/Mem/ {print $4}')
ramtest=$(($ramfree - 100))
memtester $ramtest 1 > "$logpath/memtest.log"



# Test SMART long

dialog --infobox "Lancement du test SMART (long)..." 5 50
bash smart.sh long

dialog --infobox "Analyse des résultats SMART..." 5 50
grep "#1" $logpath/smart-long*.log >/dev/null 2>&1

# Copie des logs vers stockage NFS

#dialog --infobox "Copie des fichiers log vers le stockage NFS..." 5 50
#rm -f $logpath/*-part*.log
#rm -f $logpath/*DVD*.log
#rm -f $logpath/*CD-ROM*.log

#cp -f $logpath/* "/mnt/nfs/logs/$ninventaire/"

# Transfert FTP serveur online

if dialog --backtitle "$BACKTITLE" --title "FTP" \
          --yesno "Transférer également les logs par FTP ?" $H $W; then

    dialog --infobox "Compression des logs..." 5 50
    tar -czf "log-$ninventaire.tar.gz" $logpath/*

    dialog --infobox "Transfert FTP en cours..." 5 50
    curl -T "log-$ninventaire.tar.gz" \
         "ftp://$ftpuser:$ftppassword@$ftphost/$ftpdirectory/"

    rm -f "log-$ninventaire.tar.gz"
else
    dialog --msgbox "Transfert FTP ignoré." $H $W
fi

dialog --backtitle "$BACKTITLE" --title "Terminé" \
       --msgbox "Toutes les opérations sont terminées.\n\nLa machine va s'éteindre." $H $W

clear
systemctl poweroff
