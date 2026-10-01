"""Unit tests for starlark helpers
See https://bazel.build/rules/testing#testing-starlark-utilities
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//aws/private:versions.bzl", "TOOL_VERSIONS")

def _smoke_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.true(env, "2.13.0" in TOOL_VERSIONS)
    for version, platforms in TOOL_VERSIONS.items():
        for platform in ["linux-aarch64", "linux-x86_64", "darwin"]:
            asserts.true(env, platform in platforms, "{} missing {}".format(version, platform))
            asserts.true(env, platforms[platform][1].startswith("sha384-"))
    return unittest.end(env)

# The unittest library requires that we export the test cases as named test rules,
# but their names are arbitrary and don't appear anywhere.
_t0_test = unittest.make(_smoke_test_impl)

def versions_test_suite(name):
    unittest.suite(name, _t0_test)
