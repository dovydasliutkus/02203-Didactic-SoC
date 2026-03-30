onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider tb_didactic
add wave -noupdate /tb_didactic/clk
add wave -noupdate /tb_didactic/reset
add wave -noupdate /tb_didactic/dut_clk
add wave -noupdate /tb_didactic/dut_reset
add wave -noupdate /tb_didactic/dut_uart_rx
add wave -noupdate /tb_didactic/dut_uart_tx
add wave -noupdate /tb_didactic/dut_spi_csn0
add wave -noupdate /tb_didactic/dut_spi_csn1
add wave -noupdate /tb_didactic/dut_spi_sck
add wave -noupdate /tb_didactic/dut_spi_data0
add wave -noupdate /tb_didactic/dut_spi_data1
add wave -noupdate /tb_didactic/dut_spi_data2
add wave -noupdate /tb_didactic/dut_spi_data3
add wave -noupdate /tb_didactic/dut_gpio_0
add wave -noupdate /tb_didactic/dut_gpio_1
add wave -noupdate /tb_didactic/dut_gpio_2
add wave -noupdate /tb_didactic/dut_gpio_3
add wave -noupdate /tb_didactic/dut_gpio_4
add wave -noupdate /tb_didactic/dut_gpio_5
add wave -noupdate /tb_didactic/dut_gpio_6
add wave -noupdate /tb_didactic/dut_gpio_7
add wave -noupdate /tb_didactic/dut_gpio_8
add wave -noupdate /tb_didactic/dut_gpio_9
add wave -noupdate /tb_didactic/dut_gpio_10
add wave -noupdate /tb_didactic/dut_gpio_11
add wave -noupdate /tb_didactic/dut_gpio_12
add wave -noupdate /tb_didactic/dut_gpio_13
add wave -noupdate /tb_didactic/dut_gpio_14
add wave -noupdate /tb_didactic/dut_gpio_15
add wave -noupdate /tb_didactic/dut_jtag_trstn
add wave -noupdate /tb_didactic/dut_jtag_tck
add wave -noupdate /tb_didactic/dut_jtag_tdi
add wave -noupdate /tb_didactic/dut_jtag_tms
add wave -noupdate /tb_didactic/dut_jtag_tdo
add wave -noupdate /tb_didactic/jtag_trstn
add wave -noupdate /tb_didactic/jtag_tck
add wave -noupdate /tb_didactic/jtag_tdi
add wave -noupdate /tb_didactic/jtag_tms
add wave -noupdate /tb_didactic/jtag_tdo
add wave -noupdate -divider {New Divider}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {7605872916 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 222
configure wave -valuecolwidth 275
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1327200515 ps}
