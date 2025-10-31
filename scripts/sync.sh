#!/usr/bin/env bash
# ============================================================
#  sync
#  Synchronisation entre PC principal (Documents/Note)
#  et PC client (Documents/Perso)
#  → version fiable : archive encodée en Base64 dans un chunk PNG
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# Détection de l’environnement
# ------------------------------------------------------------
if [[ -d "$HOME/Documents/Note" ]]; then
  ENV_TYPE="main"
  BASE_DIR="$HOME/Documents/Note"
  echo "🖥️  Environnement détecté : PC Principal"
elif [[ -d "$HOME/Documents/Perso" ]]; then
  ENV_TYPE="client"
  BASE_DIR="$HOME/Documents/Perso"
  echo "💼 Environnement détecté : PC Client"
else
  echo "❌ Impossible de déterminer l’environnement (Note/Perso absent)."
  exit 1
fi

# ------------------------------------------------------------
# Fonctions utilitaires
# ------------------------------------------------------------
pause() {
  echo ""
  read -n 1 -s -r -p "Appuyez sur une touche pour revenir au menu..."
  echo ""
}

check_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "❌ Fichier introuvable : $file"
    return 1
  fi
}

cleanup_tmp() {
  rm -f /tmp/sync_*.tar.gz /tmp/archive.b64 2>/dev/null || true
}

require_tools() {
  for cmd in pngcrush base64 tar; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "❌ Outil manquant : $cmd"
      exit 1
    }
  done
}

require_tools

# ------------------------------------------------------------
# Commandes PC principal
# ------------------------------------------------------------
backupTmp() {
  echo "🔧 Création de l’archive temporaire..."
  cleanup_tmp
  local archive="/tmp/sync_tmp.tar.gz"

  # --- Recherche des fichiers tmp*.md ---
  local tmp_files
  tmp_files=$(find "$HOME/Documents/Note" -type f -name "tmp*.md")
  if [[ -z "$tmp_files" ]]; then
    echo "ℹ️  Aucun fichier tmp*.md trouvé, rien à sauvegarder."
    return
  fi

  echo "$tmp_files" | tar czf "$archive" -T -

  echo "📦 Encodage en Base64..."
  base64 "$archive" > /tmp/archive.b64

  local base_img="$HOME/Documents/Note/Images/sign.png"
  local output="$HOME/Downloads/signt.png"
  check_file "$base_img" || return

  echo "🧩 Insertion dans le PNG (chunk SYNC_DATA)..."
  pngcrush -q -text a "SYNC_DATA" "$(cat /tmp/archive.b64)" "$base_img" "$output"

  echo "✅ Sauvegarde terminée → $output"
  cleanup_tmp
}

extract() {
  local src="$HOME/Downloads/sign.png"
  check_file "$src" || return

  echo "📁 Sélection du dossier de destination :"
  local dirs=("$HOME/Documents/Note/Zk"/*/)
  if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "❌ Aucun dossier trouvé dans ~/Documents/Note/Zk/"
    return
  fi

  select dest in "${dirs[@]}"; do
    if [[ -z "$dest" ]]; then
      echo "❌ Choix invalide."
      return
    fi

    echo "🧩 Extraction de l’archive Base64 depuis le PNG..."
    pngcrush -q -extract text "$src" /tmp/texts.txt

    if ! grep -q "keyword: SYNC_DATA" /tmp/texts.txt; then
      echo "❌ Aucun champ SYNC_DATA trouvé dans $src"
      return
    fi

    echo "📦 Décodage et extraction..."
    grep -A9999 "keyword: SYNC_DATA" /tmp/texts.txt | tail -n +2 | base64 -d > /tmp/extracted.tar.gz
    tar xzf /tmp/extracted.tar.gz -C "$dest"
    echo "✅ Extraction réussie vers $dest"
    break
  done

  cleanup_tmp
}

extractMp3() {
  local src="$HOME/Downloads/signm.png"
  check_file "$src" || return

  echo "🧩 Extraction de l’archive Base64 depuis $src..."
  pngcrush -q -extract text "$src" /tmp/texts.txt

  if ! grep -q "keyword: SYNC_DATA" /tmp/texts.txt; then
    echo "❌ Aucun champ SYNC_DATA trouvé dans $src"
    return
  fi

  grep -A9999 "keyword: SYNC_DATA" /tmp/texts.txt | tail -n +2 | base64 -d > /tmp/extracted.tar.gz
  tar xzf /tmp/extracted.tar.gz -C "$HOME/Downloads/"
  echo "✅ Fichiers MP3 extraits dans ~/Downloads/"
  cleanup_tmp
}

# ------------------------------------------------------------
# Commandes PC client
# ------------------------------------------------------------
backup() {
  echo "🗂  Sauvegarde du dossier Zk..."
  cleanup_tmp
  local archive="/tmp/sync_zk.tar.gz"
  tar czf "$archive" -C "$HOME/Documents/Perso" Zk
  base64 "$archive" > /tmp/archive.b64

  echo "🧩 Insertion dans le PNG..."
  pngcrush -q -text a "SYNC_DATA" "$(cat /tmp/archive.b64)" "$HOME/Documents/Perso/Images/sign.png" "$HOME/Downloads/sign.png"
  echo "✅ Sauvegarde terminée → ~/Downloads/sign.png"
  cleanup_tmp
}

backupMp3() {
  echo "🎧 Sauvegarde des MP3 de ~/Downloads..."
  cleanup_tmp
  local archive="/tmp/sync_mp3.tar.gz"
  local mp3_list
  mp3_list=$(find "$HOME/Downloads" -type f -name "*.mp3")

  if [[ -z "$mp3_list" ]]; then
    echo "ℹ️  Aucun fichier MP3 trouvé, rien à sauvegarder."
    return
  fi

  echo "$mp3_list" | tar czf "$archive" -T -
  base64 "$archive" > /tmp/archive.b64
  pngcrush -q -text a "SYNC_DATA" "$(cat /tmp/archive.b64)" "$HOME/Documents/Perso/Images/sign.png" "$HOME/Downloads/signm.png"
  echo "✅ Sauvegarde terminée → ~/Downloads/signm.png"
  cleanup_tmp
}

extractTmp() {
  local src="$HOME/Downloads/signt.png"
  check_file "$src" || return

  echo "🧩 Extraction de l’archive Base64 depuis $src..."
  pngcrush -q -extract text "$src" /tmp/texts.txt

  if ! grep -q "keyword: SYNC_DATA" /tmp/texts.txt; then
    echo "❌ Aucun champ SYNC_DATA trouvé dans $src"
    return
  fi

  grep -A9999 "keyword: SYNC_DATA" /tmp/texts.txt | tail -n +2 | base64 -d > /tmp/extracted.tar.gz
  tar xzf /tmp/extracted.tar.gz -C "$HOME/Documents/Perso/Zk/"
  echo "✅ Extraction réussie dans ~/Documents/Perso/Zk/"
  cleanup_tmp
}

# ------------------------------------------------------------
# Boucle de menu principale
# ------------------------------------------------------------
while true; do
  echo ""
  echo "------------------------------------------------------------"
  if [[ "$ENV_TYPE" == "main" ]]; then
    echo "=== PC Principal détecté ==="
    echo "1) backupTmp  - Sauvegarder les fichiers tmp*.md dans signt.png"
    echo "2) extract    - Extraire sign.png vers un dossier dans Note/Zk/"
    echo "3) extractMp3 - Extraire signm.png vers le dossier ~/Downloads/"
    echo "q) Quitter"
    echo "------------------------------------------------------------"
    read -rp "👉 Choix : " choice
    case "$choice" in
      1) backupTmp ;;
      2) extract ;;
      3) extractMp3 ;;
      q|Q) echo "👋 Au revoir."; exit 0 ;;
      *) echo "❌ Choix invalide." ;;
    esac
  else
    echo "=== PC Client détecté ==="
    echo "1) backup     - Sauvegarder Perso/Zk vers sign.png"
    echo "2) backupMp3  - Sauvegarder les MP3 de Downloads vers signm.png"
    echo "3) extractTmp - Extraire signt.png vers Perso/Zk/"
    echo "q) Quitter"
    echo "------------------------------------------------------------"
    read -rp "👉 Choix : " choice
    case "$choice" in
      1) backup ;;
      2) backupMp3 ;;
      3) extractTmp ;;
      q|Q) echo "👋 Au revoir."; exit 0 ;;
      *) echo "❌ Choix invalide." ;;
    esac
  fi
  pause
done