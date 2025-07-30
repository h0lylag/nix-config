#!/usr/bin/env python3

"""
This script patches all discord_krisp.node files found in the user's Discord configuration directories.
Serves as a wrapper for the krisp-patch command to apply patches to multiple files at once.
Uses multithreading to patch files concurrently for better performance.
"""

import os
import subprocess
import glob
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
MAX_THREADS = -1  # Set to -1 for unlimited threads

def patch_file(krisp_node):
    """Patch a single krisp node file and return the result."""
    try:
        result = subprocess.run(
            ["krisp-patch", krisp_node],
            capture_output=True,
            text=True,
            check=False
        )
        
        output = result.stdout + result.stderr
        
        return {
            'file': krisp_node,
            'success': result.returncode == 0,
            'output': output,
            'error': None
        }
        
    except FileNotFoundError:
        return {
            'file': krisp_node,
            'success': False,
            'output': '',
            'error': 'krisp-patch command not found'
        }
    except Exception as e:
        return {
            'file': krisp_node,
            'success': False,
            'output': '',
            'error': str(e)
        }

def main():
    # Discord applications to check
    apps = ["discord", "discordptb"]
    
    # Collect all krisp node files
    all_files = []
    for app in apps:
        config_dir = Path.home() / ".config" / app
        
        if not config_dir.exists():
            continue
            
        pattern = str(config_dir / "*/modules/discord_krisp/discord_krisp.node")
        krisp_nodes = glob.glob(pattern)
        all_files.extend(krisp_nodes)
    
    if not all_files:
        print("No discord_krisp.node files found to patch.")
        return 0
    
    print(f"Found {len(all_files)} files to patch. Processing concurrently...")
    
    patched_any = False
    
    # Determine max workers: -1 means unlimited (one thread per file)
    max_workers = len(all_files) if MAX_THREADS == -1 else min(len(all_files), MAX_THREADS)
    
    # Use ThreadPoolExecutor to patch files concurrently
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_file = {executor.submit(patch_file, file): file for file in all_files}
        
        # Process results as they complete
        for future in as_completed(future_to_file):
            result = future.result()
            
            if result['error']:
                print(f"Error processing {result['file']}: {result['error']}")
                if result['error'] == 'krisp-patch command not found':
                    return 1
                continue
            
            if result['success']:
                patched_any = True
            
            # Check output for status
            if "already patched" in result['output']:
                print(f"Already patched: {result['file']}")
            elif "Found patch location" in result['output']:
                print(f"Patched: {result['file']}")
            else:
                print(f"Patch failed: {result['file']}")
                print(f"  krisp-patcher output: {result['output'].strip()}")
    
    # Final status message
    if patched_any:
        print("All found discord_krisp.node files have been processed.")
    else:
        print("No files were patched. (Possible errors encountered.)")
    
    return 0

if __name__ == "__main__":
    exit(main())