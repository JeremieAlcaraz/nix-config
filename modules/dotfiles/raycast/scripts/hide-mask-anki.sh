#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title hide mask anki
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.description Script pour masquer Anki lorsqu'il est démarré

#!/bin/bash
osascript -e 'tell application "System Events" to set visible of process "Anki" to false'
