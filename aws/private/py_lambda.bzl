"Rule to produce tar files with py_binary deps and app"

load("@aspect_bazel_lib//lib:tar.bzl", "tar")
load("@bazel_skylib//lib:new_sets.bzl", "sets")

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


def _get_mtree_dirs_list_to_file(path):
    results = []
    if "/" not in path:
        return results

    parts = ""
    for dir_part in path.split("/")[:-1]:
        if len(parts) == 0:
            parts += dir_part
        else:
            parts += "/" + dir_part

        results.append(_mtree_line(parts, type = "dir", mode = "0755"))

    return results

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

def _py_lambda_tar_impl(ctx):
    deps = ctx.attr.target[DefaultInfo].default_runfiles.files

    mtree = []
    for dep in deps.to_list():
        short_path = _short_path(dep)
        mtree_path = None
        if dep.owner.workspace_name == "" and ctx.attr.kind == "app":
            mtree_path = ctx.attr.prefix + "/" + dep.short_path
        elif short_path.startswith("site-packages") and ctx.attr.kind == "deps":
            mtree_path = ctx.attr.prefix + short_path[len("site-packages"):]
        if mtree_path:
            mtree.extend(_get_mtree_dirs_list_to_file(mtree_path))
            mtree.append(_mtree_line(mtree_path, type = "file", content = dep.path))

    if ctx.attr.kind == "app" and ctx.attr.init_files:
        path = ""
        for dir in ctx.attr.init_files.split("/"):
            path = path + "/" + dir
            mtree.append(_mtree_line(ctx.attr.prefix + path, type = "dir", mode = "0755"))
            mtree.append(_mtree_line(ctx.attr.prefix + path + "/__init__.py", type = "file"))

    mtree = sets.to_list(sets.make(mtree))
    mtree = sorted(mtree, key = lambda x: len(x.split("/")))
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
