#!/usr/bin/env python

import json
import re
import time

from tornado import ioloop, httpclient, gen

USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27"


class WebshotsChecker(object):
  def __init__(self, users_to_check, concurrent=1):
    self.users_to_check = users_to_check
    self.running = 0
    self.concurrent = concurrent
    self.users_empty = []
    self.users_not_empty = []
    self.http_client = httpclient.AsyncHTTPClient()

  def start(self):
    while len(self.users_to_check) > 0 and self.running < self.concurrent:
      self.check_user(self.users_to_check.pop())

    if self.running == 0:
      ioloop.IOLoop.instance().stop()

  def check_user(self, username):
    if not re.match(r'^[-_a-zA-Z0-9]+$', username):
      return

    self.running += 1

    req = httpclient.HTTPRequest(
        ("http://community.webshots.com/user/%s/stats" % username),
        connect_timeout=10, request_timeout=30,
        use_gzip=True, user_agent=USER_AGENT)
    req.username = username
    self.http_client.fetch(req, self.handle_response)

  def handle_response(self, response):
    username = response.request.username

    if response.error:
      if response.error.code == 404:
        print "%s: Not found." % username
        self.users_empty.append(username)
      else:
        print "%s: Error %d" % (username, response.error.code)
        self.users_to_check.append(username)

    else:
      m = re.search(r'<table id="profileStatsTable">.+?<\/table>', response.body, re.DOTALL)
      if not m:
        print "%s: Not found." % username
        self.users_empty.append(username)
      else:
        counts = re.findall(r'[0-9]+', m.group(0))

        m = re.search(r'<table id="individualAlbumsTable">.+?<\/table>', response.body, re.DOTALL)
        if m:
          counts.append(len(re.findall(r'/album/', m.group(0))))

        if all([i == 0 or i == "0" for i in counts]):
          print "%s: Empty." % username
          self.users_empty.append(username)
        else:
          print "                          %s: Not empty." % username
          self.users_not_empty.append(username)

    self.running -= 1
    self.start()


print "Loading usernames..."
http_client = httpclient.HTTPClient()
res = http_client.fetch("http://tracker.archiveteam.org:8123/request", method="POST", body="")
task = json.loads(res.body)

print "Task %s" % task["id"]
usernames = task["usernames"]

if len(usernames) == 0:
  print "No usernames."
# time.sleep(30)
  exit()

print "Checking %d usernames..." % len(usernames)
print
wc = WebshotsChecker(usernames, concurrent=4)
wc.start()
ioloop.IOLoop.instance().start()

print
print "Submitting results (%d not empty)..." % len(wc.users_not_empty)
json_body = json.dumps({ "id": task["id"], "empty": wc.users_empty, "not_empty": wc.users_not_empty })
res = http_client.fetch("http://tracker.archiveteam.org:8123/submit", method="POST",
                        body=json_body, headers={"Content-Type": "application/json"})

