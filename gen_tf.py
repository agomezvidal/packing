#!/usr/bin/env python

"""
Read in a plain text list of domains.
Output terraform json file, to generate aws resources.
"""

from __future__ import print_function
import json
import sys

if len(sys.argv) != 3:
    print("Error: expecting two arguments: <source> <destination>")
    sys.exit(1)

in_file = sys.argv[1]
out_file = sys.argv[2]

domains = { 'module': {}, }

with open(in_file) as ins:
    i = 0
    for line in ins:
        domain = line.rstrip()
        # Cannot use . in terraform names
        name = domain.replace(".", "_")
        module = { 'source': "../modules/cert", 'listener_arn':'${module.core.alb_https_listeners['+str(i)+']}', 'domain': domain }
        domains['module'][name] = module
        i = (i + 1) % 8

with open(out_file, 'w') as outs:
    # Readable json. Almost. It's still json
    outs.write(json.dumps(domains, sort_keys=True, indent=2))
