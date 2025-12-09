#!/bin/bash

# Vérifie que dialog est installé
if ! command -v dialog >/dev/null 2>&1; then
    echo "dialog n'est pas installé : sudo apt install dialog"
    exit 1
fi


# Saisie des informations

downloadsource=$(dialog --stdout --inputbox "Adresse de téléchargement du script :" 10 60)
if [ $? -ne 0 ] || [ -z "$downloadsource" ]; then clear; exit 1; fi

httpuser=$(dialog --stdout --inputbox "Utilisateur pour Auth Apache :" 10 60)
if [ $? -ne 0 ] || [ -z "$httpuser" ]; then clear; exit 1; fi

httppassword=$(dialog --stdout --passwordbox "Mot de passe Auth Apache :" 10 60)
if [ $? -ne 0 ] || [ -z "$httppassword" ]; then clear; exit 1; fi



#  Chiffrement du mot de passe

(
echo 20 ; sleep 0.3
echo -n "$httppassword" | gpg --symmetric --cipher-algo AES256 -o httppassword.gpg
echo 100 ; sleep 0.2
) | dialog --gauge "Chiffrement du mot de passe (AES256)..." 10 60 0


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
