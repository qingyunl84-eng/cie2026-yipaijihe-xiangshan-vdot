#include <am.h>
#include <klib.h>
#include "identity.h"

int main(const char *args) {
  (void)args;
  printf("hello xiangshan, I am %s, IP address: %s\n", TEAM_ID, HOST_IP);
  return 0;
}
