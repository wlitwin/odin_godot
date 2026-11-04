"""Evidence-validator controls only; synthetic data is never scene acceptance."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import accept as a


def ready(framework):
    return {"impairment": {
        a.REQUEST_KEYS[framework]: dict(latency_ms=10, jitter_ms=1, loss_percent=0, duplicate_percent=0, reorder=False),
        "effective": dict(applied=True, latency_ms=10, jitter_ms=1, loss_permyriad=0, duplicate_permyriad=0, delay_active=True, unreliable_may_reorder=True),
        "channel": a.CHANNELS[framework],
    }}


def rejection():
    return [dict(event="ERROR", where="impairment_preflight", status="Invalid", before_transport=True, before_physics=True),
            dict(event="RESULT", ok=False, errors=1, cleanup_errors=0, engine_live=0, wrapper_live=0, meter_live=0, native_stats_ok=True)]


class ValidatorControls(unittest.TestCase):
    def test_sibling_keys_are_exact(self):
        for framework in ("kit", "replay"):
            data = ready(framework)
            a.verify_ready(data, framework, a.LATENCY)
            wrong = "request" if framework == "kit" else "requested"
            data["impairment"][wrong] = data["impairment"].pop(a.REQUEST_KEYS[framework])
            with self.assertRaises(a.EvidenceError): a.verify_ready(data, framework, a.LATENCY)

    def test_requested_alone_and_false_effective_fail(self):
        data = ready("replay"); del data["impairment"]["effective"]
        with self.assertRaises(a.EvidenceError): a.verify_ready(data, "replay", a.LATENCY)
        data = ready("replay"); data["impairment"]["effective"]["delay_active"] = False
        with self.assertRaises(a.EvidenceError): a.verify_ready(data, "replay", a.LATENCY)

    def test_channel_guarantees_cannot_be_relabeled(self):
        data = copy.deepcopy(ready("kit")); data["impairment"]["channel"]["reliable"] = "dropped"
        with self.assertRaises(a.EvidenceError): a.verify_ready(data, "kit", a.LATENCY)

    def test_bool_is_not_integer_metadata(self):
        data = ready("kit"); data["impairment"]["effective"]["unreliable_may_reorder"] = 1
        with self.assertRaises(a.EvidenceError): a.verify_ready(data, "kit", a.LATENCY)

    def check_rejection(self, records, code=1, timeout=False):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "log"
            path.write_text("\n".join(json.dumps(item) for item in records) + "\n")
            return a.verify_rejection(path, code, "Invalid", timeout)

    def test_expected_configuration_error_is_not_cleanup_error(self):
        self.check_rejection(rejection())
        data = rejection(); data[-1]["cleanup_errors"] = 1
        with self.assertRaises(a.EvidenceError): self.check_rejection(data)

    def test_missing_metric_and_timeout_cannot_pass(self):
        data = rejection(); del data[-1]["meter_live"]
        with self.assertRaises(a.EvidenceError): self.check_rejection(data)
        with self.assertRaises(a.EvidenceError): self.check_rejection(rejection(), timeout=True)

    def test_late_rejection_or_zero_exit_cannot_pass(self):
        with self.assertRaises(a.EvidenceError): self.check_rejection([dict(event="READY"), *rejection()])
        with self.assertRaises(a.EvidenceError): self.check_rejection(rejection(), code=0)


if __name__ == "__main__": unittest.main()
