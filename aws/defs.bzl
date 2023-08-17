"Public API re-exports"

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//aws/private:s3_sync.bzl", _s3_sync_rule = "s3_sync")

def s3_sync(name, uri, out = None, **kwargs):
    if not out:
        out = paths.basename(uri)
    _s3_sync_rule(name = name, uri = uri, out = out, **kwargs)

s3 = struct(
    sync = s3_sync,
)
