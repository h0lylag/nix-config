#!/usr/bin/env python3
import os
import shutil
import tarfile
import logging
from datetime import datetime
from glob import glob

# ==========================================
# 1. CONFIGURATION
# ==========================================

# Where are the qBittorrent instances located?
SOURCE_ROOT = os.environ.get("QBT_SOURCE_ROOT", "/var/lib/qbittorrent/")

# Where should the backups go?
BACKUP_ROOT = os.environ.get("QBT_BACKUP_ROOT", "/mnt/hdd-pool/main/Backups/qBittorrent/")

# Safety: The script will ABORT if this specific path is not a mount point.
MOUNT_POINT_TO_CHECK = os.environ.get("QBT_MOUNT_POINT", "/mnt/hdd-pool")

# --- COMPRESSION SETTINGS ---
# 1 (Fastest) to 9 (Smallest). 6 is the standard balance.
COMPRESSION_LEVEL = int(os.environ.get("QBT_COMPRESSION_LEVEL", 6))

# --- HOURLY SETTINGS ---
ENABLE_HOURLY = os.environ.get("QBT_ENABLE_HOURLY", "True").lower() == "true"
KEEP_HOURLY   = int(os.environ.get("QBT_KEEP_HOURLY", 24))

# --- DAILY SETTINGS ---
ENABLE_DAILY  = os.environ.get("QBT_ENABLE_DAILY", "True").lower() == "true"
KEEP_DAILY    = int(os.environ.get("QBT_KEEP_DAILY", 7))

# --- WEEKLY SETTINGS ---
ENABLE_WEEKLY = os.environ.get("QBT_ENABLE_WEEKLY", "True").lower() == "true"
KEEP_WEEKLY   = int(os.environ.get("QBT_KEEP_WEEKLY", 4))

# --- MONTHLY SETTINGS ---
ENABLE_MONTHLY = os.environ.get("QBT_ENABLE_MONTHLY", "True").lower() == "true"
KEEP_MONTHLY   = int(os.environ.get("QBT_KEEP_MONTHLY", 6))

# --- PROMOTION SCHEDULING ---
# If set to 0-23, daily/weekly/monthly promotions will ONLY happen during that hour.
# Defaults to -1 (disabled -> promote on first run of the period).
PROMOTION_HOUR = int(os.environ.get("QBT_PROMOTION_HOUR", -1))

# ==========================================
# END CONFIGURATION
# ==========================================

RETENTION = {
    'hourly':  {'enabled': ENABLE_HOURLY,  'keep': KEEP_HOURLY},
    'daily':   {'enabled': ENABLE_DAILY,   'keep': KEEP_DAILY},
    'weekly':  {'enabled': ENABLE_WEEKLY,  'keep': KEEP_WEEKLY},
    'monthly': {'enabled': ENABLE_MONTHLY, 'keep': KEEP_MONTHLY}
}

# Log to stdout for systemd journal integration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def is_mount_safe():
    """Ensure the destination drive is actually mounted."""
    if not os.path.exists(MOUNT_POINT_TO_CHECK):
        return False
    return os.path.ismount(MOUNT_POINT_TO_CHECK)

def tar_filter(tarinfo):
    """Exclude useless files and dangerous device nodes."""
    name = tarinfo.name
    
    # Exclude lock files 
    if name.endswith(".lock") or "qBittorrent.lock" in name:
        return None
        
    # Exclude cache/logs
    if "/cache/" in name or "/logs/" in name:
        return None
        
    # Exclude Sockets, Character Devices, and Block Devices
    if tarinfo.issock() or tarinfo.ischr() or tarinfo.isblk():
        return None
        
    return tarinfo

def should_run_backup(interval, last_backup_time, now):
    """
    Decide if a backup is needed based on strict Calendar Boundaries.
    """
    if last_backup_time is None:
        return True

    if interval == 'hourly':
        # Compare "Hour Slots" - robust against minute drift
        last_hour = last_backup_time.replace(minute=0, second=0, microsecond=0)
        current_hour = now.replace(minute=0, second=0, microsecond=0)
        return last_hour != current_hour
        
    
    # --- PROMOTION HOUR CHECK ---
    # For daily/weekly/monthly, if a specific promotion hour is set,
    # we ONLY promote if we are currently in that hour.
    if PROMOTION_HOUR >= 0:
        if now.hour != PROMOTION_HOUR:
            return False

    if interval == 'daily':
        # Different calendar days
        return last_backup_time.date() != now.date()
        
    if interval == 'weekly':
        # Compare (ISO Year, ISO Week) tuples to handle year rollovers correctly
        ly, lw, _ = last_backup_time.isocalendar()
        ny, nw, _ = now.isocalendar()
        return (ly, lw) != (ny, nw)
        
    if interval == 'monthly':
        # Different calendar months
        return (last_backup_time.year, last_backup_time.month) != (now.year, now.month)

    return False

def clean_old_backups(backup_folder, count):
    if not os.path.exists(backup_folder):
        return
    
    files = glob(os.path.join(backup_folder, "*.tar.gz"))
    files = sorted(files, key=os.path.getmtime, reverse=True)
    
    if len(files) > count:
        for f in files[count:]:
            try:
                os.remove(f)
                logging.info(f"Pruned old backup: {f}")
            except OSError as e:
                logging.error(f"Error deleting {f}: {e}")

def get_latest_backup_time(backup_folder):
    files = glob(os.path.join(backup_folder, "*.tar.gz"))
    if not files:
        return None
    latest = max(files, key=os.path.getmtime)
    return datetime.fromtimestamp(os.path.getmtime(latest))

def perform_backup(instance_name):
    src_path = os.path.join(SOURCE_ROOT, instance_name)
    dst_base = os.path.join(BACKUP_ROOT, instance_name)
    
    if not os.path.exists(src_path):
        logging.warning(f"Source not found: {src_path}")
        return

    # Use PID to ensure temp file is unique
    temp_archive = os.path.join(dst_base, f".tmp_{os.getpid()}_{instance_name}.tar.gz")

    try:
        os.makedirs(dst_base, exist_ok=True)
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"{instance_name}_{timestamp}.tar.gz"
        
        logging.info(f"Archiving {instance_name} (Level {COMPRESSION_LEVEL})...")
        
        # dereference=False ensures we archive symlinks AS links, not the target content
        with tarfile.open(temp_archive, "w:gz", compresslevel=COMPRESSION_LEVEL, dereference=False) as tar:
            tar.add(src_path, arcname=os.path.basename(src_path), filter=tar_filter)
            
        now = datetime.now()
        
        # Distribute to Retention Folders
        for interval, config in RETENTION.items():
            if not config['enabled']:
                continue

            interval_path = os.path.join(dst_base, interval)
            os.makedirs(interval_path, exist_ok=True)
            
            last_time = get_latest_backup_time(interval_path)
            
            if should_run_backup(interval, last_time, now):
                final_dest = os.path.join(interval_path, filename)
                shutil.copy2(temp_archive, final_dest)
                logging.info(f"Promoted to {interval}: {final_dest}")
                clean_old_backups(interval_path, config['keep'])

    except Exception as e:
        logging.error(f"Backup failed for {instance_name}: {str(e)}")
        
    finally:
        if os.path.exists(temp_archive):
            try:
                os.remove(temp_archive)
            except OSError:
                pass

def main():
    if not is_mount_safe():
        msg = f"CRITICAL: Mount point {MOUNT_POINT_TO_CHECK} is not mounted! Aborting to protect root FS."
        logging.critical(msg)
        # We return silently to stdout to keep cron/systemd logs clean, relying on the log file
        return

    if not os.path.exists(SOURCE_ROOT):
        logging.error(f"Source directory {SOURCE_ROOT} does not exist.")
        return

    instances = [d for d in os.listdir(SOURCE_ROOT) if os.path.isdir(os.path.join(SOURCE_ROOT, d))]
    
    logging.info("Starting Backup Run...")
    
    for instance in instances:
        if instance == 'lost+found': 
            continue
            
        logging.info(f"Processing instance: {instance}")
        perform_backup(instance)
    
    logging.info("Backup Run Complete.")

if __name__ == "__main__":
    main()