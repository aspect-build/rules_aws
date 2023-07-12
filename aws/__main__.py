import sys

import mimetypes
from awscli.clidriver import main

# The mimetypes library is inherently non-hermetic.
# It looks for files like /etc/mime.types which influence the content-type applied.
# https://docs.python.org/3/library/mimetypes.html#mimetypes.knownfiles
#
# In order for Terraform to read a file with data "aws_s3_object":
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_object
# > The content of an object (body field) is available only for objects which have a human-readable
# > Content-Type (text/* and application/json). This is to prevent printing unsafe characters and
# > potentially downloading large amount of data which would be thrown away in favour of metadata.
#
# So we explicitly set the ones we care about.
mimetypes.add_type("text/x-sh", ".sh")

if __name__ == "__main__":
    sys.exit(main())
