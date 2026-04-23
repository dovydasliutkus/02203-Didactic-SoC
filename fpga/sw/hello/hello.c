/*
 * Name: hello
 * Contributor(s):
 *    - Matti Käyrä (matti.kayra@tuni.fi)
 * Description:
 *    - hello world for Didactic SoC
 * Notes:
 *    - compile tb lib with uart receiver define
 */
#include "uart.h"
#include "soc_ctrl.h"

int main() {

  uart_init(8000000u, 38400u);

  while (1) {
    uart_print("hello from didactic!\r\n");
  }
  return 0;
}
