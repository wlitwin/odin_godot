/* Test-only bounded local TCP framing. No solver/session policy lives here. */
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <unistd.h>
#define BN_CAP (2u * 1024u * 1024u)
#define BN_PACKET 65536u
#define BN_HEADER 24u
static uint64_t live_socket_bytes;
typedef struct {
  int fd, dead;
  uint64_t sent, received, peak;
  uint32_t tx_size, rx_size;
  uint8_t tx[BN_CAP], rx[BN_CAP];
} bn_socket;
static void put32(uint8_t *p, uint32_t x) {
  for (int i = 0; i < 4; i++)
    p[i] = (uint8_t)(x >> (8 * i));
}
static void put64(uint8_t *p, uint64_t x) {
  for (int i = 0; i < 8; i++)
    p[i] = (uint8_t)(x >> (8 * i));
}
static uint32_t get32(const uint8_t *p) {
  uint32_t x = 0;
  for (int i = 0; i < 4; i++)
    x |= (uint32_t)p[i] << (8 * i);
  return x;
}
static uint64_t get64(const uint8_t *p) {
  uint64_t x = 0;
  for (int i = 0; i < 8; i++)
    x |= (uint64_t)p[i] << (8 * i);
  return x;
}
static int flush(bn_socket *s) {
  while (s->tx_size) {
#ifdef MSG_NOSIGNAL
    ssize_t n = send(s->fd, s->tx, s->tx_size, MSG_NOSIGNAL);
#else
    ssize_t n = send(s->fd, s->tx, s->tx_size, 0);
#endif
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
      return 0;
    if (n <= 0) {
      s->dead = 1;
      return -1;
    }
    s->sent += (uint64_t)n;
    s->tx_size -= (uint32_t)n;
    memmove(s->tx, s->tx + n, s->tx_size);
  }
  return 1;
}
void *bn_open(uint32_t port, uint32_t role, uint64_t generation) {
  bn_socket *s = calloc(1, sizeof(*s));
  if (!s)
    return NULL;
  s->fd = socket(AF_INET, SOCK_STREAM, 0);
  if (s->fd < 0) {
    free(s);
    return NULL;
  }
#ifdef SO_NOSIGPIPE
  int one = 1;
  setsockopt(s->fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (connect(s->fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    close(s->fd);
    free(s);
    return NULL;
  }
  int nodelay = 1;
  setsockopt(s->fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
  uint8_t hello[16] = {0};
  memcpy(hello, "B3NP", 4);
  put32(hello + 4, role);
  put64(hello + 8, generation);
  size_t off = 0;
  while (off < sizeof(hello)) {
    ssize_t n = send(s->fd, hello + off, sizeof(hello) - off, 0);
    if (n <= 0) {
      close(s->fd);
      free(s);
      return NULL;
    }
    off += (size_t)n;
  }
  int flags = fcntl(s->fd, F_GETFL, 0);
  if (flags < 0 || fcntl(s->fd, F_SETFL, flags | O_NONBLOCK) < 0) {
    close(s->fd);
    free(s);
    return NULL;
  }
  live_socket_bytes += sizeof(*s);
  return s;
}
uint64_t bn_owned_bytes(void) { return sizeof(bn_socket); }
int32_t bn_send(void *pointer, uint32_t channel, uint32_t round,
                uint64_t sequence, const uint8_t *bytes, uint32_t count) {
  bn_socket *s = pointer;
  if (!s || s->dead)
    return -1;
  if (channel > 1 || !count || count > BN_PACKET || !bytes)
    return -2;
  if (flush(s) < 0)
    return -1;
  if (count + BN_HEADER > BN_CAP - s->tx_size)
    return 0;
  uint8_t *p = s->tx + s->tx_size;
  memcpy(p, "B3PK", 4);
  put32(p + 4, count);
  put32(p + 8, channel);
  put32(p + 12, round);
  put64(p + 16, sequence);
  memcpy(p + BN_HEADER, bytes, count);
  s->tx_size += BN_HEADER + count;
  uint64_t live = (uint64_t)s->tx_size + s->rx_size;
  if (live > s->peak)
    s->peak = live;
  flush(s);
  return s->dead ? -1 : 1;
}
int32_t bn_poll(void *pointer) {
  bn_socket *s = pointer;
  if (!s || s->dead)
    return -1;
  if (flush(s) < 0)
    return -1;
  while (s->rx_size < BN_CAP) {
    ssize_t n = recv(s->fd, s->rx + s->rx_size, BN_CAP - s->rx_size, 0);
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
      break;
    if (n < 0 && errno == EINTR)
      continue;
    if (n <= 0) {
      s->dead = 1;
      return -1;
    }
    s->received += (uint64_t)n;
    s->rx_size += (uint32_t)n;
    uint64_t live = (uint64_t)s->tx_size + s->rx_size;
    if (live > s->peak)
      s->peak = live;
  }
  return 1;
}
/* 1 packet,0 empty,2 retained-too-small,-1 disconnect,-2 malformed frame. */
int32_t bn_receive(void *pointer, uint32_t *channel, uint64_t *sequence,
                   uint8_t *dst, uint32_t capacity, uint32_t *required) {
  bn_socket *s = pointer;
  if (!s || !channel || !sequence || !required)
    return -2;
  *required = 0;
  if (s->rx_size < BN_HEADER)
    return s->dead ? -1 : 0;
  const uint8_t *p = s->rx;
  if (memcmp(p, "B3PK", 4))
    return -2;
  uint32_t n = get32(p + 4), ch = get32(p + 8);
  if (!n || n > BN_PACKET || ch > 2)
    return -2;
  if (n > s->rx_size - BN_HEADER)
    return s->dead ? -1 : 0;
  *required = n;
  *channel = ch;
  *sequence = get64(p + 16);
  if (n > capacity || !dst)
    return 2;
  memcpy(dst, p + BN_HEADER, n);
  s->rx_size -= BN_HEADER + n;
  memmove(s->rx, s->rx + BN_HEADER + n, s->rx_size);
  return 1;
}
void bn_stats(void *pointer, uint64_t *out) {
  bn_socket *s = pointer;
  if (!s || !out)
    return;
  out[0] = s->sent;
  out[1] = s->received;
  out[2] = s->peak;
  out[3] = s->tx_size;
  out[4] = s->rx_size;
}
void bn_close(void *pointer) {
  bn_socket *s = pointer;
  if (!s)
    return;
  close(s->fd);
  live_socket_bytes -= sizeof(*s);
  free(s);
}
uint64_t bn_live_bytes(void) { return live_socket_bytes; }

uint64_t bn_peak_rss(void) {
  struct rusage r = {0};
  if (getrusage(RUSAGE_SELF, &r))
    return 0;
#ifdef __APPLE__
  return (uint64_t)r.ru_maxrss;
#else
  return (uint64_t)r.ru_maxrss * 1024u;
#endif
}
