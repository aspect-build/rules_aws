"Implementation of sync rule"

def _s3_sync_impl(ctx):
    aws_toolchain = ctx.toolchains["@aspect_rules_aws//aws:toolchain_type"]

    aws_executable = aws_toolchain.awsinfo.tool_files[0]
    inputs = aws_toolchain.awsinfo.tool_files[:]

    args = ctx.actions.args()
    args.add_all(["s3", "sync", ctx.attr.uri, ctx.outputs.out.path])

    ctx.actions.run(
        inputs = inputs,
        outputs = [ctx.outputs.out],
        executable = aws_executable,
        arguments = [args],
    )
    return [
        DefaultInfo(files = depset([ctx.outputs.out])),
    ]

s3_sync = rule(
    implementation = _s3_sync_impl,
    attrs = {
        "out": attr.output(
            doc = "location to output the folder",
            mandatory = True,
        ),
        "uri": attr.string(
            doc = "S3 URI in the form s3://bucket/path",
            mandatory = True,
        ),
    },
    toolchains = ["@aspect_rules_aws//aws:toolchain_type"],
)
