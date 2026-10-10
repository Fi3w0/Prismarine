# Future updates

## Controller support for Steam Deck and other handhelds

Add basic controller navigation to the existing UI without adding buttons,
changing the layout, or redesigning pages. This is planned work, not implemented
support.

- D-pad or left stick: move focus between controls and library items.
- A / primary action: activate the focused control.
- B / secondary action: go back or close the active dialog.
- Shoulder buttons: switch tabs.
- Right stick: scroll.

Reuse existing keyboard navigation and focus highlights. Make focus movement
consistent across pages, keep focused items visible, and restore focus when
dialogs close. Support text entry through an on-screen keyboard on handhelds.

Consider Steam Input keyboard/mouse mappings for an initial Steam Deck setup,
and SDL gamepad input for native controller support across systems. Avoid double
input when Steam Input is active, handle controller disconnects, and process
controller navigation only while Prismarine is focused so it does not interfere
with Minecraft after launch.

Verify the main flows on an actual handheld: selecting and launching an instance,
browsing content, navigating settings, opening and closing dialogs, and searching.
Keep keyboard, mouse and touch interactions working alongside controller input.
