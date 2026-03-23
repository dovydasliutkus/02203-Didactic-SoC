openocd -f nexys-probe.cfg \
  -c "init" \
  -c "irscan xc7.tap 0x22" \
  -c "set val [drscan xc7.tap 32 0x00000000]" \
  -c "echo \"USER3: \$val\"" \
  -c "shutdown"