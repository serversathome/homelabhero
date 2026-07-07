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

1. Gather from the user: a short alias (e.g. `pve1`), the IP or hostname, the
   platform (`linux`, `truenas`, or `proxmox`), and the SSH login user. Assume
   SSH port 22 unless they say otherwise. Confirm them back briefly.

   Pick the right connect user - this matters, get it wrong and the key auth
   fails even though the key is installed:
   - TrueNAS: `truenas_admin` (modern TrueNAS disables root SSH). This is the
     default provision uses for truenas, so you can omit it.
   - Proxmox: `root`.
   - Linux: whatever admin/login user the box uses (often `root`; ask).

2. Register and generate the key. Pass the user as the fifth argument (or as
   `user@host`) unless the platform default is correct:

       hh provision <alias> <host> [port] [platform] [user]

   Examples:

       hh provision pve1 10.0.0.10 22 proxmox            # connects as root
       hh provision nas1 10.0.0.20 22 truenas            # defaults to truenas_admin
       hh provision box1 10.0.0.30 22 linux deploy       # connects as deploy

   This prints a confirmation line (which states the user it registered) and a
   public key between `PUBLIC_KEY_BEGIN` and `PUBLIC_KEY_END`. Read that line
   back to the user so they install the key on the right account.

3. Give the user that public key and tell them to install it on the target
   account **that provision registered** (shown in the confirmation line), not
   necessarily root. Where to paste it, by platform:
   - TrueNAS: web UI -> Credentials -> Users -> `truenas_admin` -> Edit ->
     "Authorized Keys" (or SSH keypair) -> paste the key -> Save.
   - Proxmox: add the line to `/root/.ssh/authorized_keys` on the node (via its
     shell or the node's file tools).
   - Linux: append the line to `~/.ssh/authorized_keys` for that login user.

4. Once they confirm it's installed, verify:

       hh test <alias>

   `OK` means it's connected and ready. If it still fails, the key isn't on the
   target yet, or SSH/key auth is disabled there.

5. Grant passwordless sudo (skip if the connect user is root). HomelabHero is a
   full controller, so a non-root connect user needs passwordless sudo or
   privileged commands (docker, smartctl, zpool, apt...) fail. Confirm this is
   what the user wants (it gives the agent full root on that host), then:

   - TrueNAS (`truenas_admin`): the middleware works without sudo, so you can do
     it directly. Find the user id and grant it:

         hh run <alias> "midclt call user.query '[[\"username\",\"=\",\"truenas_admin\"]]' | python3 -c 'import json,sys;print(json.load(sys.stdin)[0][\"id\"])'"
         hh run <alias> "midclt call user.update <id> '{\"sudo_commands_nopasswd\": [\"ALL\"], \"sudo_commands\": []}'"

     (Or in the UI: Credentials -> Users -> truenas_admin -> Edit -> "Allow all
     sudo commands with no password".)
   - Linux / non-root Proxmox: this needs root once, so the broker cannot do it.
     Ask the operator to run, from a root/admin shell on that box:

         echo '<user> ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/homelabhero-<user> && sudo chmod 440 /etc/sudoers.d/homelabhero-<user>

6. Show it landed and confirm the privilege is in place:

       hh list
       hh doctor        # should report "<alias> (<user>, passwordless sudo OK)"

## Important

- Key-only by design. A password cannot be handled safely through the chat, so
  if the user insists on password auth, that path is the shell-only command
  `hh add-host`, run by an admin on the box. Offer keys first; they are more
  secure and work cleanly on TrueNAS, Proxmox, and Linux.
- You never see or need the private key or any password. Do not ask for one.
- Wrong connect user? `hh test` will fail even with the key installed, because
  the broker logs in as the registered user. Provision refuses to overwrite an
  existing alias, so to change the user ask the operator to run
  `hh rm-host <alias>` from an admin shell, then re-provision with the correct
  user. (rm-host needs sudo and cannot be run from the chat.)
- After adding, `hh overview` and `hh inventory` will include the new host.
