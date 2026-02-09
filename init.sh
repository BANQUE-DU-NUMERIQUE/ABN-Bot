#!/bin/bash

# Téléchargement install.sh et conf

(
echo 10 ; sleep 0.3
wget -q "$downloadsource/install.sh"
echo 50 ; sleep 0.3
mv main.conf main.conf.bak 2>/dev/null
echo 70 ; sleep 0.2
wget -q "$downloadsource/main.conf"
echo 100 ; sleep 0.3
) | dialog --gauge "Téléchargement des fichiers…" 10 60 0


# Mise à jour de main.conf

(
echo 30 ; sleep 0.3
sed -i "s|pathtoinstallfolder|$downloadsource|g" main.conf
echo 60 ; sleep 0.3
sed -i "s|userforhttpauth|$httpuser|g" main.conf
echo 90 ; sleep 0.3
sed -i "s|passwordforhttpauth|$httppassword|g" main.conf
echo 100 ; sleep 0.2
) | dialog --gauge "Mise à jour de la configuration…" 10 60 0


# Lancement de l'installation


(
echo 20 ; sleep 0.5
bash install.sh >/dev/null 2>&1
echo 100 ; sleep 0.3
) | dialog --gauge "Installation en cours…" 10 60 0


# Nettoyage final

(
echo 50 ; sleep 0.3
rm -f install.sh
echo 100 ; sleep 0.3
) | dialog --gauge "Nettoyage…" 10 60 0

# FIN
dialog --msgbox "Installation terminée avec succès." 7 50
clear
