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

# Copied from aspect-bazel-lib/lib/private/tar.bzl
def _mtree_line(file, type, content = None, uid = "0", gid = "0", time = "1672560000", mode = "0644"):
    spec = [
        file,
        "uid=" + uid,
        "gid=" + gid,
        "time=" + time,
        "mode=" + mode,
        "type=" + type,
    ]
    if content:
        spec.append("content=" + content)
    return " ".join(spec)

def _get_parent_dirs(path):
    """Get all parent directories of a given path."""
    dirs = []
    parts = path.split("/")
    for i in range(1, len(parts)):
        dirs.append("/".join(parts[:i]))
    return dirs

def _py_lambda_tar_impl(ctx):
    deps = ctx.attr.target[DefaultInfo].default_runfiles.files

    # Track created directories to avoid duplicates
    created_dirs = set()
    mtree = []

    def _ensure_parent_dirs(file_path):
        """Ensure all parent directories of file_path are created."""
        parent_dirs = _get_parent_dirs(file_path)
        for dir_path in parent_dirs:
            if dir_path not in created_dirs:
                created_dirs.add(dir_path)
                mtree.append(_mtree_line(dir_path, type = "dir", mode = "0755"))

    # Create the root prefix directory
    _ensure_parent_dirs(ctx.attr.prefix)
    created_dirs.add(ctx.attr.prefix)
    mtree.append(_mtree_line(ctx.attr.prefix, type = "dir", mode = "0755"))

    for dep in deps.to_list():
        short_path = _short_path(dep)
        if dep.owner.workspace_name == "" and ctx.attr.kind == "app":
            file_path = ctx.attr.prefix + "/" + dep.short_path
            _ensure_parent_dirs(file_path)
            mtree.append(_mtree_line(file_path, type = "file", content = dep.path))
        elif short_path.startswith("site-packages") and ctx.attr.kind == "deps":
            file_path = ctx.attr.prefix + short_path[len("site-packages"):]
            _ensure_parent_dirs(file_path)
            mtree.append(_mtree_line(file_path, type = "file", content = dep.path))

    if ctx.attr.kind == "app" and ctx.attr.init_files:
        path = ""
        for dir in ctx.attr.init_files.split("/"):
            path = path + "/" + dir
            file_path = ctx.attr.prefix + path + "/__init__.py"
            _ensure_parent_dirs(file_path)
            mtree.append(_mtree_line(file_path, type = "file"))

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

    tar(
        name = name,
        srcs = [target],
        mtree = ":_{}_{}_mf".format(name, "app"),
    )

    tar(
        name = name + ".deps",
        srcs = [target],
        mtree = ":_{}_{}_mf".format(name, "deps"),
    )
