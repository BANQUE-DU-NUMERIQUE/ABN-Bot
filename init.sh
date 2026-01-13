#!/bin/bash

set -e

# Vérifie que whiptail est installé
if ! command -v whiptail >/dev/null 2>&1; then
    echo "voulez lancez install.sh"
    exit 1
fi

# Saisie des informations

downloadsource=$(whiptail --title "Téléchargement" \
--inputbox "Adresse de téléchargement du script :" 10 60 --stdout) || exit 1

httpuser=$(whiptail --title "Apache" \
--inputbox "Utilisateur pour Auth Apache :" 10 60 --stdout) || exit 1

httppassword=$(whiptail --title "Apache" \
--passwordbox "Mot de passe Auth Apache :" 10 60 --stdout) || exit 1

ftpshost=$(whiptail --title "FTPS" \
--inputbox "Hôte FTPS :" 10 60 --stdout) || exit 1

ftpsuser=$(whiptail --title "FTPS" \
--inputbox "Utilisateur FTPS :" 10 60 --stdout) || exit 1

ftpspassword=$(whiptail --title "FTPS" \
--passwordbox "Mot de passe FTPS :" 10 60 --stdout) || exit 1

ftpsdirectory=$(whiptail --title "FTPS" \
--inputbox "Répertoire distant FTPS :" 10 60 --stdout) || exit 1

# Chiffrement des mots de passe

(
echo 20
echo -n "$httppassword" | gpg --symmetric --cipher-algo AES256 \
--batch --yes --passphrase "" -o httppassword.gpg
echo 100
) | whiptail --gauge "Chiffrement du mot de passe HTTP…" 8 60 0

(
echo 20
echo -n "$ftpspassword" | gpg --symmetric --cipher-algo AES256 \
--batch --yes --passphrase "" -o ftpspassword.gpg
echo 100
) | whiptail --gauge "Chiffrement du mot de passe FTPS…" 8 60 0

# Téléchargement des fichiers

(
echo 10
wget -q "$downloadsource/install.sh"
echo 50
mv -f main.conf main.conf.bak 2>/dev/null || true
echo 70
wget -q "$downloadsource/main.conf"
echo 100
) | whiptail --gauge "Téléchargement des fichiers…" 8 60 0

# Mise à jour de la configuration

(
echo 20
sed -i "s|pathtoinstallfolder|$downloadsource|g" main.conf
echo 40
sed -i "s|userforhttpauth|$httpuser|g" main.conf
echo 60
sed -i "s|ftpshostplaceholder|$ftpshost|g" main.conf
echo 80
sed -i "s|ftpsuserplaceholder|$ftpsuser|g" main.conf
echo 100
sed -i "s|ftpsdirectoryplaceholder|$ftpsdirectory|g" main.conf
) | whiptail --gauge "Mise à jour de la configuration…" 8 60 0

# Installation

(
echo 30
bash install.sh
echo 100
) | whiptail --gauge "Installation en cours…" 8 60 0

# Nettoyage

rm -f install.sh

whiptail --msgbox \
"Installation terminée avec succès 🎉

Les mots de passe ont été chiffrés.
Vous pouvez maintenant lancer script.sh" 12 50

clear
