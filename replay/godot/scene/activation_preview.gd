extends RefCounted
## Render-frame anticipation of a reversible activation (pickup, switch, target).
## One instance per local input stream and session scope. Simulation and score
## remain authoritative. Use the same action sequence as the outgoing control.

class Ticket:
	var sequence: int
	var started_us: int
	var actor: int
	var life: int
	var matched := false

var _pending: Dictionary[int, Ticket] = {}
var _masked: Dictionary[int, Ticket] = {}

func begin(sequence: int, now_us: int, actor := -1, life := 0) -> bool:
	if _pending.has(sequence): return false
	var ticket := Ticket.new()
	ticket.sequence = sequence
	ticket.started_us = now_us
	ticket.actor = actor
	ticket.life = life
	_pending[sequence] = ticket
	if actor >= 0 and life != 0: _masked[actor] = ticket
	return true

func active(actor: int, observed_life: int) -> bool:
	var ticket: Ticket = _masked.get(actor)
	if ticket == null: return false
	if ticket.life == observed_life: return true
	_masked.erase(actor)
	return false

func settle(sequence: int, accepted_actor := -1) -> Ticket:
	var ticket: Ticket = _pending.get(sequence)
	if ticket == null: return null
	_pending.erase(sequence)
	ticket.matched = ticket.actor >= 0 and ticket.life != 0 and ticket.actor == accepted_actor
	# A receipt may precede the observed state change. A matching mask retires
	# on the next life; an older denial cannot release a newer action's mask.
	if not ticket.matched and _masked.get(ticket.actor) == ticket:
		_masked.erase(ticket.actor)
	return ticket

func expire(now_us: int, timeout_us: int) -> Array[Ticket]:
	var expired: Array[Ticket] = []
	for key in _pending.keys():
		if now_us - _pending[key].started_us > timeout_us:
			expired.append(settle(key))
	return expired
