# Always-adjustable region

- Restore a valid saved region on launch, otherwise center a default region on the selected display.
- Replace modal selection with a persistent click-through outline and five small interactive panels: four corner handles and a move handle. Keep handles within the display at its edges.
- Save changes after each drag. Support aspect-ratio changes before and during capture.
- Start Capture opens the preview and marks the outline as live. Stop Capture closes the preview and leaves the editable region visible.
- Serialize stream configuration updates and coalesce drag changes to the latest region. Update the preview's aspect ratio without replacing its window. Disable edits briefly during start/stop.
- Keep display switching disabled during capture. Display configuration changes stop capture and restore a valid region.
- Update usage docs, run geometry tests and build the app. Inspect runtime behavior where permissions and UI tools allow.

## Result

Implemented. The arm64 Debug build and all 10 geometry tests pass. The local app launches with the new controls and saved region dimensions. Capture startup reports missing Screen Recording permission. Manual checks remain for handle dragging, click-through, and live capture updates.
