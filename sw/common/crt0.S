/*
 * Project: Edu4chip
 * Description: 
 *   - crt0 ("c runtime zero") file
 *   - program run specifics outside main function
 * Contributors:
 *   - Antti Nurmi (antti.nurmi@tuni.fi)
 *   - Matti Käyrä (matti.kayra@tuni.fi)
 * Notes:
 *   - Minimimal implementation, no irq support
 */

  .section .text

reset_handler:
  la x2, stack

  # copy .data and .sdata from IMEM image to DMEM
  la t0, _sidata
  la t1, _sdata
  la t2, _esdata
1:
  beq  t1, t2, 2f
  lw   t3, 0(t0)
  sw   t3, 0(t1)
  addi t0, t0, 4
  addi t1, t1, 4
  j    1b
2:
  # zero .bss
  la t0, _sbss
  la t1, _ebss
3:
  beq  t0, t1, 4f
  sw   zero, 0(t0)
  addi t0, t0, 4
  j    3b
4:
  la ra, postMain
  j main

/* Didactic specific return code pass over through jtag */
  .global postMain
postMain:
  li t0, 0x01020380
  li t1, 0x80000000
  or a0, a0, t1
  sw a0, 0(t0)

  .global changeStack
changeStack:
  mv sp, a2
  jr a1

  .section .vectors, "ax"
  .option norvc;
  .org 0x0
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler
  jal x0, default_handler

  //// reset vector
  .org 0x80
  jal x0, reset_handler

  .org 0x84
loop:
  j loop

default_handler:
  mret
