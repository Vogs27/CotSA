
# Troubleshooting Guide

If the program does not run correctly, please check the following:

---

## ✅ 1. Paths to External Resources

Ensure that **all file paths used in the code are valid** on your system. This includes paths to:

- Drivers  
- Scripts  
- Data files  
- Configuration files  

🛠️ *Tip: If you see errors like `File not found` or `Cannot open file`, it's likely a path issue.*

---

## ✅ 2. Drivers Are Installed

Make sure that all required **MATLAB drivers and toolboxes** are installed. This includes:

- Communications Toolbox (for SDR-related operations)
- RTL-SDR toolbox
- RTL-SDR drivers
- HackRF drivers

---

## ✅ 3. HackRF Interface Folder Is in MATLAB Path

The folder containing the **HackRF MATLAB interface** must be added to the MATLAB path.

You can do this using the following command in MATLAB:

```matlab
addpath(genpath('path_to_hackrf_interface'))
```

Replace `'path_to_hackrf_interface'` with the actual path to the HackRF interface folder on your system.

To make this change permanent, use:

1. **Home > Set Path > Add with Subfolders...**
2. Select the HackRF interface folder.
3. Click **Save**.

---

## ✅ 4. Devices Are Properly Connected

Make sure your hardware is connected:

- **HackRF** or other SDR devices should be properly plugged in via USB.
- Use system tools like `hackrf_info` (Linux/macOS/Windows terminal) or corresponding MATLAB test commands to verify connectivity.
- A similar command is available for the RTL-SDR

---

## ✅ 5. PortaPack is in HackRF Mode

If using **HackRF with PortaPack**, confirm that the device is in **HackRF mode** and not running the PortaPack UI firmware.

📌 *Many PortaPack firmwares boot into a standalone UI mode that disables SDR streaming. You must switch to HackRF mode or boot into compatible firmware that allows MATLAB/SDR communication.*
