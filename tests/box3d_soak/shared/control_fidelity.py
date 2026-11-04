"""Read-only diagnostics for saved controller observations; never acceptance."""
from __future__ import annotations

import hashlib
import json
from contextlib import closing
from pathlib import Path
import sqlite3


ORIGINS = {"kit": {1: "Submitted", 2: "Held", 3: "Authority"},
           "replay": {x: x for x in ("Neutral", "Sample", "Held", "Local")}}
KINDS = {1: "Spawn", 2: "Remove", 3: "Motor", 4: "Sleep", 5: "Wake", 6: "Query"}


def _integer(value, low=0, high=2**64-1):
    return type(value) is int and low <= value <= high


def _object(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    def constant(_):
        raise ValueError("nonfinite JSON number")

    value = json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)
    if not isinstance(value, dict):
        raise ValueError("body is not an object")
    return value


def _need(condition, message):
    if not condition:
        raise ValueError(message)


def _players(db, role, epoch):
    """Use actual READY mapping only; conflicting or absent mappings are unknown."""
    found, invalid = None, False
    for raw, in db.execute("SELECT body FROM events WHERE role=? AND kind='READY' ORDER BY id", (role,)):
        try:
            row = _object(raw)
            _need(_integer(row.get("epoch"), 1), "READY epoch unavailable")
            if row.get("epoch") != epoch:
                continue
            value = row.get("players")
            _need(isinstance(value, list) and len(value) == 2 and
                  all(_integer(x, 1) for x in value) and value[0] != value[1], "READY players unavailable")
            value = tuple(value)
            if found is not None and found != value:
                invalid = True
            found = value
        except (ValueError, TypeError):
            invalid = True
    return None if invalid else found


def _control(row, framework, players):
    _need(_integer(row.get("epoch"), 1) and _integer(row.get("tick")) and
          _integer(row.get("seat"), 1, 2), "control identity unavailable")
    _need(all(_integer(row.get(k), -32768, 32767) for k in ("x", "z")), "control axes not signed i16")
    origin = row.get("origin")
    if framework == "kit":
        _need(type(origin) is int and origin in ORIGINS[framework], "Kit origin unavailable")
        _need(type(row.get("class")) is int and row["class"] == 0 and row.get("accepted") is True and
              type(row.get("status")) is int and row["status"] == 0, "Kit control is not an actual accepted observation")
        _need("available" not in row and "unavailable" not in row, "unavailable control observation")
        _need(_integer(row.get("sequence")), "Kit source sequence unavailable")
        _need(players is not None and _integer(row.get("player"), 1) and
              row["player"] == players[row["seat"]-1], "Kit READY/player mapping unavailable")
    else:
        _need(type(origin) is str and origin in ORIGINS[framework], "Replay origin unavailable")
        _need(all(_integer(row.get(k)) for k in ("generation", "serial", "incarnation")),
              "Replay driver binding unavailable")
    return ORIGINS[framework][origin]


class _Controls:
    def __init__(self, role, seat, first, last, remote, limit):
        self.first, self.last, self.limit, self.remote = first, last, limit, remote
        self.value = dict(role=role, seat=seat, valid_unique_controls=0, malformed_controls=0,
                          duplicate_controls=0, outside_window=0, origin_counts={},
                          submitted_or_sample_count=0, held_count=0, nonzero_count=0,
                          held_zero_count=0, runs={}, run_samples=[], nonzero_samples=[])
        self.previous = None
        self.run = None
        self.zero_run = None

    def _end_run(self):
        if self.run is None:
            return
        origin, start, end = self.run
        item = self.value["runs"].setdefault(origin, dict(count=0, longest_ticks=0))
        item["count"] += 1
        item["longest_ticks"] = max(item["longest_ticks"], end-start+1)
        if len(self.value["run_samples"]) < self.limit:
            self.value["run_samples"].append(dict(origin=origin, first_tick=start, last_tick=end))
        self.run = None

    def _end_zero(self):
        if self.zero_run is not None:
            item = self.value["runs"].setdefault("HeldZero", dict(count=0, longest_ticks=0))
            item["count"] += 1
            item["longest_ticks"] = max(item["longest_ticks"], self.zero_run[1]-self.zero_run[0]+1)
            self.zero_run = None

    def add(self, event_id, row, origin):
        tick = row["tick"]
        if not self.first <= tick <= self.last:
            self.value["outside_window"] += 1
            return
        if self.previous is not None and tick <= self.previous:
            self.value["duplicate_controls"] += 1
            self._end_run()
            self._end_zero()
            return
        nonzero = row["x"] != 0 or row["z"] != 0
        held_zero = origin == "Held" and not nonzero
        if self.run is not None and (tick != self.run[2]+1 or origin != self.run[0]):
            self._end_run()
        self.run = (origin, tick if self.run is None else self.run[1], tick)
        if self.zero_run is not None and (not held_zero or tick != self.zero_run[1]+1):
            self._end_zero()
        if held_zero:
            self.zero_run = (tick if self.zero_run is None else self.zero_run[0], tick)
        self.previous = tick
        v = self.value
        v["valid_unique_controls"] += 1
        v["origin_counts"][origin] = v["origin_counts"].get(origin, 0)+1
        v["submitted_or_sample_count"] += int(origin in ("Submitted", "Sample"))
        v["held_count"] += int(origin == "Held")
        v["nonzero_count"] += int(nonzero)
        v["held_zero_count"] += int(held_zero)
        if nonzero and len(v["nonzero_samples"]) < self.limit:
            v["nonzero_samples"].append(dict(event_id=event_id, tick=tick, x=row["x"], z=row["z"], origin=origin))

    def finish(self, unattributed=False):
        self._end_run()
        self._end_zero()
        v = self.value
        v["required_ticks_in_declared_window"] = self.last-self.first+1
        v["missing_ticks"] = v["required_ticks_in_declared_window"]-v["valid_unique_controls"]
        complete = not unattributed and v["missing_ticks"] == v["malformed_controls"] == v["duplicate_controls"] == 0
        v["coverage"] = "COMPLETE_OBSERVATIONS" if complete else "UNAVAILABLE"
        v["fidelity_flag"] = None
        if v["seat"] == self.remote and v["valid_unique_controls"] > 0 and v["held_zero_count"] == v["valid_unique_controls"]:
            v["fidelity_flag"] = ("DEGENERATE_FULL_HELD_ZERO" if complete else
                                  "HELD_ZERO_ONLY_OBSERVED_COVERAGE_UNAVAILABLE")
        v["detail_samples_truncated"] = (sum(x["count"] for k, x in v["runs"].items() if k != "HeldZero") > len(v["run_samples"]) or
                                            v["nonzero_count"] > len(v["nonzero_samples"]))
        return v


def _action(row, framework, outcome=False):
    _need(_integer(row.get("epoch"), 1) and _integer(row.get("seat"), 1, 2) and
          _integer(row.get("sequence"), 1), "action identity unavailable")
    kind = row.get("kind")
    if framework == "kit" and type(kind) is int:
        kind = KINDS.get(kind)
    _need(type(kind) is str and kind in KINDS.values(), "action kind unavailable")
    if framework == "replay":
        _need(_integer(row.get("generation"), 1) and _integer(row.get("serial"), 1),
              "Replay action generation/serial unavailable")
        _need("incarnation" not in row or _integer(row["incarnation"]), "Replay incarnation malformed")
    if outcome:
        _need(type(row.get("applied")) is bool and row.get("accepted") is True and
              _integer(row.get("tick")), "published action outcome unavailable")
    else:
        _need(_integer(row.get("submitted_tick")), "actual submitted tick unavailable")
    return kind


def _correlate(db, framework, epoch, first, last, limit):
    result = dict(client_issues=0, matched_published_decisions=0, missing_published_counterpart=0,
                  ambiguous_counterpart=0, unavailable=0, kind_mismatch=0,
                  applied_true=0, applied_false=0, reason_unavailable=0,
                  published_scope_differs=0, scope_metadata_unavailable=0,
                  execution_tick_differs_from_submitted=0, actual_action_timing={},
                  samples={}, observations_by_status={})
    query = "SELECT id,body FROM events WHERE role='host' AND kind='APPLIED' AND epoch=? AND seat=? AND sequence=? ORDER BY id"
    for event_id, raw in db.execute("SELECT id,body FROM events WHERE role='client' AND kind IN ('ISSUED','SUBMITTED') ORDER BY id"):
        detail = dict(issue_event_id=event_id)
        try:
            issue = _object(raw)
            _need(_integer(issue.get("epoch"), 1), "issue epoch unavailable")
            if issue.get("epoch") != epoch:
                continue
            kind = _action(issue, framework)
            if not first <= issue["submitted_tick"] <= last:
                continue
            result["client_issues"] += 1
            timing = issue.get("action_timing")
            if type(timing) is str:
                result["actual_action_timing"][timing] = result["actual_action_timing"].get(timing, 0)+1
            matches, malformed, other_kind = [], False, False
            for authority_id, body in db.execute(query, (epoch, issue["seat"], issue["sequence"])):
                try:
                    authority = _object(body)
                    observed_kind = _action(authority, framework, outcome=True)
                    _need((authority["epoch"], authority["seat"], authority["sequence"]) ==
                          (epoch, issue["seat"], issue["sequence"]), "outcome body/index differs")
                    if framework == "replay" and authority["generation"] != issue["generation"]:
                        continue
                    if observed_kind != kind:
                        other_kind = True
                        continue
                    if len(matches) < 2:
                        matches.append((authority_id, authority))
                except (ValueError, TypeError):
                    malformed = True
            if malformed:
                result["unavailable"] += 1
                detail["observation"] = "MALFORMED_COUNTERPART_UNAVAILABLE"
            elif len(matches) > 1:
                result["ambiguous_counterpart"] += 1
                detail["observation"] = "AMBIGUOUS_PUBLISHED_COUNTERPART"
            elif other_kind:
                result["kind_mismatch"] += 1
                detail["observation"] = "PUBLISHED_KIND_DIFFERS"
            elif not matches:
                result["missing_published_counterpart"] += 1
                detail["observation"] = "NO_PUBLISHED_COUNTERPART_OBSERVED"
            else:
                authority_id, authority = matches[0]
                result["matched_published_decisions"] += 1
                result["applied_true" if authority["applied"] else "applied_false"] += 1
                reason_available = type(authority.get("reason")) is str
                result["reason_unavailable"] += int(not reason_available)
                changed = {k: [issue[k], authority[k]] for k in ("serial", "incarnation")
                           if k in issue and k in authority and issue[k] != authority[k]}
                result["published_scope_differs"] += int(bool(changed))
                scope_available = framework == "kit" or ("incarnation" in issue and "incarnation" in authority)
                result["scope_metadata_unavailable"] += int(not scope_available)
                result["execution_tick_differs_from_submitted"] += int(authority["tick"] != issue["submitted_tick"])
                detail.update(observation="LOGICAL_MATCH_ONLY_NOT_ACCEPTANCE", authority_event_id=authority_id,
                              applied=authority["applied"], reason_available=reason_available,
                              authority_tick=authority["tick"], scope_metadata_available=scope_available,
                              published_scope_differences=changed)
                if reason_available:
                    detail["actual_reason"] = authority["reason"]
            detail.update(epoch=epoch, seat=issue["seat"], sequence=issue["sequence"], kind=kind,
                          submitted_tick=issue["submitted_tick"])
        except (ValueError, TypeError, OverflowError) as error:
            result["unavailable"] += 1
            detail.update(observation="UNAVAILABLE", detail=str(error))
        status = detail["observation"]
        result["observations_by_status"][status] = result["observations_by_status"].get(status, 0)+1
        examples = result["samples"].setdefault(status, [])
        if len(examples) < limit:
            examples.append(detail)
    result["detail_samples_truncated"] = any(count > len(result["samples"][status])
                                               for status, count in result["observations_by_status"].items())
    return result


def audit_archive(path, *, framework, epoch, first_tick, last_tick, remote_seat=2, sample_limit=8):
    """Diagnose one declared epoch/window of a CLOSED saved observations.sqlite.

    No database writes, raw-state decode, chain certification or product verdict.
    Raw missing counterparts are observations, never inferred rejection/receipt.
    """
    if framework not in ORIGINS or not _integer(epoch, 1) or not _integer(first_tick) or not _integer(last_tick, first_tick):
        raise ValueError("explicit framework/epoch/tick window required")
    if not _integer(remote_seat, 1, 2) or not _integer(sample_limit, 0, 64):
        raise ValueError("invalid diagnostic seat/sample bound")
    path = Path(path).resolve()
    result = dict(schema=1, diagnostic_only=True, framework=framework, archive=str(path),
                  declared_window=dict(epoch=epoch, first_tick=first_tick, last_tick=last_tick),
                  remote_seat=remote_seat, unavailable=[], unavailable_samples=[], control_groups=[],
                  unattributed_input_rows=0,
                  issue_outcome_correlation=dict(unavailable_reason="archive/schema not read"))
    groups = {(role, seat): _Controls(role, seat, first_tick, last_tick, remote_seat, sample_limit)
              for role in ("host", "client") for seat in (1, 2)}
    try:
        with closing(sqlite3.connect(path.as_uri()+"?mode=ro", uri=True)) as db:
            db.execute("PRAGMA query_only=ON")
            db.execute("BEGIN")
            for role in ("host", "client"):
                players = _players(db, role, epoch) if framework == "kit" else None
                for event_id, raw, indexed_epoch, tick, seat in db.execute(
                        "SELECT id,body,epoch,indexed_tick,seat FROM events WHERE role=? AND kind='INPUT' ORDER BY epoch,indexed_tick,id", (role,)):
                    group = groups.get((role, seat))
                    try:
                        row = _object(raw)
                        _need(_integer(row.get("epoch"), 1) and _integer(row.get("tick")) and
                              _integer(row.get("seat"), 1, 2), "control identity unavailable")
                        _need((row.get("epoch"), row.get("tick"), row.get("seat")) ==
                              (indexed_epoch, tick, seat), "control body/index differs")
                        if indexed_epoch != epoch:
                            continue
                        _need("role" not in row or row["role"] == role, "control role differs")
                        _need("framework" not in row or row["framework"] == framework, "control framework differs")
                        origin = _control(row, framework, players)
                        _need(group is not None, "control seat unavailable")
                        group.add(event_id, row, origin)
                    except (ValueError, TypeError) as error:
                        if indexed_epoch == epoch and group is not None and _integer(tick, first_tick, last_tick):
                            group.value["malformed_controls"] += 1
                        else:
                            result["unattributed_input_rows"] += 1
                        if len(result["unavailable_samples"]) < sample_limit:
                            result["unavailable_samples"].append(dict(event_id=event_id, role=role, detail=str(error)))
                if framework == "kit" and players is None:
                    result["unavailable"].append(role+": actual READY player mapping unavailable")
            result["issue_outcome_correlation"] = _correlate(db, framework, epoch, first_tick, last_tick, sample_limit)
    except (sqlite3.Error, OSError) as error:
        result["unavailable"].append(str(error))
    result["control_groups"] = [group.finish(bool(result["unattributed_input_rows"])) for group in groups.values()]
    result["qualifications"] = [
        "No PASS/FAIL or historical reclassification; existing acceptance remains independent.",
        "Replay Sample is reported literally; submitted_or_sample_count is not a new wire receipt.",
        "Origin runs cover consecutive observed ticks; HeldZero runs also require actual zero axes.",
        "Explicit window coverage is required for DEGENERATE_FULL_HELD_ZERO; incomplete evidence is unavailable.",
        "Missing published action counterpart is not a rejection, receipt or admission-time observation.",
        "Logical action matches do not waive serial/incarnation equality; differences stay reported.",
        "Issue rows are counted; global issue uniqueness and existing immutable-intent proofs remain separate.",
        "No scripted schedule/cycle compatibility, receive timing, state equality, archive-chain integrity or cleanup is certified."]
    if path.is_file():
        try:
            with path.open("rb") as raw:
                digest = hashlib.sha256()
                for chunk in iter(lambda: raw.read(1024*1024), b""):
                    digest.update(chunk)
                result["archive_sha256"] = digest.hexdigest()
        except OSError as error:
            result["unavailable"].append(str(error))
    return result
