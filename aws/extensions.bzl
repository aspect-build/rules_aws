"""Extensions for bzlmod.

Installs a aws toolchain.
Every module can define a toolchain version under the default name, "aws".
The latest of those versions will be selected (the rest discarded),
and will always be registered by rules_aws.

Additionally, the root module can define arbitrarily many more toolchain versions under different
names (the latest version will be picked for each name) and can register them as it sees fit,
effectively overriding the default named toolchain due to toolchain resolution precedence.

Versions not mirrored in rules_aws can be used by also supplying `integrity_hashes`:

```starlark
aws = use_extension("@aspect_rules_aws//aws:extensions.bzl", "aws")
aws.toolchain(
    aws_cli_version = "2.40.0",
    integrity_hashes = {
        "darwin": "sha384-...",
        "linux-aarch64": "sha384-...",
        "linux-x86_64": "sha384-...",
    },
)
```

Without them the CLI is downloaded unverified and a warning prints the hashes to pin.
"""

load("@aspect_tools_telemetry_report//:defs.bzl", "TELEMETRY")  # buildifier: disable=load
load("@bazel_skylib//lib:versions.bzl", "versions")
load(":repositories.bzl", "aws_register_toolchains")

_DEFAULT_NAME = "aws"

aws_toolchain = tag_class(attrs = {
    "name": attr.string(doc = """\
Base name for generated repositories, allowing more than one aws toolchain to be registered.
Overriding the default is only permitted in the root module.
""", default = _DEFAULT_NAME),
    "aws_cli_version": attr.string(doc = "Explicit version of the aws CLI.", mandatory = True),
    "integrity_hashes": attr.string_dict(doc = """\
Mapping from platform (darwin, linux-aarch64, linux-x86_64) to the SRI integrity hash of
the AWS CLI download. Overrides the hashes mirrored in rules_aws, and allows using versions
that aren't mirrored.
"""),
})

def _toolchain_extension(module_ctx):
    registrations = {}
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            if toolchain.name != _DEFAULT_NAME and not mod.is_root:
                fail("""\
                Only the root module may override the default name for the aws toolchain.
                This prevents conflicting registrations in the global namespace of external repos.
                """)
            versions_for_name = registrations.setdefault(toolchain.name, {})
            versions_for_name.setdefault(toolchain.aws_cli_version, {}).update(toolchain.integrity_hashes)
    for name, versions_for_name in registrations.items():
        selected = sorted(versions_for_name.keys(), key = versions.parse, reverse = True)[0]
        if len(versions_for_name) > 1:
            # buildifier: disable=print
            print("NOTE: aws toolchain {} has multiple versions {}, selected {}".format(name, versions_for_name.keys(), selected))

        aws_register_toolchains(
            name = name,
            aws_cli_version = selected,
            integrity_hashes = versions_for_name[selected],
            register = False,
        )

aws = module_extension(
    implementation = _toolchain_extension,
    tag_classes = {"toolchain": aws_toolchain},
)
