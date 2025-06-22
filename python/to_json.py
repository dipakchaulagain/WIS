import subprocess
import json
import os
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def run_powershell_script(ps1_path):
    """Execute PowerShell script and return JSON output."""
    try:
        logger.info(f"Executing PowerShell script: {ps1_path}")
        result = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps1_path],
            capture_output=True,
            text=True,
            check=True
        )
        logger.info("PowerShell script executed successfully")
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing PowerShell script: {e.stderr}")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Error parsing JSON output: {e}")
        return None

def save_to_json(data, output_path):
    """Save data to JSON file."""
    try:
        with open(output_path, "w") as f:
            json.dump(data, f, indent=4)
        logger.info(f"System information exported to {output_path}")
    except Exception as e:
        logger.error(f"Error saving JSON file: {e}")

def main():
    # Paths (updated to match error message)
    ps1_path = r"F:\Personal\WIS\Scripts\GetSystemInfoJson.ps1"
    output_path = r"F:\Personal\WIS\system_info.json"

    # Verify PowerShell script exists
    if not os.path.exists(ps1_path):
        logger.error(f"PowerShell script not found at: {ps1_path}")
        return

    # Run PowerShell script and get JSON output
    system_info = run_powershell_script(ps1_path)
    if system_info:
        # Save to JSON file
        save_to_json(system_info, output_path)
        # Print summary to console
        print("\n=== System Information Summary ===")
        print(f"Hostname: {system_info.get('AssetInformation', {}).get('Hostname', 'Unknown')}")
        print(f"Asset Type: {system_info.get('AssetInformation', {}).get('AssetType', 'Unknown')}")
        print(f"Physical Disks: {len(system_info.get('PhysicalDisks', []))}")
        print(f"Network Interfaces: {len(system_info.get('NetworkInterfaces', []))}")
        if system_info.get('BatteryInformation'):
            print(f"Battery State: {system_info.get('BatteryInformation', {}).get('CurrentState', 'Unknown')}")
        print(f"Monitors: {len(system_info.get('MonitorInformation', []))}")

if __name__ == "__main__":
    main()