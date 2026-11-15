import type { DefaultTheme } from 'vitepress'

const sidebar: DefaultTheme.SidebarItem[] = [
  {
    "text": "Learning paths",
    "link": "/learn/"
  },
  {
    "text": "Understand the design",
    "items": [
      {
        "text": "Multiplayer concepts",
        "link": "/multiplayer/concepts/"
      },
      {
        "text": "Feature walkthroughs",
        "link": "/multiplayer/recipes/"
      },
      {
        "text": "Physics concepts",
        "link": "/box3d/concepts/"
      }
    ]
  },
  {
    "text": "Build something",
    "items": [
      {
        "text": "Your first scene",
        "link": "/scripting/first-scene"
      },
      {
        "text": "Kit multiplayer",
        "link": "/kit/quickstart"
      },
      {
        "text": "Authority and prediction",
        "link": "/kit/quickstart-sim"
      },
      {
        "text": "Replay correction",
        "link": "/replay/quickstart"
      },
      {
        "text": "Replay in Godot",
        "link": "/replay/godot"
      },
      {
        "text": "Offline physics",
        "link": "/box3d/quickstart"
      },
      {
        "text": "Timed sequences",
        "link": "/libraries/flow"
      }
    ]
  },
  {
    "text": "From GDScript to Odin",
    "items": [
      {
        "text": "Compiled scripts",
        "link": "/onboarding/01-what-if-your-scripts-were-compiled"
      },
      {
        "text": "Script state and objects",
        "link": "/onboarding/02-thinking-in-structs"
      },
      {
        "text": "Replicated state",
        "link": "/onboarding/03-state-not-messages"
      },
      {
        "text": "Commands",
        "link": "/onboarding/04-verbs-not-rpcs"
      },
      {
        "text": "Presentation timing",
        "link": "/onboarding/05-the-two-timelines"
      },
      {
        "text": "Sessions and shipping",
        "link": "/onboarding/06-the-shape-of-a-shippable-game"
      },
      {
        "text": "Competitive simulation",
        "link": "/onboarding/07-the-competitive-turn"
      }
    ]
  },
  {
    "text": "Example projects",
    "link": "/examples/"
  }
]

export default sidebar
