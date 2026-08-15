# homePC Maintenance Notes

## Front-panel audio

The Realtek ALC892 front-panel headphone output is functional, but ALSA jack
detection reports it as unplugged. WirePlumber therefore marks the normal
analog profiles unavailable and otherwise routes application audio to the
NVIDIA HDMI sink.

- Keep the homePC-specific WirePlumber rule in `configuration.nix` that forces
  `alsa_card.pci-0000_2b_00.3` to use the analog stereo profile.
- Do not move this hardware workaround into shared workstation modules or
  profiles.
- Do not remove the rule merely to restore automatic audio routing. First prove
  on homePC that the front-panel jack is detected as available and that both a
  browser stream and a 32-bit Steam/Proton stream reach the analog sink.
- Preserve HDMI as an alternative output unless the user explicitly requests
  that it be disabled.
