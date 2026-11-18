extends Node
signal ping(value: int)
signal lobby_created(result: int, lobby: int)
signal lobby_joined(lobby: int, perms: int, locked: bool, response: int)
signal join_requested(lobby: int, friend: int)
