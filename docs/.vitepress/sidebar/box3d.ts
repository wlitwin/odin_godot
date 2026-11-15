import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Overview",
    "link": "/box3d/"
  },
  {
    "text": "Tutorial",
    "items": [
      {
        "text": "Knock down a tower",
        "link": "/box3d/quickstart"
      }
    ]
  },
  {
    "text": "Guides",
    "items": [
      {
        "text": "Physics ownership",
        "link": "/box3d/ownership"
      },
      {
        "text": "Author a world",
        "link": "/box3d/authoring"
      },
      {
        "text": "Editor and baking",
        "link": "/box3d/editor"
      },
      {
        "text": "Characters and joints",
        "link": "/box3d/motion"
      },
      {
        "text": "Kit and Replay integration",
        "link": "/box3d/multiplayer"
      },
      {
        "text": "Build and export",
        "link": "/box3d/building"
      },
      {
        "text": "Configure capacities",
        "link": "/box3d/capacities"
      }
    ]
  },
  {
    "text": "Reference",
    "items": [
      {
        "text": "API map and limits",
        "link": "/box3d/reference"
      },
      {
        "text": "Platform support",
        "link": "/box3d/support"
      }
    ]
  }
]

export default sidebar
