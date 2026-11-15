import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Example projects",
    "link": "/examples/"
  },
  {
    "text": "Start small",
    "items": [
      {
        "text": "First Odin scene",
        "link": "/scripting/first-scene"
      },
      {
        "text": "Kit players",
        "link": "/kit/quickstart"
      },
      {
        "text": "Kit prediction",
        "link": "/kit/quickstart-sim"
      },
      {
        "text": "Replay correction",
        "link": "/replay/quickstart"
      },
      {
        "text": "Replay Session",
        "link": "/replay/godot"
      },
      {
        "text": "Box3D tower",
        "link": "/box3d/quickstart"
      },
      {
        "text": "Authored multiplayer physics",
        "link": "/box3d/multiplayer"
      }
    ]
  }
]

export default sidebar
