<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API re-exports

<a id="aws_py_lambda"></a>

## aws_py_lambda

<pre>
aws_py_lambda(<a href="#aws_py_lambda-name">name</a>, <a href="#aws_py_lambda-entry_point">entry_point</a>, <a href="#aws_py_lambda-deps">deps</a>, <a href="#aws_py_lambda-base">base</a>)
</pre>

Defines a Lambda run on the Python runtime.

See https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html

Produces an oci_image target following https://docs.aws.amazon.com/lambda/latest/dg/python-image.html

TODO:
- produce a [name].zip output following https://docs.aws.amazon.com/lambda/latest/dg/python-package.html#python-package-create-dependencies


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="aws_py_lambda-name"></a>name |  name of resulting target   |  none |
| <a id="aws_py_lambda-entry_point"></a>entry_point |  python source file implementing the handler   |  <code>"lambda_function.py"</code> |
| <a id="aws_py_lambda-deps"></a>deps |  third-party packages required at runtime   |  <code>[]</code> |
| <a id="aws_py_lambda-base"></a>base |  a base image that includes the AWS Runtime Interface Emulator   |  <code>"@aws_lambda_python"</code> |


