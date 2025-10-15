# 🧩 barebash

**barebash** is a **minimalist Bash environment** inspired by [Yeoman](https://yeoman.io), designed for **slow, remote, or constrained systems** where frameworks like *Oh My Zsh* are too heavy.

The idea:  
> Provide a fast, self-documented way to run and edit your most used scripts — without overhead.

---

## ⚙️ Concept

`barebash` is built around a lightweight Bash binary called `ye`, which lets you:

- automatically list all your `.sh` scripts in a given directory,  
- execute them instantly (`ye backup`),  
- or open them for editing (`ye backup edit`),  
- all with **native autocompletion**.

---

## 🚀 Quick Example

```bash
$ ye <TAB>
backup  deploy  monitor

$ ye backup
🧩 Starting backup...
✅ Backup complete!
📦 Saved to: /home/herve/backups/backup-2025-10-15.tar.gz

$ ye backup edit
# → opens scripts/backup.sh in vim