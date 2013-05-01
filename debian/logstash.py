#!/usr/bin/env python

import os
import sys

cmd = []
cmd.append('java -Xmx32m -Djava.io.tmpdir=/var/lib/logstash/ -jar /usr/share/logstash/logstash.jar agent -f /etc/logstash/conf.d --log /var/log/logstash/logstash.log')

cmd.append(' '.join(sys.argv[1:]))
cmd = ' '.join(cmd).split()
cmd.insert(1, os.path.basename(sys.argv[0]))
os.execvp(cmd[0], cmd[1:])