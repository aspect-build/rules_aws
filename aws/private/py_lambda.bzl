"Rule to produce tar files with py_binary deps and app"

# buildifier: disable=bzl-visibility
load(
    "@rules_pkg//pkg/private:pkg_files.bzl",
    "add_empty_file",
    "add_single_file",
    "write_manifest",
)

def _short_path(file_):
    # Remove prefixes for external and generated files.
    # E.g.,
    #   ../py_deps_pypi__pydantic/pydantic/__init__.py -> pydantic/__init__.py
    short_path = file_.short_path
    if short_path.startswith("../"):
        second_slash = short_path.index("/", 3)
        short_path = short_path[second_slash + 1:]
    return short_path

def _py_lambda_tar_impl(ctx):
    deps = ctx.attr.target[DefaultInfo].default_runfiles.files
    content_map = {}  # content handled in the manifest
    files = []  # Files needed by rule implementation at runtime
    args = ctx.actions.args()
    args.add("--output", ctx.outputs.output.path)

    for dep in deps.to_list():
        short_path = _short_path(dep)

        if dep.owner.workspace_name == "" and ctx.attr.kind == "app":
            add_single_file(
                content_map,
                ctx.attr.prefix + "/" + dep.short_path,
                dep,
                ctx.label,
            )
        elif short_path.startswith("site-packages") and ctx.attr.kind == "deps":
            short_path = short_path[len("site-packages"):]
            add_single_file(
                content_map,
                ctx.attr.prefix + short_path,
                dep,
                ctx.label,
            )

    if ctx.attr.kind == "app" and ctx.attr.init_files:
        path = ""
        for dir in ctx.attr.init_files.split("/"):
            path = path + "/" + dir
            add_empty_file(
                content_map,
                ctx.attr.prefix + path + "/__init__.py",
                ctx.label,
            )

    manifest_file = ctx.actions.declare_file(ctx.label.name + ".manifest")
    files.append(manifest_file)
    write_manifest(ctx, manifest_file, content_map)
    args.add("--manifest", manifest_file.path)
    args.add("--directory", "/")
    args.set_param_file_format("flag_per_line")
    args.use_param_file("@%s", use_always = False)
    inputs = depset(direct = files, transitive = [deps])
    ctx.actions.run(
        outputs = [ctx.outputs.output],
        inputs = inputs,
        executable = ctx.executable._tar,
        arguments = [args],
        progress_message = "Creating archive...",
        mnemonic = "PackageTar",
    )

    out = depset(direct = [ctx.outputs.output])
    return [
        DefaultInfo(files = out),
        OutputGroupInfo(all_files = out),
    ]

_py_lambda_tar = rule(
    implementation = _py_lambda_tar_impl,
    attrs = {
        "target": attr.label(
            # require PyRuntimeInfo provider to be sure it's a py_binary ?
        ),
        "_tar": attr.label(
            default = Label("@rules_pkg//pkg/private/tar:build_tar"),
            cfg = "exec",
            executable = True,
        ),
        "prefix": attr.string(doc = "path prefix for each entry in the tar"),
        "init_files": attr.string(doc = "path where __init__ files will be placed"),
        "kind": attr.string(values = ["app", "deps"]),
        "output": attr.output(),
    },
)

def py_lambda_tars(name, target, prefix = "/var/task", init_files = "examples/python_lambda", **kwargs):
    _py_lambda_tar(
        name = name,
        kind = "app",
        target = target,
        prefix = prefix,
        init_files = init_files,
        output = name + ".app.tar",
        **kwargs
    )

    _py_lambda_tar(
        name = name + ".deps",
        kind = "deps",
        target = target,
        prefix = prefix,
        output = name + ".deps.tar",
        **kwargs
    )
