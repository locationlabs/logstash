#!/bin/sh
exec /usr/bin/java -Xmx256m -Djava.io.tmpdir=/var/lib/logstash/ -jar /opt/logstash/logstash.jar agent -f /etc/logstash/conf.d --log /var/log/logstash/logstash.log
