# Network APIs

## `Ipv4Addr::from_octets([u8; 4])` — 1.91

## `Ipv6Addr::from_octets([u8; 16])` — 1.91

## `Ipv6Addr::from_segments([u16; 8])` — 1.91

**Construct IP addresses from byte/segment arrays without manual field extraction.**

```rust
// Before
let bytes: [u8; 4] = [192, 168, 1, 1];
let ip = Ipv4Addr::new(bytes[0], bytes[1], bytes[2], bytes[3]);

// After (1.91+)
let ip = Ipv4Addr::from_octets(bytes);
```

Complements the existing `octets()` / `segments()` getters, making IP parsing/serialization a clean round-trip:

```rust
let ip = Ipv4Addr::from_octets(bytes);
let back: [u8; 4] = ip.octets();
assert_eq!(bytes, back);
```

Similarly for IPv6:

```rust
let segs: [u16; 8] = [0x2001, 0x0db8, 0, 0, 0, 0, 0, 0x0001];
let ip = Ipv6Addr::from_segments(segs);

let bytes: [u8; 16] = /* ... */;
let ip = Ipv6Addr::from_octets(bytes);
```

### When to use which for v6

- `from_segments` when parsing textual IPv6 representations or protocols that transmit as 16-bit words.
- `from_octets` when parsing binary protocols (raw socket buffers, pcap, etc.) that give bytes.

## Implicit `From` conversions

Beyond the explicit functions above, the usual `From` conversions also exist:

```rust
let ip: Ipv4Addr = [192, 168, 1, 1].into();       // via From<[u8; 4]>
let ip: Ipv4Addr = 0xC0_A8_01_01u32.into();       // via From<u32>
let ip: Ipv6Addr = [0u16; 8].into();              // via From<[u16; 8]>
let ip: Ipv6Addr = [0u8; 16].into();              // via From<[u8; 16]>
```

`from_octets` / `from_segments` are more explicit about the byte order and layout — useful in code where you want the type of operation to be obvious to readers.

## `SocketAddr::set_ip` / `set_port` (and v4/v6 variants) — const now in 1.87

These setters are now usable in `const` contexts. Lets you build `SocketAddr` values at compile time without the `const fn SocketAddr::new` limitation:

```rust
const BIND: SocketAddr = {
    let mut addr = SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::UNSPECIFIED, 0));
    addr.set_port(8080);
    addr
};
```

## `std::os::linux::net::TcpStreamExt::quickack` / `set_quickack` — 1.89

**Linux-only: control TCP quick-ACK mode per connection.**

```rust
use std::os::linux::net::TcpStreamExt;

let stream = TcpStream::connect(...)?;
stream.set_quickack(true)?;  // send ACKs immediately, no delay
```

Useful for latency-sensitive protocols (RPC, game servers, anything with small request/response pairs where Nagle + delayed ACK causes 40ms hiccups).

Corresponds to `TCP_QUICKACK` socket option. Not available on other platforms.

## Other platform-specific additions

### `UnixStream` `MSG_NOSIGNAL` — 1.90 (compatibility)

On Unix, `UnixStream` writes now set `MSG_NOSIGNAL` automatically. Code that relied on SIGPIPE to terminate on broken pipes needs to handle `ErrorKind::BrokenPipe` on writes instead. Most code gets a small reliability improvement — broken connections no longer kill the process.

## Nothing new for UDP / DNS / TLS

Std's `net` module still does not include:
- DNS resolution beyond `ToSocketAddrs`
- UDP connectionless helpers beyond `UdpSocket`
- Any TLS or QUIC support
- `SO_REUSEPORT` or advanced socket options

For these, keep using `hickory-dns`, `rustls`, `quinn`, `socket2`, etc.
