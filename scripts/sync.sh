#!/usr/bin/env bash
# ============================================================
#  sync
#  Synchronisation entre PC principal (Documents/Note)
#  et PC client (Documents/Perso)
#  Nouvelle version sans pngcrush :
#  → archive encodée en Base64 entre marqueurs ###SYNC_START### / ###SYNC_END###
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
  rm -f /tmp/sync_*.tar.gz /tmp/archive.b64 /tmp/extracted.tar.gz 2>/dev/null || true
}

# ------------------------------------------------------------
# Fonctions communes d’encodage/décodage
# ------------------------------------------------------------
embed_archive_in_png() {
  local base_img="$1"
  local archive="$2"
  local output="$3"
  check_file "$base_img" || return
  check_file "$archive" || return

  echo "🧩 Insertion de l’archive encodée dans l’image..."
  base64 "$archive" > /tmp/archive.b64
  {
    cat "$base_img"
    echo ""
    echo "###SYNC_START###"
    cat /tmp/archive.b64
    echo ""
    echo "###SYNC_END###"
  } > "$output"

  echo "✅ Fusion terminée → $output"
}

extract_archive_from_png() {
  local src="$1"
  local dest_dir="$2"
  check_file "$src" || return

  echo "🧩 Extraction de la section encodée..."
  awk '/###SYNC_START###/{flag=1;next}/###SYNC_END###/{flag=0}flag' "$src" > /tmp/archive.b64

  if [[ ! -s /tmp/archive.b64 ]]; then
    echo "❌ Aucune archive trouvée dans $src"
    return 1
  fi

  echo "📦 Décodage et extraction..."
  base64 -d /tmp/archive.b64 > /tmp/extracted.tar.gz
  tar xzf /tmp/extracted.tar.gz -C "$dest_dir"
  echo "✅ Extraction réussie vers $dest_dir"
  cleanup_tmp
}

# ------------------------------------------------------------
# Commandes PC principal
# ------------------------------------------------------------
backupTmp() {
  echo "🔧 Création de l’archive temporaire..."
  cleanup_tmp
  local archive="/tmp/sync_tmp.tar.gz"

  tmp_files=$(find "$HOME/Documents/Note" -type f -name "tmp*.md")
  if [[ -z "$tmp_files" ]]; then
    echo "ℹ️  Aucun fichier tmp*.md trouvé, rien à sauvegarder."
    return
  fi

  echo "$tmp_files" | tar czf "$archive" -T -
  embed_archive_in_png "$HOME/Documents/Note/Images/sign.png" "$archive" "$HOME/Downloads/signt.png"
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
    [[ -z "$dest" ]] && echo "❌ Choix invalide." && return
    extract_archive_from_png "$src" "$dest"
    break
  done
}

extractMp3() {
  local src="$HOME/Downloads/signm.png"
  check_file "$src" || return
  extract_archive_from_png "$src" "$HOME/Downloads"
}

# ------------------------------------------------------------
# Commandes PC client
# ------------------------------------------------------------
backup() {
  echo "🗂  Sauvegarde du dossier Zk..."
  cleanup_tmp
  local archive="/tmp/sync_zk.tar.gz"
  tar czf "$archive" -C "$HOME/Documents/Perso" Zk
  embed_archive_in_png "$HOME/Documents/Perso/Images/sign.png" "$archive" "$HOME/Downloads/sign.png"
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
  embed_archive_in_png "$HOME/Documents/Perso/Images/sign.png" "$archive" "$HOME/Downloads/signm.png"
  cleanup_tmp
}

extractTmp() {
  local src="$HOME/Downloads/signt.png"
  check_file "$src" || return
  extract_archive_from_png "$src" "$HOME/Documents/Perso/Zk/"
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