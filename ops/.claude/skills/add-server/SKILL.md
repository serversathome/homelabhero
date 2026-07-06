---
name: add-server
description: >
  Register a new server so HomelabHero can manage it, driven entirely from the
  chat/UI with no shell access and no password ever entering the conversation.
  Use this whenever Evan (or a user) asks to add, register, connect, onboard, or
  "hook up" a server, host, machine, NAS, node, or box, or says things like "add
  my truenas", "connect to my proxmox at 10.x.x.x", or "I have another Linux box
  to manage". Trigger it any time someone wants a new machine brought under
  management, even if they do not say the word "register".
---

# Add a server (from the UI, key-only)

This is the safe way to onboard a host through the chat. It never asks for or
handles the target's password. It generates a keypair in the vault (you never
see the private half) and gives back a public key the user installs on the
target themselves.

## Steps

1. Gather three things from the user: a short alias (e.g. `pve1`), the IP or
   hostname, and the platform (`linux`, `truenas`, or `proxmox`). Assume SSH
   port 22 unless they say otherwise. Confirm them back briefly.

2. Register and generate the key:

       hh provision <alias> <host> [port] [platform]

   This prints a confirmation line and a public key between `PUBLIC_KEY_BEGIN`
   and `PUBLIC_KEY_END`.

3. Give the user that public key and tell them to install it on the target's
   root account. Where to paste it, by platform:
   - TrueNAS: web UI -> Credentials -> Users -> root -> Edit -> "Authorized Keys"
     (or SSH keypair) -> paste the key -> Save.
   - Proxmox: add the line to `/root/.ssh/authorized_keys` on the node (via its
     shell or the node's file tools).
   - Linux: append the line to `~/.ssh/authorized_keys` for the login user.

4. Once they confirm it's installed, verify:

       hh test <alias>

   `OK` means it's connected and ready. If it still fails, the key isn't on the
   target yet, or SSH/key auth is disabled there.

5. Show it landed:

       hh list

## Important

- Key-only by design. A password cannot be handled safely through the chat, so
  if the user insists on password auth, that path is the shell-only command
  `hh add-host`, run by an admin on the box. Offer keys first; they are more
  secure and work cleanly on TrueNAS, Proxmox, and Linux.
- You never see or need the private key or any password. Do not ask for one.
- After adding, `hh overview` and `hh inventory` will include the new host.
