# Controller support design notes

First implementation: SDL2 input, optional at build time, with position-based focus. Navigation
and value adjusting were confirmed by hand on a BigBen pad, which is not a genuine PS4 controller. Steam Deck and
other handheld acceptance checks come later, as agreed in the [development plan](development-plan.md).

Prismarine moves focus by position on screen, so pages and dialogs do not describe their own
navigation order. New controls work as long as they can take focus. A private test fails when a
left-clickable item on the checked pages has no focusable control.

## Buttons

| Button | Action |
| --- | --- |
| D-pad, left stick | Move focus. The first press only shows where focus is. The newest direction wins on a diagonal. |
| Bottom (A, Cross) | Select. On a value control, start or accept adjusting. |
| Right (B, Circle) | Close a dialog or go back. While adjusting, cancel. |
| Top (Y, Triangle) | Open the selected instance. |
| Left (X, Square) | Open the focused item's menu. |
| Start, Options | Play the selected instance. |
| Shoulder buttons | Previous or next page. |
| Right stick | Scroll. |

Sliders, number boxes and the colour square keep their value as focus passes over them. Page
buttons do nothing while a dialog or menu is open. Removing a skin asks first, because a stray
press should not delete a file.

## Input integration

`GamepadInput` reads the first controller through SDL while Prismarine is the active
application, and polls once a second otherwise to notice a controller being plugged in.
`GamepadState` turns input into actions without touching SDL. `GamepadNavigator` sends direction
keys straight to the focused control, then falls back to `SpatialFocus`, which picks the next
control by position inside the top open dialog or page. A control that changes value on up and
down is passed through without changing. Duplicate input from Steam Input is not handled yet.
Release builds set `PRISMARINE_REQUIRE_CONTROLLER`, so they fail rather than ship without SDL2.

## Still to do

- On-screen keyboard, because text fields need a physical keyboard today.
- On-screen button prompts.
- Handling duplicate input from Steam Input.

## Acceptance checks

Checked by hand on a BigBen pad, which reports as PS4-type: navigation, value adjusting, menus
and the account switcher.

Not checked yet: a genuine PS4 controller, disconnect and reconnect, returning from a running
Minecraft, Windows and macOS. On handheld hardware, also check readability, suspend and resume.
