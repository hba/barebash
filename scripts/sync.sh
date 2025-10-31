#!/usr/bin/env bash
# ============================================================
#  sync (version sans dépendances externes)
#  - Archive .tar.gz encodée en Base64 entre deux marqueurs
#    ###SYNC_START### ... ###SYNC_END###
#  - Compatible macOS/Linux/WSL
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
# Utilitaires
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

# Encodage/décodage base64 compatibles macOS/Linux
b64enc() {  # b64enc <in> <out>
  if [[ "$(uname)" == "Darwin" ]]; then
    base64 -i "$1" -o "$2"
  else
    base64 "$1" > "$2"
  fi
}
b64dec() {  # b64dec <in> <out>
  if [[ "$(uname)" == "Darwin" ]]; then
    base64 -D -i "$1" -o "$2"
  else
    base64 -d "$1" > "$2"
  fi
}

# ------------------------------------------------------------
# Fonctions communes d’injection/extraction
# ------------------------------------------------------------
embed_archive_in_png() {
  local base_img="$1"   # PNG source
  local archive="$2"    # .tar.gz
  local output="$3"     # PNG destination (toujours ~/Downloads/sign.png / signm.png)
  check_file "$base_img" || return
  check_file "$archive" || return

  echo "🧩 Insertion de l’archive encodée dans l’image..."
  b64enc "$archive" /tmp/archive.b64

  {
    cat "$base_img"
    printf "\n###SYNC_START###\n"
    cat /tmp/archive.b64
    printf "\n###SYNC_END###\n"
  } > "$output"

  # Petit contrôle : présence des marqueurs + sha256 du bloc encodé
  if strings -a "$output" | grep -q "###SYNC_START###"; then
    sha=$(shasum -a 256 /tmp/archive.b64 | awk '{print $1}')
    echo "✅ Fusion terminée → $output (SHA256 bloc b64: $sha)"
  else
    echo "⚠️  Attention : marqueurs non détectés dans $output"
  fi
}

extract_archive_from_png() {
  local src="$1"
  local dest_dir="$2"
  check_file "$src" || return

  echo "🧩 Recherche de la section encodée dans $src ..."
  # Extraction binaire-safe du bloc entre marqueurs
  perl -0777 -ne 'if (/###SYNC_START###(.*?)###SYNC_END###/s){print $1}' "$src" > /tmp/archive.b64 || true

  if [[ ! -s /tmp/archive.b64 ]]; then
    echo "❌ Aucun bloc ###SYNC_START###/###SYNC_END### trouvé dans le fichier."
    echo "   → Le fichier a pu être recompressé/altéré ou l’injection n’a pas eu lieu."
    return 1
  fi

  echo "📦 Décodage et extraction..."
  b64dec /tmp/archive.b64 /tmp/extracted.tar.gz
  tar xzf /tmp/extracted.tar.gz -C "$dest_dir"
  echo "✅ Extraction réussie vers $dest_dir"
  cleanup_tmp
}

checkSync() {
  local src="$1"
  check_file "$src" || return
  echo "🔎 Vérification de $src"
  if ! strings -a "$src" | grep -q "###SYNC_START###"; then
    echo "❌ Marqueurs absents."
    return 1
  fi
  # Affiche un hash du bloc encodé pour confirmer
  perl -0777 -ne 'if (/###SYNC_START###(.*?)###SYNC_END###/s){print $1}' "$src" > /tmp/archive.b64 || true
  if [[ ! -s /tmp/archive.b64 ]]; then
    echo "❌ Marqueurs vus mais bloc vide."
    return 1
  fi
  sha=$(shasum -a 256 /tmp/archive.b64 | awk '{print $1}')
  echo "✅ Marqueurs trouvés. SHA256 bloc b64 : $sha"
  echo "📝 Aperçu (premières lignes) :"
  head -n 3 /tmp/archive.b64
  cleanup_tmp
}

# ------------------------------------------------------------
# PC principal
# ------------------------------------------------------------
backupTmp() {
  echo "🔧 Création de l’archive temporaire..."
  cleanup_tmp
  local archive="/tmp/sync_tmp.tar.gz"

  local tmp_files
  tmp_files=$(find "$HOME/Documents/Note" -type f -name "tmp*.md" | sort || true)
  if [[ -z "${tmp_files}" ]]; then
    echo "ℹ️  Aucun fichier tmp*.md trouvé, rien à sauvegarder."
    return
  fi

  # Crée l’archive depuis la liste (sécurise espaces via -T -)
  echo "$tmp_files" | tar czf "$archive" -T -
  # Injection dans ~/Downloads/sign.png (cohérence)
  embed_archive_in_png "$HOME/Documents/Note/Images/sign.png" "$archive" "$HOME/Downloads/sign.png"
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
# PC client
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
  mp3_list=$(find "$HOME/Downloads" -type f -name "*.mp3" | sort || true)

  if [[ -z "$mp3_list" ]]; then
    echo "ℹ️  Aucun fichier MP3 trouvé, rien à sauvegarder."
    return
  fi

  echo "$mp3_list" | tar czf "$archive" -T -
  embed_archive_in_png "$HOME/Documents/Perso/Images/sign.png" "$archive" "$HOME/Downloads/signm.png"
  cleanup_tmp
}

extractTmp() {
  local src="$HOME/Downloads/sign.png"
  check_file "$src" || return
  extract_archive_from_png "$src" "$HOME/Documents/Perso/Zk/"
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
while true; do
  echo ""
  echo "------------------------------------------------------------"
  if [[ "$ENV_TYPE" == "main" ]]; then
    echo "=== PC Principal détecté ==="
    echo "1) backupTmp   - Sauvegarder les fichiers tmp*.md dans ~/Downloads/sign.png"
    echo "2) extract     - Extraire ~/Downloads/sign.png vers un dossier dans Note/Zk/"
    echo "3) extractMp3  - Extraire ~/Downloads/signm.png vers ~/Downloads/"
    echo "4) checkSync   - Vérifier le contenu encodé de ~/Downloads/sign.png"
    echo "q) Quitter"
    echo "------------------------------------------------------------"
    read -rp "👉 Choix : " choice
    case "$choice" in
      1) backupTmp ;;
      2) extract ;;
      3) extractMp3 ;;
      4) checkSync "$HOME/Downloads/sign.png" ;;
      q|Q) echo "👋 Au revoir."; exit 0 ;;
      *) echo "❌ Choix invalide." ;;
    esac
  else
    echo "=== PC Client détecté ==="
    echo "1) backup      - Sauvegarder Perso/Zk vers ~/Downloads/sign.png"
    echo "2) backupMp3   - Sauvegarder les MP3 de Downloads vers ~/Downloads/signm.png"
    echo "3) extractTmp  - Extraire ~/Downloads/sign.png vers Perso/Zk/"
    echo "4) checkSync   - Vérifier le contenu encodé de ~/Downloads/sign.png"
    echo "q) Quitter"
    echo "------------------------------------------------------------"
    read -rp "👉 Choix : " choice
    case "$choice" in
      1) backup ;;
      2) backupMp3 ;;
      3) extractTmp ;;
      4) checkSync "$HOME/Downloads/sign.png" ;;
      q|Q) echo "👋 Au revoir."; exit 0 ;;
      *) echo "❌ Choix invalide." ;;
    esac
  fi
  pause
done