# Optional shell artwork

`incompris.png` is Alan's original transparent 400 × 134 Incompris wordmark,
restored unchanged for the explicitly enabled shell dashboard. The repository's
governed Mantle Brand Kit remains under `assets/identity/`.

- Original commit: `a71bb0c03bbf2bd9a7e43141266efc003711496d`
- Original path: `assets/presentation/mantle-banner.png`
- Original Git blob: `5f33e822304247c7581f4920d2fec952ae1cbfa0`
- SHA-256: `ed15d8fe05cf62691571130c19e21b2ba35f1da193628f34a68cd0da835aff80`

`incompris.txt` is a new plain-text fallback, rather than a recovered ANSI logo.
Startup selects the PNG for recognized iTerm/Kitty image protocols and uses the
text fallback elsewhere. A user-supplied Fastfetch configuration retains its own
logo unless `MANTLE_FASTFETCH_LOGO` explicitly overrides it.
