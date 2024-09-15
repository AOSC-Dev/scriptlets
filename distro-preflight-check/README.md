revoke-leaked-keys.bash
===

Detect and collect leaked SSH host keys in AOSC OS system media.

Usage
---

On the AOSC repository server:

```
sudo bash revoke-leaked-keys.bash
```

The collected keys will be found in `${PWD}/revoked`, prefixed by the image
filename from which they were found.
