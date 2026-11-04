#!/usr/bin/env python3
"""Run one selected browser pair with retained whole-operation telemetry."""
import importlib.util
from pathlib import Path

file=Path(__file__).resolve().parents[1]/'online/run.py'
spec=importlib.util.spec_from_file_location('dockyard_online',file)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
if __name__=='__main__':raise SystemExit(shared.main(driver=Path(__file__).with_name('drive.mjs'),max_ticks=40000,case_timeout=800))
