#!/bin/bash

# Vérifie que whiptail est installé
if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail n'est pas installé : sudo apt install whiptail"
    exit 1
fi

# Saisie des informations
downloadsource=$(whiptail --inputbox "Adresse de téléchargement du script :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$downloadsource" ]; then clear; exit 1; fi

httpuser=$(whiptail --inputbox "Utilisateur pour Auth Apache :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$httpuser" ]; then clear; exit 1; fi

httppassword=$(whiptail --passwordbox "Mot de passe Auth Apache :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$httppassword" ]; then clear; exit 1; fi

sftphost=$(whiptail --inputbox "Hôte SFTP :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$sftphost" ]; then clear; exit 1; fi

sftpuser=$(whiptail --inputbox "Utilisateur SFTP :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$sftpuser" ]; then clear; exit 1; fi

sftppassword=$(whiptail --passwordbox "Mot de passe SFTP :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$sftppassword" ]; then clear; exit 1; fi

sftpdirectory=$(whiptail --inputbox "Répertoire distant SFTP :" 10 60 --stdout)
if [ $? -ne 0 ] || [ -z "$sftpdirectory" ]; then clear; exit 1; fi

# Chiffrement du mot de passe HTTP
(
echo 20 ; sleep 0.3
echo -n "$httppassword" | gpg --symmetric --cipher-algo AES256 --batch --passphrase "" -o httppassword.gpg 2>/dev/null
echo 100 ; sleep 0.2
) | whiptail --gauge "Chiffrement du mot de passe HTTP (AES256)..." 10 60 0

# Chiffrement du mot de passe SFTP
(
echo 20 ; sleep 0.3
echo -n "$sftppassword" | gpg --symmetric --cipher-algo AES256 --batch --passphrase "" -o sftppassword.gpg 2>/dev/null
echo 100 ; sleep 0.2
) | whiptail --gauge "Chiffrement du mot de passe SFTP (AES256)..." 10 60 0

# Téléchargement install.sh et conf
(
echo 10 ; sleep 0.3
wget -q "$downloadsource/install.sh" || { echo "Erreur téléchargement install.sh" >&2; exit 1; }
echo 50 ; sleep 0.3
mv main.conf main.conf.bak 2>/dev/null
echo 70 ; sleep 0.2
wget -q "$downloadsource/main.conf" || { echo "Erreur téléchargement main.conf" >&2; exit 1; }
echo 100 ; sleep 0.3
) | whiptail --gauge "Téléchargement des fichiers…" 10 60 0

# Mise à jour de main.conf
(
echo 20 ; sleep 0.3
sed -i "s|pathtoinstallfolder|$downloadsource|g" main.conf
echo 40 ; sleep 0.3
sed -i "s|userforhttpauth|$httpuser|g" main.conf
echo 60 ; sleep 0.3
sed -i "s|sftphostplaceholder|$sftphost|g" main.conf
echo 80 ; sleep 0.3
sed -i "s|sftpuserplaceholder|$sftpuser|g" main.conf
echo 90 ; sleep 0.3
sed -i "s|sftpdirectoryplaceholder|$sftpdirectory|g" main.conf
echo 100 ; sleep 0.2
) | whiptail --gauge "Mise à jour de la configuration…" 10 60 0

# Lancement de l'installation
(
echo 20 ; sleep 0.5
bash install.sh
echo 100 ; sleep 0.3
) | whiptail --gauge "Installation en cours…" 10 60 0

# Vérification de l'installation
if [ $? -ne 0 ]; then
    whiptail --msgbox "Erreur lors de l'installation.\nConsultez les logs pour plus de détails." 8 50
    clear
    exit 1
fi

# Nettoyage final
(
echo 50 ; sleep 0.3
rm -f install.sh
echo 100 ; sleep 0.3
) | whiptail --gauge "Nettoyage…" 10 60 0

# FIN
whiptail --msgbox "Installation terminée avec succès.\n\nLes mots de passe ont été chiffrés.\nVous pouvez maintenant lancer script.sh" 10 50
clear