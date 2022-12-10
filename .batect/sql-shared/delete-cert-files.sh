#!/bin/bash
set -o pipefail

# Delete cert files if they exist. They'll be created again as part of the HADR setup.
rm -f /certificate/cert.key 2> /dev/null
rm -f /certificate/cert.cert 2> /dev/null
