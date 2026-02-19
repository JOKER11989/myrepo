import os
import subprocess
import hashlib
import bz2
import json

# Configuration
CONFIG_FILE = 'repo_config.json'
DEBS_DIR = 'debs'
PACKAGES_FILE = 'Packages'
RELEASE_FILE = 'Release'

def get_file_hash(filepath, hash_type='md5'):
    h = hashlib.new(hash_type)
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def extract_control_info(deb_path):
    """Extracts the 'control' file content from a .deb package."""
    try:
        # Use dpkg-deb if available, otherwise fallback to 'ar' and 'tar'
        result = subprocess.run(['dpkg-deb', '-f', deb_path], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout
        else:
            # Fallback for systems without dpkg-deb
            subprocess.run(['ar', 'x', deb_path, 'control.tar.gz'], check=True)
            control_content = subprocess.run(['tar', '-xOf', 'control.tar.gz', './control'], capture_output=True, text=True).stdout
            os.remove('control.tar.gz')
            return control_content
    except Exception as e:
        print(f"Error extracting {deb_path}: {e}")
        return None

def update_repo():
    if not os.path.exists(DEBS_DIR):
        os.makedirs(DEBS_DIR)
        print(f"Created {DEBS_DIR} directory. Place your .deb files there.")
        return

    packages_data = []
    
    for filename in os.listdir(DEBS_DIR):
        if filename.endswith('.deb'):
            filepath = os.path.join(DEBS_DIR, filename)
            print(f"Processing {filename}...")
            
            control_text = extract_control_info(filepath)
            if control_text:
                # Add extra fields required by Cydia
                stats = os.stat(filepath)
                control_text += f"Filename: {DEBS_DIR}/{filename}\n"
                control_text += f"Size: {stats.st_size}\n"
                control_text += f"MD5sum: {get_file_hash(filepath, 'md5')}\n"
                control_text += f"SHA1: {get_file_hash(filepath, 'sha1')}\n"
                control_text += f"SHA256: {get_file_hash(filepath, 'sha256')}\n"
                packages_data.append(control_text.strip())

    # Write Packages file
    with open(PACKAGES_FILE, 'w') as f:
        f.write('\n\n'.join(packages_data) + '\n')

    # Create Packages.bz2
    with open(PACKAGES_FILE, 'rb') as f_in:
        with bz2.open(PACKAGES_FILE + '.bz2', 'wb') as f_out:
            f_out.writelines(f_in)

    # Write Release file
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
        
        release_content = ""
        for key, value in config.items():
            release_content += f"{key}: {value}\n"
        
        with open(RELEASE_FILE, 'w') as f:
            f.write(release_content)
    
    print("Repository metadata updated successfully!")

if __name__ == "__main__":
    update_repo()
