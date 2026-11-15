import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Multiplayer learning",
    "link": "/multiplayer/concepts/"
  },
  {
    "text": "Foundations",
    "items": [
      {
        "text": "Authority and ownership",
        "link": "/multiplayer/concepts/authority"
      },
      {
        "text": "State and input",
        "link": "/multiplayer/concepts/state-and-inputs"
      },
      {
        "text": "Ticks and clocks",
        "link": "/multiplayer/concepts/clocks"
      },
      {
        "text": "Prediction and correction",
        "link": "/multiplayer/concepts/prediction"
      },
      {
        "text": "Determinism",
        "link": "/multiplayer/concepts/determinism"
      },
      {
        "text": "Presentation and effects",
        "link": "/multiplayer/concepts/presentation-and-effects"
      }
    ]
  },
  {
    "text": "Feature walkthroughs",
    "items": [
      {
        "text": "Player movement",
        "link": "/multiplayer/recipes/movement"
      },
      {
        "text": "Pickups and inventories",
        "link": "/multiplayer/recipes/pickups-and-inventories"
      },
      {
        "text": "Weapons and damage",
        "link": "/multiplayer/recipes/weapons-and-damage"
      },
      {
        "text": "Spawning and lifetime",
        "link": "/multiplayer/recipes/spawning-and-lifetime"
      },
      {
        "text": "Joining and reconnecting",
        "link": "/multiplayer/recipes/joining-and-reconnecting"
      },
      {
        "text": "Scenes and rounds",
        "link": "/multiplayer/recipes/scenes-and-rounds"
      }
    ],
    "link": "/multiplayer/recipes/"
  },
  {
    "text": "Networks and scale",
    "items": [
      {
        "text": "Connections and compatibility",
        "link": "/multiplayer/concepts/connections-and-compatibility"
      },
      {
        "text": "Bandwidth and relevance",
        "link": "/multiplayer/concepts/bandwidth-and-relevance"
      },
      {
        "text": "Performance and scale",
        "link": "/multiplayer/concepts/performance-and-scale"
      },
      {
        "text": "Testing and debugging",
        "link": "/multiplayer/concepts/testing-and-debugging"
      },
      {
        "text": "Recovery and trust",
        "link": "/multiplayer/concepts/recovery-and-trust"
      }
    ]
  },
  {
    "text": "Choose a framework",
    "items": [
      {
        "text": "Kit or Replay",
        "link": "/multiplayer/"
      },
      {
        "text": "Kit overview",
        "link": "/kit/"
      },
      {
        "text": "Replay overview",
        "link": "/replay/"
      },
      {
        "text": "Physics concepts",
        "link": "/box3d/concepts/"
      }
    ]
  }
]

export default sidebar
