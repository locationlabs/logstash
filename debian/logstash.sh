#!/bin/sh
exec /usr/bin/java -Xmx32m -Djava.io.tmpdir=/var/lib/logstash/ -jar /usr/share/logstash/logstash.jar agent -f /etc/logstash/conf.d --log /var/log/logstash/logstash.log
