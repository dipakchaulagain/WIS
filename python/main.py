import platform
import socket
import os
import psutil
import wmi
import screeninfo
import subprocess
import math
import json
from datetime import datetime

def get_wmi_object(namespace="root\\cimv2", class_name=None):
    """Helper function to safely query WMI objects."""
    try:
        c = wmi.WMI(namespace=namespace)
        return c.query(f"SELECT * FROM {class_name}")
    except wmi.x_wmi as e:
        print(f"WMI query failed for {class_name} in {namespace}: {str(e)}")
        return []

def get_full_manufacturer_name(code):
    """Map monitor manufacturer codes to full names."""
    manufacturer_map = {
        "DEL": "Dell",
        "SAM": "Samsung",
        "LG ": "LG Electronics",
        "APP": "Apple",
        "ACR": "Acer",
        "HWP": "HP",
        "LEN": "Lenovo",
        "SNY": "Sony",
        "ASU": "Asus",
        "PHL": "Philips",
        "VSC": "ViewSonic",
        "CMN": "Chi Mei Corporation"
    }
    return manufacturer_map.get(code.strip(), code.strip())

def get_asset_type():
    """Determine if the device is a laptop or desktop."""
    chassis = get_wmi_object(class_name="Win32_SystemEnclosure")
    if chassis and chassis[0].ChassisTypes:
        chassis_type = chassis[0].ChassisTypes[0]
        if chassis_type in [8, 9, 10, 14]:
            return "Laptop"
    return "Desktop"

def get_domain_or_workgroup():
    """Determine if the system is part of a domain or workgroup."""
    cs = get_wmi_object(class_name="Win32_ComputerSystem")
    if cs and cs[0].PartOfDomain:
        return cs[0].Domain
    return "WORKGROUP"

# Initialize system info dictionary for JSON export
system_info = {
    "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "asset_information": {},
    "memory_information": {"modules": [], "total_memory_gb": 0},
    "physical_disks": [],
    "logical_drives": [],
    "network_interfaces": [],
    "battery_information": None,
    "monitor_information": []
}

# === Asset Information ===
print("\n=== Asset Information ===\n")

# Hostname
hostname = socket.gethostname()
print(f"Hostname:\t{hostname}")
system_info["asset_information"]["hostname"] = hostname

# Asset type
asset_type = get_asset_type()
print(f"Asset type:\t{asset_type}")
system_info["asset_information"]["asset_type"] = asset_type

# Last user
username = os.environ.get("USERNAME", "Unknown")
userdomain = os.environ.get("USERDOMAIN", "Unknown")
last_user = f"{userdomain}\\{username}"
print(f"Last user:\t{last_user}")
system_info["asset_information"]["last_user"] = last_user

# OS info
os_info = platform.uname()
print(f"OS:\t\t{os_info.system} {os_info.release}")
print(f"Version:\t{os_info.version}")
print(f"Build:\t\t{platform.win32_ver()[2]}")
system_info["asset_information"]["os"] = f"{os_info.system} {os_info.release}"
system_info["asset_information"]["version"] = os_info.version
system_info["asset_information"]["build"] = platform.win32_ver()[2]

# Domain/Workgroup
domain = get_domain_or_workgroup()
print(f"Domain:\t\t{domain}")
system_info["asset_information"]["domain"] = domain

# Manufacturer and Model
cs = get_wmi_object(class_name="Win32_ComputerSystem")
manufacturer = cs[0].Manufacturer if cs else "Unknown"
model = cs[0].Model if cs else "Unknown"
print(f"Manufacturer:\t{manufacturer}")
print(f"Model:\t\t{model}")
system_info["asset_information"]["manufacturer"] = manufacturer
system_info["asset_information"]["model"] = model

# Serial Number
bios = get_wmi_object(class_name="Win32_BIOS")
serial = bios[0].SerialNumber if bios else "Unknown"
print(f"Serial Number:\t{serial}")
system_info["asset_information"]["serial_number"] = serial

# Processor
cpu = get_wmi_object(class_name="Win32_Processor")
if cpu:
    cpu_name = cpu[0].Name
    cores = cpu[0].NumberOfCores
    threads = cpu[0].NumberOfLogicalProcessors
    speed = round(cpu[0].MaxClockSpeed / 1000.0, 2)
    cpu_info = f"{cpu_name} ({cores} cores / {threads} threads @ {speed} GHz)"
    print(f"Processor:\t{cpu_info}")
    system_info["asset_information"]["processor"] = cpu_info
else:
    print("Processor:\tUnknown")
    system_info["asset_information"]["processor"] = "Unknown"

# Motherboard
mb = get_wmi_object(class_name="Win32_BaseBoard")
mb_info = f"{mb[0].Manufacturer} {mb[0].Product}" if mb else "Unknown"
print(f"Motherboard:\t{mb_info}")
system_info["asset_information"]["motherboard"] = mb_info

# Graphics
gpu = get_wmi_object(class_name="Win32_VideoController")
gpu_names = [g.Name for g in gpu] if gpu else ["Unknown"]
print(f"Graphics:\t{', '.join(gpu_names)}")
system_info["asset_information"]["graphics"] = gpu_names

# Audio
audio = get_wmi_object(class_name="Win32_SoundDevice")
audio_names = [a.Name for a in audio] if audio else ["Unknown"]
print(f"Audio:\t\t{', '.join(audio_names)}")
system_info["asset_information"]["audio"] = audio_names

# Antivirus
try:
    result = subprocess.run(["powershell", "-Command", "Get-MpComputerStatus | Select-Object -ExpandProperty AntispywareEnabled"], capture_output=True, text=True)
    av_status = "Enabled" if "True" in result.stdout else "Disabled"
    av_info = f"Windows Defender ({av_status})"
    print(f"Antivirus:\t{av_info}")
    system_info["asset_information"]["antivirus"] = av_info
except:
    print("Antivirus:\tUnknown")
    system_info["asset_information"]["antivirus"] = "Unknown"

# Firewall
try:
    result = subprocess.run(["powershell", "-Command", "Get-NetFirewallProfile | Select-Object Name,Enabled | Format-Table -HideTableHeaders | Out-String"], capture_output=True, text=True)
    firewall_status = ", ".join([line.strip() for line in result.stdout.splitlines() if line.strip()])
    print(f"Firewall:\t{firewall_status}")
    system_info["asset_information"]["firewall"] = firewall_status
except:
    print("Firewall:\tUnknown")
    system_info["asset_information"]["firewall"] = "Unknown"

# === Memory Information ===
print("\n=== Memory Information ===\n")

def get_ram_type(smbios_type):
    """Map SMBIOS memory type to human-readable name."""
    ram_types = {
        20: "DDR",
        21: "DDR2",
        22: "DDR2 FB-DIMM",
        24: "DDR3",
        26: "DDR4",
        27: "LPDDR",
        28: "LPDDR2",
        29: "LPDDR3",
        30: "LPDDR4",
        31: "Logical Non-Volatile Device",
        32: "HBM",
        33: "HBM2",
        34: "DDR5",
        35: "LPDDR5"
    }
    return ram_types.get(smbios_type, f"Unknown ({smbios_type})")

def get_module_type(form_factor):
    """Map memory form factor to human-readable name."""
    module_types = {
        0: "Unknown",
        1: "Other",
        2: "SIP",
        3: "DIP",
        4: "ZIP",
        5: "SOJ",
        6: "Proprietary",
        7: "SIMM",
        8: "DIMM",
        9: "TSOP",
        10: "PGA",
        11: "RIMM",
        12: "SODIMM",
        13: "SRIMM",
        14: "SMD",
        15: "SSMP",
        16: "QFP",
        17: "TQFP",
        18: "SOIC",
        19: "LCC",
        20: "PLCC",
        21: "BGA",
        22: "FPBGA",
        23: "LGA"
    }
    return module_types.get(form_factor, f"Unknown ({form_factor})")

ram_modules = get_wmi_object(class_name="Win32_PhysicalMemory")
if ram_modules:
    print("Capacity (GB)\tSpeed (MHz)\tRAM Type\tModule Type\tManufacturer\tPart Number")
    print("-" * 80)
    total_mem = 0
    for ram in ram_modules:
        try:
            capacity = round(int(ram.Capacity) / (1024 ** 3), 2) if ram.Capacity else 0
            total_mem += capacity
            speed = ram.Speed if ram.Speed else "Unknown"
            ram_type = get_ram_type(ram.SMBIOSMemoryType)
            module_type = get_module_type(ram.FormFactor)
            manufacturer = ram.Manufacturer if ram.Manufacturer else "Unknown"
            part_number = ram.PartNumber.strip() if ram.PartNumber else "Unknown"
            print(f"{capacity:.2f}\t\t{speed}\t\t{ram_type}\t{module_type}\t{manufacturer}\t{part_number}")
            system_info["memory_information"]["modules"].append({
                "capacity_gb": capacity,
                "speed_mhz": speed,
                "ram_type": ram_type,
                "module_type": module_type,
                "manufacturer": manufacturer,
                "part_number": part_number
            })
        except (ValueError, TypeError):
            print("Invalid RAM module data detected. Skipping.")
            continue
    system_info["memory_information"]["total_memory_gb"] = round(total_mem, 2)
    print(f"\nTotal Memory:\t{round(total_mem, 2)} GB")
else:
    print("Memory information not available.")
    system_info["memory_information"]["modules"] = []
    system_info["memory_information"]["total_memory_gb"] = "Unknown"

# === Physical Disks ===
print("\n=== Physical Disks ===\n")

def get_physical_disk_info():
    """Query Get-PhysicalDisk via PowerShell for accurate media and bus types."""
    try:
        result = subprocess.run([
            "powershell", "-Command",
            "Get-PhysicalDisk | Select-Object FriendlyName,MediaType,BusType,Size | ConvertTo-Json"
        ], capture_output=True, text=True)
        disks = json.loads(result.stdout)
        return disks if isinstance(disks, list) else [disks] if disks else []
    except:
        return []

def get_drive_letters(disk_index):
    """Map physical disk to drive letters using WMI."""
    try:
        drive_letters = []
        # Query disk partitions
        partitions = get_wmi_object(class_name="Win32_DiskDriveToDiskPartition")
        for partition in partitions:
            if f"Disk #{disk_index}" in partition.Antecedent:
                # Query logical disks linked to partition
                logical_disks = get_wmi_object(class_name="Win32_LogicalDiskToPartition")
                for logical in logical_disks:
                    if partition.Dependent in logical.Antecedent:
                        # Extract drive letter from logical disk
                        logical_disk = get_wmi_object(class_name="Win32_LogicalDisk")
                        for ld in logical_disk:
                            if ld.DeviceID in logical.Dependent:
                                drive_letters.append(ld.DeviceID[0])
        return ", ".join(drive_letters) if drive_letters else ""
    except:
        return ""

physical_disks = get_physical_disk_info()
if physical_disks:
    print("Model\t\t\tMedia Type\tBus Type\tSize (GB)\tDrive Letters")
    print("-" * 80)
    for index, disk in enumerate(physical_disks):
        model = disk.get("FriendlyName", "Unknown").strip()
        media_type = disk.get("MediaType", "Unknown")
        bus_type = disk.get("BusType", "Unknown")
        size = round(int(disk.get("Size", 0)) / (1024 ** 3), 2)
        drive_letters = get_drive_letters(index)
        print(f"{model[:20]:<20}\t{media_type:<15}\t{bus_type:<10}\t{size:.2f}\t\t{drive_letters}")
        system_info["physical_disks"].append({
            "model": model,
            "media_type": media_type,
            "bus_type": bus_type,
            "size_gb": size,
            "drive_letters": drive_letters
        })
else:
    print("Physical disk information not available.")
    system_info["physical_disks"] = []

# === Logical Drive Usage ===
print("\n=== Logical Drive Usage ===\n")

disks = psutil.disk_partitions()
if disks:
    print("Drive\tLabel\t\tFile System\tTotal (GB)\tUsed (GB)\tFree (GB)\tUsed (%)")
    print("-" * 80)
    for disk in disks:
        if disk.fstype:  # Only include local drives
            usage = psutil.disk_usage(disk.mountpoint)
            drive_letter = disk.mountpoint[0]
            label = disk.opts.split(",")[-1] if disk.opts else "Drive"
            fs = disk.fstype
            total = round(usage.total / (1024 ** 3), 2)
            used = round(usage.used / (1024 ** 3), 2)
            free = round(usage.free / (1024 ** 3), 2)
            percent = round(usage.percent, 2)
            print(f"{drive_letter}\t{label[:12]:<12}\t{fs:<12}\t{total:.2f}\t\t{used:.2f}\t\t{free:.2f}\t\t{percent:.2f}")
            system_info["logical_drives"].append({
                "drive_letter": drive_letter,
                "label": label,
                "file_system": fs,
                "total_gb": total,
                "used_gb": used,
                "free_gb": free,
                "used_percent": percent
            })
else:
    print("Logical drive information not available.")
    system_info["logical_drives"] = []

# === Network Interfaces ===
print("\n=== Network Interfaces ===\n")

def get_vendor_from_mac(mac):
    """Simplified MAC vendor lookup (first three bytes)."""
    if not mac:
        return "Unknown Vendor"
    mac_prefix = mac.replace(":", "").replace("-", "")[:6].upper()
    vendor_list = {
        "00163E": "Intel",
        "00FF41": "Unknown Vendor",
        "00F48D": "Realtek",
        "025041": "Microsoft",
        "8C1645": "Unknown Vendor"
    }
    return vendor_list.get(mac_prefix, "Unknown Vendor")

def get_network_adapters():
    """Query Win32_NetworkAdapter for consistent interface details."""
    adapters = get_wmi_object(class_name="Win32_NetworkAdapter")
    result = []
    for adapter in adapters:
        if adapter.NetConnectionID and adapter.MACAddress:  # Exclude null or loopback adapters
            try:
                # Get IP addresses
                config = get_wmi_object(class_name="Win32_NetworkAdapterConfiguration")
                ipv4 = ""
                ipv6 = ""
                for cfg in config:
                    if cfg.MACAddress == adapter.MACAddress:
                        if cfg.IPAddress:
                            for ip in cfg.IPAddress:
                                if ":" not in ip:
                                    ipv4 = ip
                                else:
                                    ipv6 = ip
                        break
                status = adapter.NetConnectionStatus
                if status == 2:
                    status = "Up"
                elif status == 7:
                    status = "Disconnected"
                elif status == 0:
                    status = "Disabled"
                else:
                    status = "Unknown"
                result.append({
                    "name": adapter.NetConnectionID,
                    "status": status,
                    "ipv4": ipv4,
                    "ipv6": ipv6,
                    "mac": adapter.MACAddress,
                    "vendor": get_vendor_from_mac(adapter.MACAddress)
                })
            except:
                continue
    return result

network_adapters = get_network_adapters()
if network_adapters:
    print("Name\t\t\tStatus\tIPv4\t\t\tIPv6\t\t\tMAC\t\t\tVendor")
    print("-" * 80)
    seen_names = set()
    for adapter in network_adapters:
        name = adapter["name"]
        if name in seen_names:
            continue  # Skip duplicates
        seen_names.add(name)
        print(f"{name[:20]:<20}\t{adapter['status']:<10}\t{adapter['ipv4']:<15}\t{adapter['ipv6'][:20]:<20}\t{adapter['mac']:<17}\t{adapter['vendor']}")
        system_info["network_interfaces"].append({
            "name": name,
            "status": adapter["status"],
            "ipv4": adapter["ipv4"],
            "ipv6": adapter["ipv6"],
            "mac": adapter["mac"],
            "vendor": adapter["vendor"]
        })
else:
    print("Network interface information not available.")
    system_info["network_interfaces"] = []

# === Battery Information (only if Laptop) ===
if asset_type == "Laptop":
    print("\n=== Battery Information ===\n")
    battery = psutil.sensors_battery()
    battery_info = {
        "model": "Unknown",
        "manufacturer": "Unknown",
        "designed_capacity_wh": "Unknown",
        "current_capacity_wh": "Unknown",
        "battery_wear_percent": "Unknown",
        "current_state": "Unknown",
        "eta_to_full_empty": "Unknown"
    }
    if battery:
        percent = battery.percent
        battery_info["current_state"] = "Charging" if battery.power_plugged else "Discharging"
        battery_info["eta_to_full_empty"] = "Calculating..." if battery.secsleft == psutil.POWER_TIME_UNLIMITED else f"{battery.secsleft // 60} minutes"
        battery_info["percent"] = percent
        print(f"Current State:\t\t{battery_info['current_state']}")
        print(f"Percent:\t\t{percent}%")
        print(f"ETA to Full/Empty:\t{battery_info['eta_to_full_empty']}")
    else:
        print("Basic battery information not available via psutil.")

    try:
        # Try BatteryStaticData (root\wmi)
        wmi_battery = get_wmi_object(namespace="root\\wmi", class_name="BatteryStaticData")
        if wmi_battery:
            battery_info["model"] = wmi_battery[0].Name if wmi_battery[0].Name else "Unknown"
            battery_info["manufacturer"] = wmi_battery[0].Manufacturer if wmi_battery[0].Manufacturer else "Unknown"
            battery_info["designed_capacity_wh"] = round(wmi_battery[0].DesignedCapacity / 1000, 2) if wmi_battery[0].DesignedCapacity else "Unknown"
        else:
            # Fallback to Win32_Battery (root\cimv2)
            wmi_battery = get_wmi_object(namespace="root\\cimv2", class_name="Win32_Battery")
            if wmi_battery:
                battery_info["model"] = wmi_battery[0].Name if wmi_battery[0].Name else "Unknown"
                battery_info["manufacturer"] = wmi_battery[0].Manufacturer if wmi_battery[0].Manufacturer else "Unknown"
                battery_info["designed_capacity_wh"] = "Unknown"  # Win32_Battery doesn't provide capacity
        if battery_info["model"] != "Unknown" or battery_info["manufacturer"] != "Unknown":
            print(f"Battery Model:\t\t{battery_info['model']}")
            print(f"Manufacturer:\t\t{battery_info['manufacturer']}")
            print(f"Designed Capacity:\t{battery_info['designed_capacity_wh']} Wh")
            print(f"Current Capacity:\t{battery_info['current_capacity_wh']} Wh")
            print(f"Battery Wear:\t\t{battery_info['battery_wear_percent']} %")
        else:
            print("Detailed battery information not available via WMI.")
    except Exception as e:
        print(f"Detailed battery information not available via WMI: {str(e)}")
    system_info["battery_information"] = battery_info
else:
    system_info["battery_information"] = {}

# === Monitor Information ===
print("\n=== Monitor Information ===\n")

try:
    monitor_ids = get_wmi_object(namespace="root\\wmi", class_name="WmiMonitorID")
except:
    monitor_ids = []
    print("WMI query for monitor information failed.")

try:
    screens = screeninfo.get_monitors()
except:
    screens = []
    print("Screen information not available via screeninfo.")

if monitor_ids and screens:
    monitor_count = len(monitor_ids)
    screen_count = len(screens)
    if monitor_count > 1 and monitor_count != screen_count:
        print(f"Warning: Number of monitors detected via WMI ({monitor_count}) does not match number of screens ({screen_count}). Resolution assignments may be inaccurate.")

    for index, monitor in enumerate(monitor_ids):
        manufacturer_code = "".join(chr(c) for c in monitor.ManufacturerName if c != 0)
        manufacturer = get_full_manufacturer_name(manufacturer_code)
        product_code = "".join(chr(c) for c in monitor.ProductCodeID if c != 0) if monitor.ProductCodeID else "Unknown"
        serial_number = "".join(chr(c) for c in monitor.SerialNumberID if c != 0) if monitor.SerialNumberID else "Unknown"
        friendly_name = "".join(chr(c) for c in monitor.UserFriendlyName if c != 0) if monitor.UserFriendlyName and monitor.UserFriendlyNameLength > 0 else "Unknown"
        year = monitor.YearOfManufacture if monitor.YearOfManufacture else "Unknown"

        diagonal_inch = "Unknown"
        try:
            display_params = get_wmi_object(namespace="root\\wmi", class_name="WmiMonitorBasicDisplayParams")
            for param in display_params:
                if param.InstanceName == monitor.InstanceName:
                    width_cm = param.MaxHorizontalImageSize
                    height_cm = param.MaxVerticalImageSize
                    if width_cm and height_cm:
                        width_inch = round(width_cm / 2.54, 2)
                        height_inch = round(height_cm / 2.54, 2)
                        diagonal_inch = round(math.sqrt(width_inch ** 2 + height_inch ** 2), 2)
                    break
        except:
            pass

        native_res = "Unknown"
        if index < len(screens):
            screen = screens[index]
            native_res = f"{screen.width} x {screen.height}"

        monitor_info = {
            "friendly_name": friendly_name,
            "manufacturer": manufacturer,
            "product_code": product_code,
            "serial_number": serial_number,
            "screen_size_inch": diagonal_inch,
            "native_resolution": native_res,
            "year_of_manufacture": year
        }
        system_info["monitor_information"].append(monitor_info)

        print("=" * 49)
        print(f"Monitor: {friendly_name}")
        print(f"Manufacturer: {manufacturer}")
        print(f"Product Code: {product_code}")
        print(f"Serial Number: {serial_number}")
        print(f"Screen Size: {diagonal_inch} inches")
        print(f"Native Resolution: {native_res}")
        print(f"Year of Manufacture: {year}")
        print("=" * 49)

elif screens:
    print("No monitor information available via WMI. Using fallback method for screen detection.")
    for screen in screens:
        native_res = f"{screen.width} x {screen.height}"
        monitor_info = {
            "friendly_name": "Unknown",
            "manufacturer": "Unknown",
            "product_code": "Unknown",
            "serial_number": "Unknown",
            "screen_size_inch": "Unknown",
            "native_resolution": native_res,
            "year_of_manufacture": "Unknown"
        }
        system_info["monitor_information"].append(monitor_info)
        print("=" * 49)
        print("Monitor: Unknown")
        print("Manufacturer: Unknown")
        print("Product Code: Unknown")
        print("Serial Number: Unknown")
        print("Screen Size: Unknown inches")
        print(f"Native Resolution: {native_res}")
        print("Year of Manufacture: Unknown")
        print("=" * 49)
else:
    print("Unable to retrieve monitor information via WMI or screeninfo. No displays detected.")
    system_info["monitor_information"] = []

# Export to JSON
with open("system_info.json", "w") as f:
    json.dump(system_info, f, indent=4)
print("\nSystem information exported to system_info.json")