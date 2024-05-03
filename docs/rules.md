<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API re-exports

<a id="s3_sync"></a>

## s3_sync

<pre>
s3_sync(<a href="#s3_sync-name">name</a>, <a href="#s3_sync-aws">aws</a>, <a href="#s3_sync-bucket">bucket</a>, <a href="#s3_sync-bucket_file">bucket_file</a>, <a href="#s3_sync-role">role</a>, <a href="#s3_sync-srcs">srcs</a>)
</pre>

Executable rule to copy or sync files to an S3 bucket.

Intended for use with `bazel run`, and with Aspect's Continuous Delivery feature.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="s3_sync-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="s3_sync-aws"></a>aws |  AWS CLI   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>@aws//:aws</code> |
| <a id="s3_sync-bucket"></a>bucket |  S3 path to copy to   | String | optional | <code>""</code> |
| <a id="s3_sync-bucket_file"></a>bucket_file |  file containing a single line: the S3 path to copy to. Useful because the file content may be stamped.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional | <code>None</code> |
| <a id="s3_sync-role"></a>role |  Assume this role before copying files, using <code>aws sts assume-role</code>   | String | optional | <code>""</code> |
| <a id="s3_sync-srcs"></a>srcs |  Files to copy to the s3 bucket   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


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


