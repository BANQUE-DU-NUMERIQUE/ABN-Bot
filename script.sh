#!/bin/bash
# Script d’inventaire & diagnostics

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

# Transfert API
if dialog --backtitle "$BACKTITLE" --title "API Upload" \
  --yesno "Transférer les logs via l’API ? (HTTP ${api_method:-POST})" $H $W; then

  # Préparer les données
  dialog --infobox "Préparation des fichiers..." 5 50
  # regrouper en une archive (comme le FTP)
  archive_name="log-${ninventaire}.tar.gz"
  tar -czf "$archive_name" $logpath/*

  # Récupérer le token Bearer depuis le fichier GPG
  #    -> Le passphrase GPG sera demandé par gpg si nécessaire
  api_token=$(gpg --quiet --batch --decrypt "$api_token_file" 2>/dev/null)
  if [ -z "$api_token" ]; then
    dialog --msgbox "Impossible de déchiffrer le token API (fichier: $api_token_file)." $H $W
    rm -f "$archive_name"
    clear; exit 1
  fi

  # Déterminer le champ multipart
  idx="${glpi_file_field_index:-0}"
  field_name="filename[${idx}]"

  # Envoi via API
  dialog --infobox "Transfert API en cours (archive)..." 5 50
  if ! curl -sS -X "${api_method:-POST}" \
      "${CURL_HEADERS[@]}" \
      -F "${field_name}=@${archive_name};type=application/gzip;filename=${archive_name}" \
      -F "inventory=${ninventaire}" \
      "$api_url" ; then
    dialog --msgbox "Échec de l’upload API." $H $W
  else
    dialog --msgbox "Upload API réussi (archive)." $H $W
  fi

  # Nettoyage de l’archive
  rm -f "$archive_name"

else
  dialog --msgbox "Transfert API ignoré." $H $W
fi

# FIN
dialog --backtitle "$BACKTITLE" --title "Terminé" \
       --msgbox "Toutes les opérations sont terminées.\n\nLa machine va s'éteindre." $H $W

clear
systemctl poweroff
