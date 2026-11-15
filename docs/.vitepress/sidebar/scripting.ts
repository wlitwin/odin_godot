import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Overview",
    "link": "/scripting/"
  },
  {
    "text": "Start here",
    "items": [
      {
        "text": "Your first scene",
        "link": "/scripting/first-scene"
      },
      {
        "text": "Install and configure",
        "link": "/getting-started"
      },
      {
        "text": "Install the addon",
        "link": "/distribution"
      }
    ]
  },
  {
    "text": "Guides",
    "items": [
      {
        "text": "Script state and Godot objects",
        "link": "/onboarding/02-thinking-in-structs"
      },
      {
        "text": "Build and reload",
        "link": "/workflow"
      },
      {
        "text": "Debugging",
        "link": "/debugging"
      },
      {
        "text": "Script modules",
        "link": "/modules"
      },
      {
        "text": "Exporting",
        "link": "/exporting"
      }
    ]
  },
  {
    "text": "Reference",
    "items": [
      {
        "text": "Script authoring API",
        "link": "/authoring-guide"
      }
    ]
  },
  {
    "text": "Next",
    "items": [
      {
        "text": "Choose Kit or Replay",
        "link": "/multiplayer/"
      },
      {
        "text": "Box3D physics",
        "link": "/box3d/"
      },
      {
        "text": "Libraries",
        "link": "/libraries/"
      }
    ]
  }
]

export default sidebar
