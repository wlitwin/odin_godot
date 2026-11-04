#!/usr/bin/env python3
"""Reuse the source-bound online runner for actual production lifecycle cases."""
import importlib.util
from pathlib import Path

shared_file=Path(__file__).resolve().parents[1]/'online/run.py'
spec=importlib.util.spec_from_file_location('dockyard_online_runner',shared_file)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
if __name__=='__main__':raise SystemExit(shared.main(driver=Path(__file__).with_name('drive.mjs')))
