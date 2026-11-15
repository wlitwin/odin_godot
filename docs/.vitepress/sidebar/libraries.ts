import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Overview",
    "link": "/libraries/"
  },
  {
    "text": "Standalone libraries",
    "items": [
      {
        "text": "Typed events",
        "link": "/events"
      },
      {
        "text": "Timed sequences",
        "link": "/libraries/flow"
      },
      {
        "text": "Godot Tween steps",
        "link": "/libraries/flowgd"
      }
    ]
  },
  {
    "text": "Gameplay",
    "items": [
      {
        "text": "Choose gameplay helpers",
        "link": "/libraries/gameplay"
      },
      {
        "text": "Kit components",
        "link": "/kit/play"
      },
      {
        "text": "Items",
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
  }
]

export default sidebar
