#!/bin/bash
./wget-lua \
    --directory-prefix=files/ \
    --force-directories --adjust-extension \
    --user-agent="Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US) AppleWebKit/533.20.25 (KHTML, like Gecko) Version/5.0.4 Safari/533.20.27" \
    --span-hosts \
    --page-requisites \
    -nv \
    -e "robots=off" \
    --timeout=10 --tries=3 --waitretry=5 \
    --lua-script=webshots.lua \
    --warc-header="operator: Archive Team" \
    --warc-file=webshots-test \
    http://outdoors.webshots.com/photo/2688178200053971194ivfbNy
#   http://outdoors.webshots.com/album/555614763SAwAPi
#   http://community.webshots.com/user/iahuis2
#   http://community.webshots.com/user/daliabloze
#   http://community.webshots.com/user/brookefj

