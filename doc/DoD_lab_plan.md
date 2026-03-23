
# Image processing accelerator with CPU Data transport

This laboratory exercise extends the existing image processing accelerator by integrating it into the Didactic-SoC and introducing data transport between the CPU, accelerator, and UART peripheral.

The goal is to expose students to memory-mapped hardware modules, a simple SoC architecture, hardware–software co-design.


## Tasks
### 0.  Test the Didactic-SoC with a Working Example

The Student SubSystem contains a simple pixel inversion accelerator. 

The accelerator consists of an input buffer, an output buffer, a control/status register (CSR) and a processing FSM that performs pixel inversion.

![Student SS with pixel inversion accelerator](../figures/student_ss_bd.drawio.svg)

The CPU controls the accelerator and performs the following steps:


1. Copy image data from **DMEM** to the accelerator **input buffer**.
2. Set the **DATA_READY** bit in the CSR to start processing.
3. Poll the **DONE** bit in the CSR.
4. When processing is complete, copy the processed data from the **output buffer** back into **DMEM** (different location).

The testbench then reads this processed memory region and writes it into a PGM image file.
The generated `.pgm` file can be viewed using software such as **IrfanView** or any image viewer that supports the PGM format.

---

### 1.  Develop the Edge Detection Accelerator

#### Architecture consideration
Before writing any RTL code, you need a design. You need
to understand the problem and consider possible implementations.

...

Draw a block diagram showing the datapath you have designed and develop an ASMD chart specification of your design.

#### RTL design

Using your ASMD chart and block diagram, implement the edge detection accelerator in RTL. Don't write your code in the the full Didactic-SoC yet, as that will make debugging more difficult. Instead use the provided standalone accelerator testbench. 

The testbench will:

1. provide an input image
2. run the simulation
3. write the processed image to a **PGM** file

This allows you to verify the functionality of your accelerator before system integration.


### 2.  Integrate the Accelerator into the SoC

Once your RTL design works correctly with the standalone testbench, integrate the accelerator into the Didactic-SoC.

Use the pixel inversion accelerator from Task 0 as a reference for how the accelerator connects to the system.

You may also need to modify the CPU software to control your new accelerator.

---

### 3.  FPGA Testing

Finally, test the complete system on the FPGA.

Synthesize and implement the design using **Vivado**. If synthesis errors occur, check your RTL code for **unsynthesizable constructs**.

#### FPGA Demonstration Setup

To test the system you will send an image from your computer to the Didactic-SoC and get the processed image back. More precise steps are:

1. A computer sends an image to the FPGA via UART.
2. The CPU stores the received image in DMEM.
3. The CPU transfers the image to the accelerator.
4. The accelerator processes the image.
5. The CPU sends the processed image back to the PC through UART.

#### Provided Code

Example code is available in:
```
fpga/sw
```

The provided code gives two functions: one for reading an image from UART to DMEM and another for writing an image from DMEM to UART.

The variable `pic_start_addr` holds the starting address of the image in memory.

#### Student Task

Extend the provided CPU software so that it:

1. Receives an image from the computer via UART and stores it in DMEM (use the provided function - `UART_read_from_pc()`).
2. Transfers the image data from DMEM to the accelerator input buffer and starts the accelerator.
3. Waits until the accelerator signals that processing is complete.
4. Transfers the processed data from the accelerator output buffer back to DMEM.
5. Sends the processed image back to the computer via UART (use the provided function - `UART_write_to_pc()`).

---


## Notes
* Will it fit on the FPGA? The Didactic-SoC itself takes up 95% of Basys3 LUTs. Nexys4 has 3x more LUTs will have enough space.
* Don't do pixel checking in testbench. Because the students might do different implementations. If they want to check pixels that's fine otherwise we don't care about the most precise result.
* Regarding FPGA implementation the student might ask why we move the data twice: UART to DMEM then DMEM to ACC. In a real case the UART would have a FIFO (we use DMEM instead) once the FIFO fills up we would move data from FIFO to ACC. Same goes the other way we would put the processed image in the FIFO and the UART would then slowly send it out. The curious student could atempt to transfer data from UART straight to the ACC.

# Draft space

0. Give a working blinky example for testing all the tools
0. Implement a bus-connected frame buffer in the Didactic-SoC Student SS. Test with given testbench
2. Integrate frame buffer
Could also do pixel inversion, then have a status register which would indicate to the CPU the state of the peripheral (IDLE, RUNNING, DONE).
2. Verify buffer operation by writing a small C program which would move a frame from DMEM to the new peripheral, wait for it to process, then write back to another part of memory.
3. Develop accelerator (ACC) in isolation (we provide testbench).
4. Integrate accelerator in the SoC. Use the simple design from milestone1 to attach the accelerator to the system.
5. Adjust CPU software - once the image processing is done it writes the result to UART instead of back to memory.
6. Test the full system on an FPGA. Students run their program to process an image stored in memory. The processed output is transmitted via UART and displayed on a PC using a provided application.
7. Design improvement (Advanced tasks)
Improve the system performance and utilization. This could be done by:
* Improve the accelerator. For example to buffer multiple lines instead of the whole frame, then pipeline CPU transfers with accelerator execution:
```
CPU writes new data 
while 
accelerator processes previous data.
```


Extend the provided code so that once a full image has been loaded into DMEM the CPU moves the image into the accelerator and once processing is done call the `UART_write_image(uint32_t pic_start_addr)` function to send the image back to the PC.