#!/usr/bin/env bash
set -euo pipefail
python3 -m pytest app/tests
python3 -m ruff check app

