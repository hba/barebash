#!/bin/zsh
# ============================================================
#  sync
#  Synchronisation entre PC principal (Documents/Note)
#  et PC client (Documents/Perso)
# ============================================================

set -euo pipefail
setopt null_glob

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
function pause() {
  echo ""
  read -s -k "?Appuyez sur une touche pour revenir au menu..."
}

function check_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo "❌ Fichier introuvable : $file"; return 1; }
}

function cleanup_tmp() {
  rm -f /tmp/sync_*.tar.gz 2>/dev/null || true
}

# ------------------------------------------------------------
# Commandes PC principal
# ------------------------------------------------------------
function backupTmp() {
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

  # --- Création de l’archive ---
  echo "$tmp_files" | tar czf "$archive" -T -

  # --- Fusion dans l’image ---
  local base_img="$HOME/Documents/Note/Images/sign.png"
  if [[ -f "$base_img" ]]; then
    cat "$base_img" "$archive" > "$HOME/Downloads/signt.png"
    echo "✅ Sauvegarde terminée → ~/Downloads/signt.png"
  else
    echo "❌ Image de base introuvable : $base_img"
  fi

  cleanup_tmp
}

function extract() {
  local src="$HOME/Downloads/sign.png"
  check_file "$src" || return
  echo "📁 Sélection du dossier de destination :"
  select dest in "$HOME/Documents/Note/Zk"/*; do
    [[ -n "$dest" ]] || { echo "❌ Choix invalide."; return; }
    echo "📦 Extraction vers : $dest"
    tail -n +1 "$src" | tar xzf - -C "$dest"
    echo "✅ Extraction réussie vers $dest"
    break
  done
  cleanup_tmp
}

function extractMp3() {
  local src="$HOME/Downloads/signm.png"
  check_file "$src" || return
  echo "🎵 Extraction des fichiers MP3 vers ~/Downloads/"
  tail -n +1 "$src" | tar xzf - -C "$HOME/Downloads/"
  echo "✅ Fichiers extraits dans ~/Downloads/"
  cleanup_tmp
}

# ------------------------------------------------------------
# Commandes PC client
# ------------------------------------------------------------
function backup() {
  echo "🗂  Sauvegarde du dossier Zk..."
  cleanup_tmp
  local archive="/tmp/sync_zk.tar.gz"
  tar czf "$archive" -C "$HOME/Documents/Perso" Zk
  echo "🧩 Fusion avec l’image..."
  cat "$HOME/Documents/Perso/Images/sign.png" "$archive" > "$HOME/Downloads/sign.png"
  echo "✅ Sauvegarde terminée → ~/Downloads/sign.png"
  cleanup_tmp
}

function backupMp3() {
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
  cat "$HOME/Documents/Perso/Images/sign.png" "$archive" > "$HOME/Downloads/signm.png"
  echo "✅ Sauvegarde terminée → ~/Downloads/signm.png"
  cleanup_tmp
}

function extractTmp() {
  local src="$HOME/Downloads/signt.png"
  check_file "$src" || return
  echo "📦 Extraction vers ~/Documents/Perso/Zk/"
  tail -n +1 "$src" | tar xzf - -C "$HOME/Documents/Perso/Zk/"
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
    read -r "?👉 Choix : " choice
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
    read -r "?👉 Choix : " choice
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