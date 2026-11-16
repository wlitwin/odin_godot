"""Require every combat fixture edit while accepting Odin formatting changes."""
import re


_TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|`[^`]*`|[A-Za-z_]\w*|[0-9]+|[^\s]')


def _pattern(snippet):
    return re.compile(r'\s*'.join(re.escape(token) for token in _TOKEN.findall(snippet)))


def _replace(source, before, after, expected=1):
    pattern = _pattern(before)
    matches = list(pattern.finditer(source))
    if len(matches) != expected:
        raise ValueError(f'combat fixture expected {expected} occurrence(s) of {before!r}; found {len(matches)}')
    return pattern.sub(lambda _: after, source)


def _replace_block(source, opening, after):
    matches = list(_pattern(opening).finditer(source))
    if len(matches) != 1:
        raise ValueError(f'combat fixture expected one block {opening!r}; found {len(matches)}')
    start = matches[0]
    depth = 1
    # Quoted strings remain one token, so braces in messages are not delimiters.
    for token in _TOKEN.finditer(source, start.end()):
        if token.group() == '{':
            depth += 1
        elif token.group() == '}':
            depth -= 1
            if depth == 0:
                return source[:start.start()] + after + source[token.end():]
    raise ValueError(f'combat fixture block has no closing brace: {opening!r}')


def apply(source, browser=False):
    s = _replace(
        source, 'checked_epoch,diagnostic_at,durable_after:u64,',
        'checked_epoch, diagnostic_at, durable_after: u64,\n'
        '    profile_sent, continued: bool,\n'
        '    cast_due, combat_sample, restored_shots, restored_casts, restored_kills: u64,\n'
        '    peak: u32,',
    )
    s = _replace(s, 'game.initial(dedicated=true,encounter_count=0)', 'combat_initial()')
    if not browser:
        s = _replace(s, '>40000', '>120000')
    elif len(list(_pattern('>120000').finditer(s))) != 1:
        raise ValueError('combat browser fixture lost its extended timeout')
    s = _replace(s, 'rgd.room_frame(&self.room,dt,game.Control{})',
                 'rgd.room_frame(&self.room, dt, combat_input(self))')
    s = _replace_block(s, 'if !self.ready_sent && frame.state.players[seat-1].connected {',
                       'combat_actions(self, &frame.state, seat, epoch)')
    s = _replace(s, 'avatars:=0', 'combat_observe(self, &frame.state, epoch)\n    avatars := 0')
    if not browser:
        s = _replace(
            s, 'self.expected,self.point,self.expected_ready=cp.frame,self.room.prepared.point,true',
            'mem.copy_non_overlapping(&self.expected, &cp.frame, size_of(cp.frame))\n'
            '        self.point, self.expected_ready = self.room.prepared.point, true',
        )
    elif len(list(_pattern('mem.copy_non_overlapping(&self.expected,&cp.frame,size_of(cp.frame))').finditer(s))) != 1:
        raise ValueError('combat browser fixture lost its explicit checkpoint copy')
    return_statement = 'return false' if browser else 'return'
    s = _replace(
        s, 'self.checked_epoch=epoch',
        'if !combat_active(&restored.state) {\n'
        '            fail(self, "checkpoint was not active combat")\n'
        f'            {return_statement}\n'
        '        }\n'
        '        self.restored_shots, self.restored_casts, self.restored_kills, _ = combat_counts(&restored.state)\n'
        '        gd.print_str(fmt.tprintf("DEDICATED_COMBAT_RESTORED epoch=%d tick=%d shots=%d casts=%d kills=%d living=%d projectiles=%d lobs=%d zones=%d", '
        'epoch, restored.tick, self.restored_shots, self.restored_casts, self.restored_kills, '
        'game.living_enemies(&restored.state), restored.state.shots.count, restored.state.lobs.count, restored.state.zones.count))\n'
        '        self.checked_epoch = epoch',
    )
    s = _replace(
        s, '&& self.room.backup_observation.point.archive.tick>=self.durable_after {',
        '&& self.room.backup_observation.point.archive.tick >= self.durable_after '
        '&& self.peak >= 30 && combat_checkpoint(self, self.room.backup_observation.point.archive.tick) {',
    )
    s = _replace(
        s, '&& rgd.room_backup_status(&self.room).phase==.Ready {',
        '&& rgd.room_backup_status(&self.room).phase == .Ready && seen(self, "combat-continued") {',
        expected=2,
    )
    if 'import "core:mem"' not in s:
        s = _replace(s, 'import "core:reflect"', 'import "core:reflect"\nimport "core:mem"')
    return s
