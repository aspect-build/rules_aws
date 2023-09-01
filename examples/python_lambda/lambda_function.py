# Copied from https://docs.aws.amazon.com/lambda/latest/dg/python-image.html#python-image-instructions
import requests
import sys

def handler(event, context):
    r = requests.get("https://www.example.com")
    print(r.ok)

    return 'Hello from AWS Lambda using Python' + sys.version + '!'
