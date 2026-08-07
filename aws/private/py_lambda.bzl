"Rule to produce tar files with py_binary deps and app"

load("@aspect_bazel_lib//lib:tar.bzl", "tar")

# Write these two separate layers, so application changes are a small delta when pushing to a registry
_LAYERS = ["app", "deps"]

def _short_path(file_):
    # Remove prefixes for external and generated files.
    # E.g.,
    #   ../py_deps_pypi__pydantic/pydantic/__init__.py -> pydantic/__init__.py
    short_path = file_.short_path
    if short_path.startswith("../"):
        second_slash = short_path.index("/", 3)
        short_path = short_path[second_slash + 1:]
    return short_path

# mtree is a space-delimited format whose reader also treats backslash, tab and
# newline specially, so any of them in a path corrupts the spec -- bsdtar reads
# the rest of the path as keywords and fails with "Can't open <truncated>".
# Real wheels do ship such paths: scipy has
# scipy/io/tests/data/"Transparent Busy.ani", so any aws_py_lambda whose deps
# pull scipy in cannot build. bsdtar accepts backslash-octal escapes.
#
# Backslash is escaped FIRST; otherwise it would also match the backslashes
# introduced by the escapes below, double-encoding them.
def _mtree_escape(path):
    return (
        path
            .replace("\\", "\\134")
            .replace(" ", "\\040")
            .replace("\t", "\\011")
            .replace("\n", "\\012")
    )

# Every ancestor directory of the given paths, deduped, parents before
# children. A parent is always a strict prefix of its child, and a string sorts
# before any extension of itself, so sorting is enough to order them.
def _ancestor_dirs(paths):
    dirs = {}
    for path in paths:
        acc = ""
        for segment in path.split("/")[:-1]:
            acc = acc + "/" + segment if acc else segment
            dirs[acc] = True
    return sorted(dirs.keys())

# Copied from aspect-bazel-lib/lib/private/tar.bzl
def _mtree_line(file, type, content = None, uid = "0", gid = "0", time = "1672560000", mode = "0644"):
    spec = [
        _mtree_escape(file),
        "uid=" + uid,
        "gid=" + gid,
        "time=" + time,
        "mode=" + mode,
        "type=" + type,
    ]

    # Bazel hardlinks identical files in the execroot (every empty __init__.py
    # and duplicated wheel data file shares one inode), and bsdtar preserves
    # that as hardlink entries. AWS Lambda's image unpacker rejects a layer
    # containing them -- InvalidImage / UnsupportedImageLayerDetected, at deploy
    # time, before any invocation. Docker unpacks them happily, so nothing local
    # catches it. Declaring nlink=1 makes bsdtar emit each as its own regular
    # file. There is no bsdtar flag for this.
    if type == "file":
        spec.append("nlink=1")

    if content:
        spec.append("content=" + _mtree_escape(content))
    return " ".join(spec)

def _py_lambda_tar_impl(ctx):
    deps = ctx.attr.target[DefaultInfo].default_runfiles.files

    # (destination, content-or-None) for every file this layer carries.
    entries = []

    for dep in deps.to_list():
        short_path = _short_path(dep)
        if dep.owner.workspace_name == "" and ctx.attr.kind == "app":
            entries.append((ctx.attr.prefix + "/" + dep.short_path, dep.path))
        elif short_path.startswith("site-packages") and ctx.attr.kind == "deps":
            entries.append((ctx.attr.prefix + short_path[len("site-packages"):], dep.path))

    if ctx.attr.kind == "app" and ctx.attr.init_files:
        path = ""
        for dir in ctx.attr.init_files.split("/"):
            path = path + "/" + dir
            entries.append((ctx.attr.prefix + path + "/__init__.py", None))

    # Spell out every ancestor directory rather than leaving them implicit.
    # Docker's unpacker synthesizes missing parents; AWS Lambda's does not --
    # it rejects the image at deploy time, before any invocation, with:
    #
    #     CustomerError: ImageLayerFailure: UnsupportedImageLayerDetected
    #     - Layer Digest sha256:...
    #
    # Directories are emitted first so a parent always precedes its contents.
    mtree = [
        _mtree_line(dir, type = "dir", mode = "0755")
        for dir in _ancestor_dirs([dest for dest, _ in entries])
    ]
    for dest, content in entries:
        mtree.append(_mtree_line(dest, type = "file", content = content))

    mtree.append("")
    ctx.actions.write(ctx.outputs.output, "\n".join(mtree))

    out = depset(direct = [ctx.outputs.output])
    return [DefaultInfo(files = out)]

_py_lambda_tar = rule(
    implementation = _py_lambda_tar_impl,
    attrs = {
        "target": attr.label(
            # require PyRuntimeInfo provider to be sure it's a py_binary ?
        ),
        "prefix": attr.string(doc = "path prefix for each entry in the tar"),
        "init_files": attr.string(doc = "path where __init__ files will be placed"),
        "kind": attr.string(values = _LAYERS),
        "output": attr.output(),
    },
)

def py_lambda_tars(name, target, prefix = "var/task", init_files = "examples/python_lambda", **kwargs):
    for kind in _LAYERS:
        _py_lambda_tar(
            name = "_{}_{}_mf".format(name, kind),
            kind = kind,
            target = target,
            prefix = prefix,
            init_files = init_files,
            output = "{}.{}.spec".format(name, kind),
            **kwargs
        )

    # gzip, not for size: an uncompressed layer under a Docker-format manifest
    # gets media type application/vnd.docker.image.rootfs.diff.tar, which the
    # Docker image spec does not define (it specifies only the .tar.gzip form).
    # AWS Lambda rejects such a layer with UnsupportedImageLayerDetected. The
    # base image here is Docker-format, so the manifest format follows it.
    tar(
        name = name,
        srcs = [target],
        compress = "gzip",
        mtree = ":_{}_{}_mf".format(name, "app"),
    )

    tar(
        name = name + ".deps",
        srcs = [target],
        compress = "gzip",
        mtree = ":_{}_{}_mf".format(name, "deps"),
    )
