"""Verifies //:runtime_pkg's five layers land at their expected install paths.

Each layer (see BUILD.bazel's comments) is a `tar()` target; this test reads
the tar members directly rather than re-deriving path logic, so it catches
regressions like a `strip_prefix`/`package_dir` typo landing a file at the
wrong path without needing to actually install anything.
"""

import importlib
import os
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

_EXPECTED_MEMBERS = {
    "usr/lib/python3/dist-packages/dash_api/__init__.py",
    "usr/lib/python3/dist-packages/dash_api/utils.py",
    "usr/lib/python3/dist-packages/dash_api/_utils.so",
    "usr/bin/dash_api_utils",
    # The bundled protobuf runtime (pb_runtime_pkg) that keeps the generated
    # *_pb2.py modules' gencode version in sync with what's actually
    # installed - see BUILD.bazel's comment on that target for why Trixie's
    # apt python3-protobuf package can't be used for this instead.
    "usr/lib/python3/dist-packages/google/protobuf/__init__.py",
}

# libdashapi.so's multiarch directory is platform-selected (lib_pkg picks
# lib_pkg_x86_64 or lib_pkg_arm64 via `select()`), so only one of these is
# ever present in a given test run - checked as "any", not "all", below.
_EXPECTED_LIBDASHAPI_PATHS = (
    "usr/lib/x86_64-linux-gnu/libdashapi.so",
    "usr/lib/aarch64-linux-gnu/libdashapi.so",
)


class RuntimePkgTest(unittest.TestCase):

    def _all_members(self):
        # cwd during test execution is not the runfiles tree (it varies with
        # the rules_python venv bootstrap). Bazel always sets TEST_SRCDIR to
        # the runfiles root, so anchor the search there - NOT at
        # TEST_SRCDIR/TEST_WORKSPACE, since TEST_WORKSPACE is always "_main"
        # (the root repo) regardless of which repo the test itself belongs
        # to; this target's own data deps land in the "sonic-dash-api+"
        # sibling directory instead.
        members = set()
        for tar_path in Path(os.environ["TEST_SRCDIR"]).rglob("*.tar"):
            with tarfile.open(tar_path) as tf:
                members.update(m.name.lstrip("./") for m in tf.getmembers() if m.isfile())
        return members

    def test_expected_files_are_packaged(self):
        members = self._all_members()
        self.assertTrue(members, "no tar layers found among runtime_pkg's data files")
        for expected in _EXPECTED_MEMBERS:
            self.assertIn(
                expected, members,
                f"{expected!r} missing from runtime_pkg's layers: {sorted(members)}")

    def test_generated_pb2_files_present(self):
        members = self._all_members()
        pb2_files = [
            m for m in members
            if m.startswith("usr/lib/python3/dist-packages/dash_api/") and m.endswith("_pb2.py")
        ]
        self.assertTrue(pb2_files, f"no generated *_pb2.py files found among: {sorted(members)}")

    def test_libdashapi_so_present_for_current_platform(self):
        members = self._all_members()
        self.assertTrue(
            any(path in members for path in _EXPECTED_LIBDASHAPI_PATHS),
            f"none of {_EXPECTED_LIBDASHAPI_PATHS} found among: {sorted(members)}")

    def test_generated_pb2_modules_are_importable(self):
        # Regression test for a real bug: protobuf's Python runtime refuses
        # to load gencode newer than itself ("Detected incompatible
        # Protobuf Gencode/Runtime versions"). Trixie's apt python3-protobuf
        # (5.29.6) is older than what this module's *_pb2.py files were
        # compiled against (protobuf 33.4), so relying on it silently ships
        # a package that throws on import. Actually extract runtime_pkg and
        # import a generated module, rather than just checking file
        # presence, so this fails loudly if that mismatch ever recurs.
        with tempfile.TemporaryDirectory() as install_root:
            for tar_path in Path(os.environ["TEST_SRCDIR"]).rglob("*.tar"):
                with tarfile.open(tar_path) as tf:
                    tf.extractall(install_root)
            site_packages = os.path.join(install_root, "usr/lib/python3/dist-packages")
            sys.path.insert(0, site_packages)
            try:
                route_pb2 = importlib.import_module("dash_api.route_pb2")
                self.assertIsNotNone(route_pb2.Route())
            finally:
                sys.path.remove(site_packages)
                for module_name in list(sys.modules):
                    if module_name == "google" or module_name.startswith(
                            ("google.protobuf", "dash_api")):
                        del sys.modules[module_name]


if __name__ == "__main__":
    unittest.main()
