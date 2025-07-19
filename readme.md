
# CotSA – SDR‑Based Automatic RF Component Analyzer

**CotSA** (Commercial‑off‑the‑Shelf Analyzer) is an open‑source MATLAB project that transforms a low‑cost Software‑Defined Radio pair—**HackRF One** for transmission and an **RTL‑SDR (NESDR Smart V5)** for reception—into a flexible RF component analysis platform.

The toolbox automates common RF measurements such as:

- Power‑calibrated spectrograms and sweeps  
- Two‑tone intermodulation (IIP3) tests  
- Digital modulation analysis (e.g. 16‑QAM constellations & eye diagrams)  
- Gain, linearity and power‑transfer curve tracing  

A modular, object‑oriented architecture makes it easy to add new measurements or swap hardware.

---

## Quick Start

1. **Clone** this repository.  
2. Install **MATLAB R2021a (or newer)** with **Communications Toolbox**.  
3. Follow the steps in **DRIVERS** folder to add the SDR drivers and HackRF interface folder to your MATLAB path.  
4. Connect the **HackRF One** (TX) and **RTL‑SDR** (RX) via USB.  
5. Run:

```matlab
run('CotSA/main.m');
```

---

## Trouble? 5‑Point Checklist 🔧

If the program does not run correctly, verify that:

1. **Paths to external resources** in the code are valid (scripts, data, configs).  
2. Required **drivers and toolboxes** are installed.  
3. The **HackRF interface folder is on the MATLAB path**.  
4. **Devices are properly connected** and detected (`hackrf_info`, etc.).  
5. PortaPack (if present) is in **HackRF mode**, **not** standalone UI mode.

See **Software** folder for the full guide.

---

## License

This project is released under the **GNU AFFERO GENERAL PUBLIC LICENSE** – see `LICENSE` for details.

Happy measuring!
