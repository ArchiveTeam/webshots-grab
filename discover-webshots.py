#!/usr/bin/env python

import json
import re
import time
import urllib

from tornado import ioloop, httpclient, gen



alphabet = "0123456789abcdefghijklmnopqrstuvwxyz-"
USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27"
http_client = httpclient.HTTPClient()

print "Loading task..."
res = http_client.fetch("http://tracker.archiveteam.org:8123/request-discover", method="POST", body="n=25&version=2")
task = json.loads(res.body)
# task = { "id": 123, "prefix": "ab03" }

print "Task %s" % task["id"]
prefixes = task["prefixes"]

if prefixes == []:
  print "No task."
  exit()


usernames = []
next_prefixes = []

for prefix in prefixes:
  count = 0

  print " - Prefix: '%s'" % prefix
  while True:
    query = urllib.quote(prefix.ljust(3, "%") + "%")
    req = httpclient.HTTPRequest(
        ("http://www.webshots.com/explore/member?action=userSearch&username=%s" % query),
        connect_timeout=10, request_timeout=30,
        user_agent=USER_AGENT)
    try:
      res = http_client.fetch(req)
      matches = re.findall('http:\/\/community\.webshots\.com\/user\/([^/]+)', res.body)
      for value in matches:
        if value != "my":
          usernames.append(value)
      count = res.body.count("http://community.webshots.com/user/")
      break

    except httpclient.HTTPError, e:
      print "Error:", e
      if e.code == 599:
        # timeout?
        time.sleep(10)
      else:
        # not found
        break

  if count < 100:
    # End of this query reached
    pass
  else:
    # Not specific enough, we need to go a level deeper
    for c in alphabet:
      next_prefixes.append("%s%s" % (prefix, c))


print
print "Submitting results (%d usernames, %d new prefixes)..." % (len(usernames), len(next_prefixes))
json_body = json.dumps({ "id": task["id"], "prefixes": prefixes, "usernames": usernames, "next_prefixes": next_prefixes })
print json_body
res = http_client.fetch("http://tracker.archiveteam.org:8123/submit-discover", method="POST",
                        body=json_body, headers={"Content-Type": "application/json"})


