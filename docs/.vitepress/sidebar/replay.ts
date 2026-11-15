import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Overview",
    "link": "/replay/"
  },
  {
    "text": "Tutorials",
    "items": [
      {
        "text": "Correct an inventory transfer",
        "link": "/replay/quickstart"
      },
      {
        "text": "Connect a Godot session",
        "link": "/replay/godot"
      }
    ]
  },
  {
    "text": "Guides and concepts",
    "items": [
      {
        "text": "World and history",
        "link": "/replay/architecture"
      },
      {
        "text": "Networking",
        "link": "/replay/networking"
      },
      {
        "text": "Presentation",
        "link": "/replay/presentation"
      },
      {
        "text": "Owner streams",
        "link": "/replay/owner-streams"
      },
      {
        "text": "Recovery",
        "link": "/replay/recovery"
      },
      {
        "text": "Box3D integration",
        "link": "/box3d/multiplayer"
      }
    ]
  },
  {
    "text": "Reference",
    "items": [
      {
        "text": "Support and compatibility",
        "link": "/replay/support"
      },
      {
        "text": "Physics networking",
        "link": "/replay/box3d-networking"
      }
    ]
  }
]

export default sidebar
