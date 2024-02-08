"Public API re-exports"

load("@rules_oci//oci:defs.bzl", "oci_image")
load("@rules_python//python:defs.bzl", "py_binary")
load("//aws/private:py_lambda.bzl", "py_lambda_tars")

def aws_py_lambda(name, entry_point = "lambda_function.py", deps = [], base = "@aws_lambda_python"):
    """Defines a Lambda run on the Python runtime.

    See https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html

    Produces an oci_image target following https://docs.aws.amazon.com/lambda/latest/dg/python-image.html

    TODO:
    - produce a [name].zip output following https://docs.aws.amazon.com/lambda/latest/dg/python-package.html#python-package-create-dependencies

    Args:
        name: name of resulting target
        entry_point: python source file implementing the handler
        deps: third-party packages required at runtime
        base: a base image that includes the AWS Runtime Interface Emulator
    """

    bin_target = "_{}.bin".format(name)
    tars_target = "_{}.tars".format(name)

    # Convert //my/pkg:entry_point.py to my.pkg.entry_point.handler
    cmd = "{}.{}.handler".format(native.package_name().replace("/", "."), entry_point.replace(".py", ""))

    py_binary(
        name = bin_target,
        srcs = [entry_point],
        main = entry_point,
        deps = deps,
    )

    py_lambda_tars(
        name = tars_target,
        target = bin_target,
    )

    oci_image(
        name = name,
        base = base,
        cmd = [cmd],
        # Only allow building on linux, since we don't want to upload a lambda zip file
        # with e.g. macos compiled binaries.
        target_compatible_with = ["@platforms//os:linux"],
        # N.B. deps layer appears first since it's larger and changes less frequently.
        tars = [
            "{}.deps".format(tars_target),
            tars_target,
        ],
    )
