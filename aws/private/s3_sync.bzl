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
    "bucket": attr.string(
        doc = "S3 path to copy to",
    ),
    "bucket_file": attr.label(
        doc = "file containing a single line: the S3 path to copy to. Useful because the file content may be stamped.",
        allow_single_file = True,
    ),
    "destination_uri_file": attr.label(
        doc = """Only permitted when copying a single src file. A file containing a single line:
            the full [S3Uri](https://docs.aws.amazon.com/cli/latest/reference/s3/#path-argument-type) to copy the file to.""",
        allow_single_file = True,
    ),
    "role": attr.string(
        doc = "Assume this role before copying files, using `aws sts assume-role`",
    ),
    "aws": attr.label(
        doc = "AWS CLI",
    ),
    "_sync_script": attr.label(
        default = Label("//aws/private:s3_sync.sh"),
        allow_single_file = True,
    ),
}

def _s3_sync_impl(ctx):
    aws_toolchain = ctx.toolchains["//aws:toolchain_type"]
    coreutils = ctx.toolchains["@aspect_bazel_lib//lib:coreutils_toolchain_type"]
    jq = ctx.toolchains["@aspect_bazel_lib//lib:jq_toolchain_type"]

    if ctx.attr.aws:
        aws_tool_path = ctx.attr.aws[DefaultInfo].default_runfiles.files.to_list()[0].short_path
        aws_runfiles = ctx.attr.aws[DefaultInfo].default_runfiles
    else:
        aws_tool_path = aws_toolchain.awsinfo.target_tool_path
        aws_runfiles = ctx.runfiles(files = aws_toolchain.awsinfo.tool_files)

    executable = ctx.actions.declare_file("{}/s3_sync.sh".format(ctx.label.name))
    runfiles = [executable, coreutils.coreutils_info.bin, jq.jqinfo.bin] + ctx.files.srcs
    vars = []
    if int(bool(ctx.attr.bucket)) + int(bool(ctx.attr.bucket_file)) + int(bool(ctx.attr.destination_uri_file)) != 1:
        fail("Exactly one of 'bucket', 'bucket_file', or 'destination_uri_file' must be set")
    if ctx.attr.bucket_file:
        vars.append("bucket_file=\"{}\"".format(ctx.file.bucket_file.short_path))
        runfiles.append(ctx.file.bucket_file)
    elif ctx.attr.bucket:
        vars.append("bucket=\"{}\"".format(ctx.attr.bucket))
    else:
        if len(ctx.files.srcs) > 1:
            fail("Only one source file may be copied using destination_uri_file")
        vars.append("destination_uri_file=\"{}\"".format(ctx.file.destination_uri_file.short_path))
        runfiles.append(ctx.file.destination_uri_file)
    if ctx.attr.role:
        vars.append("role=\"{}\"".format(ctx.attr.role))
    ctx.actions.expand_template(
        template = ctx.file._sync_script,
        output = executable,
        is_executable = True,
        substitutions = {
            "$aws": aws_tool_path,
            "$coreutils": coreutils.coreutils_info.bin.short_path,
            "$jq": jq.jqinfo.bin.short_path,
            "artifacts=()": "artifacts=({})".format(" ".join([s.short_path for s in ctx.files.srcs])),
            "# Collect Args": "\n".join(vars),
        },
    )

    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = runfiles).merge(aws_runfiles),
    )]

s3_sync = rule(
    implementation = _s3_sync_impl,
    executable = True,
    attrs = _ATTRS,
    doc = _DOC,
    toolchains = [
        "//aws:toolchain_type",
        "@aspect_bazel_lib//lib:coreutils_toolchain_type",
        "@aspect_bazel_lib//lib:jq_toolchain_type",
    ],
)
