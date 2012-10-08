import time
import os
import os.path
import shutil
import glob

from seesaw.project import *
from seesaw.config import *
from seesaw.item import *
from seesaw.task import *
from seesaw.pipeline import *
from seesaw.externalprocess import *
from seesaw.tracker import *

DATA_DIR = "data"
USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27"
VERSION = "20121008.01"

class PrepareDirectories(SimpleTask):
  def __init__(self):
    SimpleTask.__init__(self, "PrepareDirectories")

  def process(self, item):
    item_name = item["item_name"]
    dirname = "/".join(( DATA_DIR, item_name ))

    if os.path.isdir(dirname):
      shutil.rmtree(dirname)

    os.makedirs(dirname + "/files")

    item["item_dir"] = dirname
    item["data_dir"] = DATA_DIR
    item["warc_file_base"] = "webshots.com-user-%s-%s" % (item_name, time.strftime("%Y%m%d-%H%M%S"))

class MoveFiles(SimpleTask):
  def __init__(self):
    SimpleTask.__init__(self, "MoveFiles")

  def process(self, item):
    os.rename("%(item_dir)s/%(warc_file_base)s.warc.gz" % item,
              "%(data_dir)s/%(warc_file_base)s.warc.gz" % item)

    shutil.rmtree("%(item_dir)s" % item)

class DeleteFiles(SimpleTask):
  def __init__(self):
    SimpleTask.__init__(self, "DeleteFiles")

  def process(self, item):
    os.unlink("%(data_dir)s/%(warc_file_base)s.warc.gz" % item)

def calculate_item_id(item):
  inline_photos = glob.glob("%(item_dir)s/files/community.webshots.com/inlinePhoto*" % item)
  n = len(inline_photos)
  if n == 0:
    return "null"
  else:
    return inline_photos[0] + "-" + inline_photos[n-1]


project = Project(
  title = "Webshots",
  project_html = """
    <img class="project-logo" alt="Webshots logo" src="http://archiveteam.org/images/thumb/3/36/Webshots-logo-crop.png/120px-Webshots-logo-crop.png" />
    <h2>Webshots <span class="links"><a href="http://community.webshots.com/">Website</a> &middot; <a href="http://tracker.archiveteam.org/webshots/">Leaderboard</a></span></h2>
    <p><i>Webshots</i> will soon become <i>Smile, by Webshots</i>. We archive the member photos.</p>
  """,
  utc_deadline = datetime.datetime(2012,12,1, 23,59,0)
)

pipeline = Pipeline(
  GetItemFromTracker("http://tracker.archiveteam.org/webshots", downloader, VERSION),
  PrepareDirectories(),
  WgetDownload([ "./wget-lua",
      "-U", USER_AGENT,
      "-nv",
      "-o", ItemInterpolation("%(item_dir)s/wget.log"),
      "--directory-prefix", ItemInterpolation("%(item_dir)s/files"),
      "--force-directories",
      "--adjust-extension",
      "-e", "robots=off",
      "--page-requisites", "--span-hosts",
      "--lua-script", "webshots.lua",
      "--reject-regex", "agwebshots.112.2o7.net|track_pagetag=|ads.com.com|ag.tags.crwdcntrl.net|.googlesyndication.com|tags.bluekai.com",
      "--timeout", "10",
      "--tries", "3",
      "--waitretry", "5",
      "--warc-file", ItemInterpolation("%(item_dir)s/%(warc_file_base)s"),
      "--warc-header", "operator: Archive Team",
      "--warc-header", "webshots-dld-script-version: " + VERSION,
      "--warc-header", ItemInterpolation("webshots-username: %(item_name)s"),
      ItemInterpolation("http://webshots.com/user/%(item_name)s"),
      ItemInterpolation("http://community.webshots.com/user/%(item_name)s")
    ],
    max_tries = 2,
    accept_on_exit_code = [ 0, 4, 6, 8 ],
  ),
  PrepareStatsForTracker(
    defaults = { "downloader": downloader, "version": VERSION },
    file_groups = {
      "data": [ ItemInterpolation("%(item_dir)s/%(warc_file_base)s.warc.gz") ]
    },
    id_function = calculate_item_id
  ),
  MoveFiles(),
  LimitConcurrent(1,
    RsyncUpload(
      target = ConfigInterpolation("fos.textfiles.com::webshotz/%s/", downloader),
      target_source_path = ItemInterpolation("%(data_dir)s/"),
      files = [
        ItemInterpolation("%(warc_file_base)s.warc.gz")
      ],
      extra_args = [
        "--partial-dir", ".rsync-tmp"
      ]
    ),
  ),
  SendDoneToTracker(
    tracker_url = "http://tracker.archiveteam.org/webshots",
    stats = ItemValue("stats")
  ),
  DeleteFiles()
)

