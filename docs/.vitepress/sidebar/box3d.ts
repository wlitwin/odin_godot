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
        "text": "Offline starter",
        "link": "/box3d/quickstart"
      },
      {
        "text": "Procedural tower",
        "link": "/box3d/procedural"
      }
    ]
  },
  {
    "text": "Physics concepts",
    "items": [
      {
        "text": "Reading path",
        "link": "/box3d/concepts/"
      },
      {
        "text": "Bodies and motion",
        "link": "/box3d/concepts/bodies-shapes-and-motion"
      },
      {
        "text": "Collision and queries",
        "link": "/box3d/concepts/collision-and-queries"
      },
      {
        "text": "Simulation and rollback",
        "link": "/box3d/concepts/simulation-and-rollback"
      },
      {
        "text": "Authoring and identity",
        "link": "/box3d/concepts/authoring-and-world-identity"
      },
      {
        "text": "Joints and characters",
        "link": "/box3d/concepts/joints-and-characters"
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
      },
      {
        "text": "Configure timing and history",
        "link": "/box3d/timing"
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
