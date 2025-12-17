#!/bin/bash
# init.sh

# Saisie des informations
downloadsource=$(dialog --stdout --inputbox "Adresse de téléchargement du script :" 10 60)
if [ $? -ne 0 ] || [ -z "$downloadsource" ]; then clear; exit 1; fi
httpuser=$(dialog --stdout --inputbox "Utilisateur pour Auth Apache :" 10 60)
if [ $? -ne 0 ] || [ -z "$httpuser" ]; then clear; exit 1; fi
httppassword=$(dialog --stdout --passwordbox "Mot de passe Auth Apache :" 10 60)
if [ $? -ne 0 ] || [ -z "$httppassword" ]; then clear; exit 1; fi

# Chiffrement du mot de passe
(
  echo 20; sleep 0.3
  echo -n "$httppassword" | gpg --symmetric --cipher-algo AES256 -o httppassword.gpg
  echo 100; sleep 0.2
) | dialog --gauge "Chiffrement du mot de passe (AES256)..." 10 60 0

# Paramètres API
api_url=$(dialog --stdout --inputbox "URL API :" 10 60)
if [ $? -ne 0 ] || [ -z "$api_url" ]; then clear; exit 1; fi
api_method="POST"
api_auth_type="bearer"

# Saisie du token
if [ ! -f apitoken.gpg ]; then
  api_token_clear=$(dialog --stdout --passwordbox "Token API : " 10 60)
  if [ $? -ne 0 ] || [ -z "$api_token_clear" ]; then clear; exit 1; fi
  (
    echo 20; sleep 0.2
    echo -n "$api_token_clear" | gpg --symmetric --cipher-algo AES256 -o apitoken.gpg
    echo 100; sleep 0.2
  ) | dialog --gauge "Chiffrement du token API (AES256)..." 10 60 0
fi

# Champ multipart pour les fichiers
glpi_file_field_index=$(dialog --stdout --inputbox \
"Index du champ fichier côté multipart (ex: 0 pour filename[0]) :" 10 60 "0")
if [ $? -ne 0 ] || [ -z "$glpi_file_field_index" ]; then clear; exit 1; fi

# Téléchargement install.sh et conf
(
  echo 10; sleep 0.3
  wget -q "$downloadsource/install.sh"
  echo 50; sleep 0.3
  mv main.conf main.conf.bak 2>/dev/null
  echo 70; sleep 0.2
  wget -q "$downloadsource/main.conf"
  echo 100; sleep 0.3
) | dialog --gauge "Téléchargement des fichiers…" 10 60 0

# Mise à jour de main.conf
(
  echo 30; sleep 0.3
  sed -i "s|pathtoinstallfolder|$downloadsource|g" main.conf
  echo 60; sleep 0.3
  sed -i "s|userforhttpauth|$httpuser|g" main.conf
  echo 75; sleep 0.2
  sed -i "s|passwordforhttpauth|$httppassword|g" main.conf
  echo 85; sleep 0.2
  # Ajouts API
  sed -i "s|^api_url=.*|api_url=\"$api_url\"|g" main.conf 2>/dev/null || echo "api_url=\"$api_url\"" >> main.conf
  sed -i "s|^api_method=.*|api_method=\"$api_method\"|g" main.conf 2>/dev/null || echo "api_method=\"$api_method\"" >> main.conf
  sed -i "s|^api_auth_type=.*|api_auth_type=\"$api_auth_type\"|g" main.conf 2>/dev/null || echo "api_auth_type=\"$api_auth_type\"" >> main.conf
  sed -i "s|^api_token_file=.*|api_token_file=\"apitoken.gpg\"|g" main.conf 2>/dev/null || echo "api_token_file=\"apitoken.gpg\"" >> main.conf
  sed -i "s|^api_extra_headers=.*|api_extra_headers=\"$api_extra_headers\"|g" main.conf 2>/dev/null || echo "api_extra_headers=\"$api_extra_headers\"" >> main.conf
  sed -i "s|^glpi_file_field_index=.*|glpi_file_field_index=\"$glpi_file_field_index\"|g" main.conf 2>/dev/null || echo "glpi_file_field_index=\"$glpi_file_field_index\"" >> main.conf
  echo 100; sleep 0.2
) | dialog --gauge "Mise à jour de la configuration…" 10 60 0

# Lancement de l'installation
(
  echo 20; sleep 0.5
  bash install.sh >/dev/null 2>&1
  echo 100; sleep 0.3
) | dialog --gauge "Installation en cours…" 10 60 0

# Nettoyage final
(
  echo 50; sleep 0.3
  rm -f install.sh
  echo 100; sleep 0.3
) | dialog --gauge "Nettoyage…" 10 60 0

# FIN
dialog --msgbox "Installation terminée avec succès." 7 50
clear
