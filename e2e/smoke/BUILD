"""Provides a simple way to test your rules as an external workspace.
Add a basic smoke-test target below.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@aspect_rules_aws//aws:defs.bzl", "s3_sync")

s3_sync(
    name = "upload_dry_run",
    srcs = ["BUILD"],
    bucket = "s3://my-test-bucket/release_destination",
)

build_test(
    name = "smoke_test",
    targets = [
        ":upload_dry_run",
    ],
)
