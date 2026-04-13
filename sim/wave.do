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
add wave -noupdate /tb_didactic/dut_jtag_tck
add wave -noupdate /tb_didactic/dut_jtag_tdi
add wave -noupdate /tb_didactic/dut_jtag_tms
add wave -noupdate /tb_didactic/dut_jtag_tdo
add wave -noupdate /tb_didactic/dut_gpio
add wave -noupdate /tb_didactic/i
add wave -noupdate -divider {Ibex Core signals}
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/u_ibex_core/pc_if
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/u_ibex_core/if_stage_i/instr_valid_id_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/u_ibex_core/if_stage_i/instr_rdata_id_o
add wave -noupdate -divider {Ibex IMEM IF}
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_req_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_gnt_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_rvalid_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_addr_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_rdata_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_rdata_intg_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/instr_err_i
add wave -noupdate -divider {Ibex DMEM IF}
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_req_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_gnt_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_rvalid_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_we_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_be_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_addr_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_wdata_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_wdata_intg_o
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_rdata_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_rdata_intg_i
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/i_ibex_wrapper/Ibex_Core/u_ibex_top/data_err_i
add wave -noupdate -divider UART
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/iSIN
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/iSINr
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/SIN
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/iLSR_DR
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/iRXFIFOWrite
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/CLK
add wave -noupdate /tb_didactic/i_didactic/SystemControl_SS/SysCtrl_SS/apb_uart/RSTN
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -divider Student_area_0
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PADDR
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PENABLE
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PSEL
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PWDATA
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PWRITE
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PSTRB
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PRDATA
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PREADY
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/PSLVERR
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/irq
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/clk_ctrl
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/irq_en
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/clk_in
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/high_speed_clk
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/rst
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/pmod_gpi
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/pmod_gpo
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/pmod_gpio_oe
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/csr_data_ready
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/csr_done
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/csr_busy
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/ibuf_waddr
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/obuf_raddr
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/fsm_state
add wave -noupdate /tb_didactic/i_didactic/Student_SS_0/Student_area_0/proc_addr
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {46023902 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 604
configure wave -valuecolwidth 178
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
WaveRestoreZoom {0 ps} {294051 ps}
