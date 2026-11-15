import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Overview",
    "link": "/kit/"
  },
  {
    "text": "Learning background",
    "items": [
      {
        "text": "Multiplayer concepts",
        "link": "/multiplayer/concepts/"
      },
      {
        "text": "Feature walkthroughs",
        "link": "/multiplayer/recipes/"
      }
    ]
  },
  {
    "text": "Tutorials",
    "items": [
      {
        "text": "Two moving players",
        "link": "/kit/quickstart"
      },
      {
        "text": "Authority and prediction",
        "link": "/kit/quickstart-sim"
      },
      {
        "text": "Build a multiplayer game",
        "link": "/kit/build-a-game-in-a-day"
      }
    ]
  },
  {
    "text": "Concepts",
    "items": [
      {
        "text": "Timeline models",
        "link": "/kit/timelines"
      },
      {
        "text": "Network profiles",
        "link": "/kit/profiles"
      },
      {
        "text": "Glossary",
        "link": "/kit/glossary"
      }
    ]
  },
  {
    "text": "Sessions and replication",
    "items": [
      {
        "text": "Game lifecycle",
        "link": "/kit/boot"
      },
      {
        "text": "Sessions",
        "link": "/kit/session"
      },
      {
        "text": "Fields and commands",
        "link": "/kit/net"
      },
      {
        "text": "Fixed-tick simulation",
        "link": "/kit/sim"
      },
      {
        "text": "Godot transports",
        "link": "/kit/netgd"
      },
      {
        "text": "Steam transport",
        "link": "/kit/steamgd"
      },
      {
        "text": "Saves",
        "link": "/kit/save"
      },
      {
        "text": "Chat and pings",
        "link": "/kit/comms"
      },
      {
        "text": "Large transfers",
        "link": "/kit/xfer"
      }
    ]
  },
  {
    "text": "Gameplay libraries",
    "items": [
      {
        "text": "Embedded components",
        "link": "/kit/play"
      },
      {
        "text": "Items and inventory",
        "link": "/kit/items"
      },
      {
        "text": "Combat",
        "link": "/kit/combat"
      },
      {
        "text": "Interactions",
        "link": "/kit/interact"
      },
      {
        "text": "AI",
        "link": "/kit/ai"
      },
      {
        "text": "Navigation",
        "link": "/kit/nav"
      },
      {
        "text": "UI",
        "link": "/kit/ui"
      },
      {
        "text": "Effects",
        "link": "/kit/fx"
      }
    ]
  },
  {
    "text": "Physics and testing",
    "items": [
      {
        "text": "Box3D integration",
        "link": "/box3d/multiplayer"
      },
      {
        "text": "Complete physics state",
        "link": "/kit/box3d"
      },
      {
        "text": "Physics networking",
        "link": "/kit/box3d-networking"
      },
      {
        "text": "Multiplayer tests",
        "link": "/kit/testing"
      },
      {
        "text": "Contributor conventions",
        "link": "/kit/conventions"
      }
    ]
  }
]

export default sidebar
