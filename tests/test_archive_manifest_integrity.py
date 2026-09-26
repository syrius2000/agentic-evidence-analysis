"""Tests archive manifest integrity for immutable historical sources."""

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVES_ROOT = ROOT / "docs" / "Archives"


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_batch_002_manifest_integrity():
    """Verify Batch 002 manifest SHA-256 hashes match archived source bytes exactly."""
    manifest_path = ARCHIVES_ROOT / "20260912_183500_002" / "archive_manifest.json"
    assert manifest_path.is_file(), f"Manifest not found: {manifest_path}"

    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    items = data.get("items", [])
    assert len(items) == 7, f"Expected 7 items in batch 002, got {len(items)}"

    for item in items:
        dest = ROOT / item["destination"]
        expected_sha = item["sha256"]
        assert dest.is_file(), f"Archived source missing: {dest}"
        actual_sha = sha256_of(dest)
        assert actual_sha == expected_sha, (
            f"Archive integrity failure for {dest}:\n"
            f"  expected {expected_sha}\n"
            f"  actual   {actual_sha}"
        )


def test_batch_003_plan_016_manifest_integrity():
    """Verify Batch 003 Plan 016 manifest SHA-256 matches archived source exactly."""
    manifest_path = ARCHIVES_ROOT / "20260913_195758_003" / "archive_manifest.json"
    assert manifest_path.is_file(), f"Manifest not found: {manifest_path}"

    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    items = data.get("items", [])
    plan_016 = next((item for item in items if "implementation_plan_016_0912.md" in item.get("destination", "")), None)
    assert plan_016 is not None, "implementation_plan_016_0912.md not found in batch 003 manifest"

    dest = ROOT / plan_016["destination"]
    assert dest.is_file(), f"Archived source missing: {dest}"
    assert sha256_of(dest) == plan_016["sha256"], f"SHA mismatch for {dest}"


def test_batch_004_manifest_integrity():
    """Verify Batch 004 manifest SHA-256 hashes match archived source bytes exactly."""
    manifest_path = ARCHIVES_ROOT / "20260915_182000_004" / "archive_manifest.json"
    assert manifest_path.is_file(), f"Manifest not found: {manifest_path}"

    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    sources = data.get("sources", [])
    assert len(sources) > 0, "No sources in batch 004"

    for s in sources:
        dest = ROOT / s["archive_path"]
        expected_sha = s["sha256"]
        assert dest.is_file(), f"Archived source missing: {dest}"
        actual_sha = sha256_of(dest)
        assert actual_sha == expected_sha, f"Mismatch in {dest}"


def test_batch_007_manifest_integrity():
    """Verify Batch 007 manifest SHA-256 hashes match archived source bytes when recorded."""
    manifest_path = ARCHIVES_ROOT / "20260920_154500_007" / "archive_manifest.json"
    assert manifest_path.is_file(), f"Manifest not found: {manifest_path}"

    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    sources = data.get("sources", [])
    assert len(sources) > 0, "No sources in batch 007"

    for s in sources:
        expected_sha = s.get("sha256")
        if expected_sha:
            dest = ROOT / s["archive_path"]
            assert dest.is_file(), f"Archived source missing: {dest}"
            actual_sha = sha256_of(dest)
            assert actual_sha == expected_sha, f"Mismatch in {dest}"


def test_batches_012_013_014_manifest_integrity():
    """Verify Batches 012, 013, 014 manifest SHA-256 hashes match archived source bytes exactly."""
    for batch_slug in ("20260924_141100_012", "20260925_183701_013", "20260925_185527_014"):
        manifest_path = ARCHIVES_ROOT / batch_slug / "archive_manifest.json"
        assert manifest_path.is_file(), f"Manifest not found: {manifest_path}"

        data = json.loads(manifest_path.read_text(encoding="utf-8"))
        batch_dir = manifest_path.parent
        files = data.get("files", [])
        assert len(files) > 0, f"No files in {batch_slug}"

        for f in files:
            dest = batch_dir / f["archived_as"]
            expected_sha = f["sha256"]
            assert dest.is_file(), f"Archived source missing: {dest}"
            actual_sha = sha256_of(dest)
            assert actual_sha == expected_sha, f"Mismatch in {dest}"


if __name__ == "__main__":
    test_batch_002_manifest_integrity()
    print("[PASS] test_batch_002_manifest_integrity")
    test_batch_003_plan_016_manifest_integrity()
    print("[PASS] test_batch_003_plan_016_manifest_integrity")
    test_batch_004_manifest_integrity()
    print("[PASS] test_batch_004_manifest_integrity")
    test_batch_007_manifest_integrity()
    print("[PASS] test_batch_007_manifest_integrity")
    test_batches_012_013_014_manifest_integrity()
    print("[PASS] test_batches_012_013_014_manifest_integrity")
    print("All archive manifest integrity tests passed!")
