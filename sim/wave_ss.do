onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_student_ss/dut/clk_in
add wave -noupdate /tb_student_ss/dut/rst
add wave -noupdate -divider APB
add wave -noupdate /tb_student_ss/dut/PADDR
add wave -noupdate /tb_student_ss/dut/PWRITE
add wave -noupdate /tb_student_ss/dut/ADDR_OBUF_DATA
add wave -noupdate /tb_student_ss/dut/PENABLE
add wave -noupdate /tb_student_ss/dut/PSEL
add wave -noupdate /tb_student_ss/dut/PWDATA
add wave -noupdate /tb_student_ss/dut/PSTRB
add wave -noupdate /tb_student_ss/dut/PRDATA
add wave -noupdate /tb_student_ss/dut/PREADY
add wave -noupdate /tb_student_ss/dut/PSLVERR
add wave -noupdate -divider Internal
add wave -noupdate /tb_student_ss/dut/fsm_state
add wave -noupdate /tb_student_ss/dut/proc_addr
add wave -noupdate /tb_student_ss/dut/proc_addr_d
add wave -noupdate /tb_student_ss/dut/pipe_valid
add wave -noupdate /tb_student_ss/dut/csr_data_ready
add wave -noupdate /tb_student_ss/dut/csr_done
add wave -noupdate /tb_student_ss/dut/csr_busy
add wave -noupdate /tb_student_ss/dut/ibuf_waddr
add wave -noupdate /tb_student_ss/dut/obuf_raddr
add wave -noupdate /tb_student_ss/dut/ibuf_wr_en
add wave -noupdate /tb_student_ss/dut/obuf_wr_en
add wave -noupdate /tb_student_ss/dut/ibuf_wr_addr
add wave -noupdate /tb_student_ss/dut/obuf_wr_addr
add wave -noupdate /tb_student_ss/dut/ibuf_wr_data
add wave -noupdate /tb_student_ss/dut/obuf_wr_data
add wave -noupdate /tb_student_ss/dut/ibuf_rd_en
add wave -noupdate /tb_student_ss/dut/obuf_rd_en
add wave -noupdate /tb_student_ss/dut/ibuf_rd_addr
add wave -noupdate /tb_student_ss/dut/obuf_rd_addr
add wave -noupdate /tb_student_ss/dut/ibuf_rd_data
add wave -noupdate /tb_student_ss/dut/obuf_rd_data
add wave -noupdate /tb_student_ss/dut/pixel_out
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
WaveRestoreCursors {{Cursor 1} {1013905 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 604
configure wave -valuecolwidth 229
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
WaveRestoreZoom {1013634 ns} {1014742 ns}
