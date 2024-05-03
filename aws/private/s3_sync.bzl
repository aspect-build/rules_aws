"Executable rule to release artifacts to an S3 bucket"

_DOC = """\
Executable rule to copy or sync files to an S3 bucket.

Intended for use with `bazel run`, and with Aspect's Continuous Delivery feature.
"""

_ATTRS = {
    "srcs": attr.label_list(
        doc = "Files to copy to the s3 bucket",
        allow_files = True,
        mandatory = True,
    ),
    "bucket": attr.label(
        doc = "file containing a single line: the S3 bucket to copy to",
        allow_single_file = True,
        mandatory = True,
    ),
    "prefix": attr.string(
        doc = "Prefix to prepend to artifact names when copying to S3",
        default = "",
        mandatory = False,
    ),
    "role": attr.string(
        doc = "Assume this role before copying files, using `aws sts assume-role`",
    ),
    "aws": attr.label(
        doc = "AWS CLI",
        default = Label("@aws"),
    ),
    "_sync_script": attr.label(
        default = Label("//aws/private:s3_sync.sh"),
        allow_single_file = True,
    ),
}

def _s3_sync_impl(ctx):
    executable = ctx.actions.declare_file("{}/s3_sync.sh".format(ctx.label.name))
    vars = [
        "bucket_file=\"{}\"".format(ctx.file.bucket.short_path),
        "prefix=\"{}\"".format(ctx.attr.prefix),
    ]
    if ctx.attr.role:
        vars.append("role=\"{}\"".format(ctx.attr.role))
    ctx.actions.expand_template(
        template = ctx.file._sync_script,
        output = executable,
        is_executable = True,
        substitutions = {
            "$aws": ctx.attr.aws[DefaultInfo].default_runfiles.files.to_list()[0].short_path,
            "artifacts=()": "artifacts=({})".format(" ".join([s.short_path for s in ctx.files.srcs])),
            "# Collect Args": "\n".join(vars),
        },
    )
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = [executable, ctx.file.bucket] + ctx.files.srcs).merge(ctx.attr.aws[DefaultInfo].default_runfiles),
    )]

s3_sync = rule(
    implementation = _s3_sync_impl,
    executable = True,
    attrs = _ATTRS,
    doc = _DOC,
)
