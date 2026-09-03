## Software requirements

| # | Tool | Notes |
|---|------|-------|
| 1 | Make | Flow automation |
| 2 | Questa Starter Edition | Simulation |
| 3 | WSL2 | Windows only |
| 4 | `riscv64-unknown-elf` toolchain | Cross-compiler |
| 5 | Bender | Hardware dependency manager (fetches the open-source IP) |
| 6 | Vivado | FPGA synthesis and implementation |
| 7 | Python 3 | For the PC side of the FPGA test. Packages: `pyserial`, `Pillow`, `appJar`, `python3-tk` |
| 8 | OpenOCD (Optional) | JTAG debugging |

## Software setup guide

### 1. Make

`make` drives every build and simulation flow in this project.

**Linux:** Make is typically pre-installed. If not:
```bash
sudo apt install make
```
Verify with `make --version`.

**Windows:** The recommended way is to install the [Chocolatey](https://chocolatey.org)
package manager and then use it to install `make`.

#### Install Chocolatey

1. Open **Windows PowerShell as Administrator**.

2. Allow the install script to run in this session and download it:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```
   This is the official one-liner published at
   <https://chocolatey.org/install>. It installs Chocolatey into
   `C:\ProgramData\chocolatey` and adds it to the system `PATH`.

3. Verify Chocolatey:
   ```powershell
   choco --version
   ```
   The install script refreshes the current session, so this normally works
   right away. If `choco` is not recognised, close the window and open a new
   PowerShell (it will pick up the updated `PATH`).

#### Install Make with Chocolatey

In an **Administrator** PowerShell:
```powershell
choco install make -y
```

Verify installation:
```powershell
make --version
```

### 2. Questa Starter Edition

Questa Starter Edition is a free HDL simulator used in this lab.

#### Download and install

1. Download the installer from the [Altera download center](https://www.altera.com/downloads/simulation-tools/questa-fpgas-standard-edition-software-version-25-1)
   (Linux and Windows builds available).
2. Run the installer and select the **Questa** simulator component. A minimal
   install is <10 GB.
3. Add Questa's `bin` directory (the one containing `vsim`) to your `PATH`:
   - **Windows:** `setx PATH "%PATH%;C:\intelFPGA\25.1\questa_fse\win64"`
     (adjust the path), or use System Properties -> Environment Variables.
   - **Linux:** add `export PATH=$PATH:/opt/intelFPGA/25.1/questa_fse/bin`
     to `~/.bashrc`, then `source ~/.bashrc`.

> **Linux:** Based on distro Questa might have prerequisites for some extra libraries. Try the standard installer first, if it fails find a solution online / LLM.

#### Get a free license

1. Go to the [Self Service Licensing Center](https://www.altera.com/SSLC) and register an account.
2. Choose **Sign up for Evaluation or No-Cost Licenses** and select **Questa FPGA Starter Edition**.
3. Set License Type to **FIXED** and enter your **NIC ID** (MAC address) as the
   Primary Computer ID. Bind it to an adapter that is always present: the
   built-in **Ethernet** port if the machine has one, otherwise **Wi-Fi**. Avoid
   WSL, VPN, and virtual-machine adapters - their MACs change and the license
   stops matching.
   - **Windows:** run `getmac /v /fo list` and read the `Physical Address` of the
     entry whose `Connection Name` is `Ethernet` (or `Wi-Fi`). Alternatively:
     *Settings -> Network & Internet -> <your adapter> -> Hardware properties ->
     Physical address (MAC)*.
   - **Linux:** run `ip link`; the wired interface is `en*` / `eth*`, wireless is
     `wl*`. Use the value after `link/ether`.
4. You will receive a `.dat` license file by email (can take a while).
5. Point Questa at it via the `SALT_LICENSE_FILE` environment variable:
   - **Windows:** `setx SALT_LICENSE_FILE "C:\licenses\questa.dat"` (or use "Edit environment variables" )
   - **Linux:** `export SALT_LICENSE_FILE=$HOME/licenses/questa.dat` in `~/.bashrc`

#### Verify

```bash
vsim -version
```

First time using Questa? Glance over the [Questa Quick-Start Guide](https://docs.altera.com/r/docs/691278/21.3/questa-intel-fpga-edition-quick-start-intel-quartus-prime-pro-edition/questa-intel-fpga-edition-quick-start-intel-quartus-prime-pro-edition).

### 3. WSL2 (Windows only)

WSL2 provides the Linux environment used to run the RISC-V cross-compiler
(Section 4). Skip this section on Linux.

<!-- **Requirements:** Windows 10 21H2+ or Windows 11, administrator rights, and
hardware virtualization enabled in the BIOS/UEFI (Intel VT-x / AMD-V). Most
machines have it on by default. -->

#### Install

1. Open **Windows PowerShell as Administrator** and run:
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
   This enables the WSL and Virtual Machine Platform features, installs the WSL2
   kernel, and downloads Ubuntu 24.04.
2. **Reboot** when prompted.
3. After reboot an Ubuntu terminal opens and asks you to create a UNIX
   username and password (these are separate from your Windows login). If it
   does not open automatically, launch **Ubuntu** from the Start menu.
4. Update the distro:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

#### Verify

In PowerShell:
```powershell
wsl -l -v
```
Ubuntu-24.04 should be listed with `VERSION` `2`. If it shows `1`, run
`wsl --set-version Ubuntu-24.04 2`.

<!-- #### Notes

- Your Windows drives are visible inside WSL under `/mnt/c/`, `/mnt/d/`, etc.,
  so you can work on the project checkout from either side.
- If `wsl --install` reports an outdated kernel, run `wsl --update` and retry.
- If it fails with a virtualization error, enable VT-x / AMD-V (sometimes called
  "SVM Mode" or "Intel Virtualization Technology") in your BIOS/UEFI. -->

Full reference: [official WSL installation guide](https://documentation.ubuntu.com/wsl/stable/#1-overview).

### 4. RISC-V toolchain

The CPU firmware is cross-compiled with the `riscv64-unknown-elf` GCC toolchain
(GCC, binutils, and newlib). Although the prefix says `riscv64`, the project
builds a **32-bit** target (`-march=rv32imc -mabi=ilp32`); the Ubuntu package is
multilib and handles this.

Install it **inside WSL** (or natively on Linux):
```bash
sudo apt install gcc-riscv64-unknown-elf
```

Verify (inside WSL / Linux):
```bash
riscv64-unknown-elf-gcc --version
```

### 5. Bender

Bender is the dependency manager for the SoC's hardware IP - it fetches the open-source modules (CPU core, bus, peripherals) that the RTL build needs.

Install it **inside WSL** (or natively on Linux). On Windows the build invokes Bender through WSL, so it must be installed there, not in native Windows.

Use the official installer (downloads a prebuilt binary):
```bash
sudo apt install curl        # if curl is missing
curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh
```
The installer writes the binary to `./bin/bender` in the current directory. Move it onto your `PATH`:
```bash
sudo mv bin/bender /usr/local/bin/
```

Verify:
```bash
bender --version
```

Project home: <https://github.com/pulp-platform/bender>.

### 6. Vivado

See installation guide on DTU Learn.

<!-- 1. Download the **Vivado ML Edition** installer (Linux `.bin`) from the [AMD downloads page](https://www.xilinx.com/support/download.html). Select the latest 2024.x release and choose *AMD Unified Installer for FPGAs & Adaptive SoCs*.

2. Make the installer executable and run it:
   ```
   chmod +x FPGAs_AdaptiveSoCs_Unified_<version>_Lin64.bin
   sudo ./FPGAs_AdaptiveSoCs_Unified_<version>_Lin64.bin
   ```

3. In the installer GUI, select **Vivado** (not Vitis), then **Vivado ML Standard** (free edition). When choosing devices, selecting only *7 Series* is sufficient for this lab and keeps the download size manageable.

4. After installation, add Vivado to your PATH by sourcing its settings script. Add the following line to your `~/.bashrc`:
   ```
   source /tools/Xilinx/Vivado/<version>/settings64.sh
   ```
   Then reload: `source ~/.bashrc`

5. Verify with `vivado -version`.

> **Note:** The installer requires ~60 GB of disk space for a full install. A 7 Series-only install is roughly 20 GB. -->

### 7. On-hardware debugging OpenOCD and gdb-multiarch (Optional)

OpenOCD bridges GNU Debugger (GDB) and the physical JTAG interface on the FPGA board. Since the bitstream already initialises instruction memory, OpenOCD is not needed for basic testing - it becomes useful if you want to step through code, inspect registers, or reload software without re-programming the FPGA.
 `gdb-multiarch` is the multi-architecture gdb version that supports RISC-V debugging.

**Linux (Ubuntu):**

```bash
sudo apt install gdb-multiarch openocd
```

Verify with `gdb-multiarch --version` and `openocd --version`.

<!-- By default OpenOCD needs `sudo` to access the USB device. To run it as a normal
user, install the udev rules shipped with OpenOCD (or add a rule for the FTDI
`0403:6010`) and re-plug the board:
```bash
sudo cp /usr/share/openocd/contrib/60-openocd.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger -->
```

**Windows:**

#### Step 1 - Install MSYS2

1. Download and run the installer from [msys2.org](https://www.msys2.org)
   (`msys2-x86_64-*.exe`); accept the default install path `C:\msys64`.
2. Open **MSYS2 MINGW64** from the Start menu (the blue icon - *not* "MSYS2 MSYS"
   or "UCRT64"). All commands below run in this shell.
3. Update the package database and core packages:
   ```bash
   pacman -Syu
   ```
   If it asks to close the terminal, do so, reopen **MSYS2 MINGW64**, and run
   `pacman -Syu` again to finish.

#### Step 2 - Install OpenOCD and GDB (inside MSYS2 MINGW64)

```bash
pacman -S mingw-w64-x86_64-openocd mingw-w64-x86_64-riscv64-unknown-elf-gdb
```

Verify:
```bash
openocd --version
riscv64-unknown-elf-gdb --version
```

#### Step 3 - Zadig for switching out the FTDI driver

The Digilent/FTDI chip on the Nexys A7 exposes two interfaces: interface 0 (JTAG)
and interface 1 (UART). Windows binds Digilent's driver to interface 0, which
blocks OpenOCD's libusb access. [Zadig](https://zadig.akeo.ie) swaps only
interface 0 to the generic **WinUSB** driver so OpenOCD can claim it.

Install Zadig, then follow the step-by-step driver-switch procedure in the lab
guide, section *"Program and debug over JTAG"*.

> Switching interface 0 to WinUSB makes the board invisible to the Vivado
> Hardware Manager. The lab guide's JTAG section explains how to restore the
> Digilent driver when you need Vivado's programmer again.
