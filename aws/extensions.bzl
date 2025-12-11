"""Extensions for bzlmod.

Installs a aws toolchain.
Every module can define a toolchain version under the default name, "aws".
The latest of those versions will be selected (the rest discarded),
and will always be registered by rules_aws.

Additionally, the root module can define arbitrarily many more toolchain versions under different
names (the latest version will be picked for each name) and can register them as it sees fit,
effectively overriding the default named toolchain due to toolchain resolution precedence.
"""

load("@aspect_tools_telemetry_report//:defs.bzl", "TELEMETRY")  # buildifier: disable=load
load("@bazel_skylib//lib:new_sets.bzl", "sets")
load(":repositories.bzl", "aws_register_toolchains")

_DEFAULT_NAME = "aws"

aws_toolchain = tag_class(attrs = {
    "name": attr.string(doc = """\
Base name for generated repositories, allowing more than one aws toolchain to be registered.
Overriding the default is only permitted in the root module.
""", default = _DEFAULT_NAME),
    "aws_cli_version": attr.string(doc = "Explicit version of the aws CLI.", mandatory = True),
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
            if toolchain.name not in registrations.keys():
                registrations[toolchain.name] = []
            registrations[toolchain.name].append(toolchain.aws_cli_version)
    for name, versions in registrations.items():
        unique_versions = sets.to_list(sets.make(versions))
        if len(unique_versions) > 1:
            # TODO: should be semver-aware, using MVS
            selected = sorted(unique_versions, reverse = True)[0]

            # buildifier: disable=print
            print("NOTE: aws toolchain {} has multiple versions {}, selected {}".format(name, unique_versions, selected))
        else:
            selected = unique_versions[0]

        aws_register_toolchains(
            name = name,
            aws_cli_version = selected,
            register = False,
        )

aws = module_extension(
    implementation = _toolchain_extension,
    tag_classes = {"toolchain": aws_toolchain},
)
