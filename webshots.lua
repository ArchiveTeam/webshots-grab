
read_file = function(file)
  if file then
    local f = io.open(file)
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

albums = {}
photos = {}
videos = {}
url_count = 0
album_count = 0
photo_count = 0
video_count = 0

previous_stats = ""

print_stats = function()
  s = " - Downloaded: "..url_count
  s = s.." URLs. Discovered: "
  s = s..album_count.." album"
  if album_count ~= 1 then
    s = s.."s"
  end
  s = s..", "..photo_count.." photo"
  if photo_count ~= 1 then
    s = s.."s"
  end
  s = s..", "..video_count.." video"
  if video_count ~= 1 then
    s = s.."s"
  end
  if s ~= previous_stats then
    io.stdout:write("\r"..s)
    io.stdout:flush()
    previous_stats = s
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  -- progress message
  url_count = url_count + 1
  if url_count % 50 == 0 then
    print_stats()
  end

  -- user page (album list)
  local base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+)[^/]*$")
  if base then
    local html = read_file(file)

    if base == url then
      print("\n + User profile loaded.")
    end

    -- the tab pages
    table.insert(urls, { url=(base.."/profile"), link_expect_html=1 })
    table.insert(urls, { url=(base.."?action=profile"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/people"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/people?list=friends"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/people?list=fans"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/people?list=favorite"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/bookmarks"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/tags"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/messages"), link_expect_html=1 })
    table.insert(urls, { url=(base.."/stats"), link_expect_html=1 })

    -- pagination
    for start in string.gmatch(html, "%?start=(%d+)") do
      table.insert(urls, { url=(base.."?start="..start), link_expect_html=1 })
    end

    -- albums
    for album_url in string.gmatch(html, "http://[^\"/]+/album/[^?\"#/]+") do
      table.insert(urls, { url=(album_url), link_expect_html=1 })
      local album_id = string.match(album_url, "[^/]+$")
      if not albums[album_id] then
        album_count = album_count + 1
        albums[album_id] = true
      end
    end

    print_stats()
  end

  -- people
  local base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+/people)")
  if base then
    local html = read_file(file)

    -- pagination
    for list, sort, start in string.gmatch(html, "people%?list=([^&]+)&amp;sort=(recent%-activity)&amp;start=(%d+)") do
      table.insert(urls, { url=(base.."?list="..list.."&sort="..sort.."&start="..start), link_expect_html=1 })
    end
  end

  -- bookmarks
  local base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+/bookmarks)")
  if base then
    local html = read_file(file)

    -- pagination
    for start in string.gmatch(html, "%?start=(%d+)") do
      table.insert(urls, { url=(base.."?start="..start), link_expect_html=1 })
    end
  end

  -- tags : won't do

  -- messages (full page)
  local base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+/messages)$")
  if base then
    local html = read_file(file)

    -- pagination
    for page in string.gmatch(html, "/forum/update%?[^\"]+") do
      page = string.gsub(page, "&amp;", "&")
      table.insert(urls, { url=("http://community.webshots.com"..page), link_expect_html=1 })
    end
  end

  -- messages (updates)
  local base = string.match(url, "^http://community%.webshots%.com/forum/update")
  if base then
    local html = read_file(file)

    -- pagination
    for page in string.gmatch(html, "/forum/update%?[^\"]+") do
      page = string.gsub(page, "&amp;", "&")
      table.insert(urls, { url=("http://community.webshots.com"..page), link_expect_html=1 })
    end
  end

  -- album
  local base = string.match(url, "^(http://[^.]+%.webshots%.com/album/[a-zA-Z0-9]+)")
  if base then
    local html = read_file(file)

    -- pagination
    for start in string.gmatch(html, "%?start=(%d+)") do
      table.insert(urls, { url=(base.."?start="..start), link_expect_html=1 })
    end

    -- all comments are visible, no pagination

    -- photos
    for photo_url in string.gmatch(html, "http://[^\"/]+/photo/[a-zA-Z0-9]+") do
      table.insert(urls, { url=(photo_url), link_expect_html=1 })
      local photo_id = string.match(photo_url, "[^/]+$")
      if not photos[photo_id] then
        photo_count = photo_count + 1
        photos[photo_id] = true
      end
    end

    -- videos
    for video_url in string.gmatch(html, "http://[^\"/]+/video/[a-zA-Z0-9]+") do
      table.insert(urls, { url=(video_url), link_expect_html=1 })
      local video_id = string.match(video_url, "[^/]+$")
      if not videos[video_id] then
        video_count = video_count + 1
        videos[video_id] = true
      end
    end

    print_stats()
  end

  -- photo
  local photo_id = string.match(url, "^http://[^.]+%.webshots%.com/photo/([a-zA-Z0-9]+)$")
  if photo_id then
    local html = read_file(file)

    -- all comments are visible, no pagination

    -- full size
    table.insert(urls, { url=("http://community.webshots.com/photo/fullsize/"..photo_id), link_expect_html=1 })

    -- image
    local image_url = string.match(html, "src=(http://image[^ \"]+)\_ph%.jpg")
    if image_url then
      table.insert(urls, { url=(image_url.."_ph.jpg") })
      table.insert(urls, { url=(image_url.."_fs.jpg") })
    end

    -- other sizes
    local other_sizes_url = string.match(html, "/inlinePhoto%?[^\"]+")
    if other_sizes_url then
      other_sizes_url = string.gsub(other_sizes_url, "&amp;", "&")
      table.insert(urls, { url=("http://community.webshots.com"..other_sizes_url), link_expect_html=1 })
    end
  end

  -- other sizes
  local photo_id = string.match(url, "^http://[^.]+%.webshots%.com/inlinePhoto%?photoId=([a-zA-Z0-9]+)")
  if photo_id then
-- INLINEAPI.WEBSHOTS.COM is out of order

--  -- contact the inlinePhoto api
--  local photo_sizes = { 100, 200, 425, 500, 600 }
--  for i, s in ipairs(photo_sizes) do
--    table.insert(urls, { url=("http://inlineapi.webshots.com/inlinePhoto?tab="..s.."&photoId="..photo_id.."&maxX="..s.."&maxY="..s.."&fitType=shrink&quality=85") })
--  end
  end

  -- other sizes, inline api
  local base = string.match(url, "^http://inlineapi%.webshots%.com/inlinePhoto")
  if base then
    local html = read_file(file)

    -- get the image
    local photo_url = string.match(html, "id: \"direct\", data: \"([^\"]+)\"")
    if photo_url then
      table.insert(urls, { url=(photo_url) })
    end
  end

  -- video
  local video_id = string.match(url, "^http://[^.]+%.webshots%.com/video/([a-zA-Z0-9]+)$")
  if video_id then
    local html = read_file(file)

    -- all comments are visible, no pagination

    -- video
    local video_url, still_url, inline_photo_url = string.match(html, "writeFlashVideo%(\"([^\"]+)\", \"([^\"]+)\", \"([^\"]+)\"")
    if video_url then
      table.insert(urls, { url=video_url })
    end
    if still_url then
      table.insert(urls, { url=still_url })
    end
    if inline_photo_url then
      table.insert(urls, { url=inline_photo_url, link_expect_html=1 })
    end
  end

  -- video thumbnails
  local base = string.match(url, "^(http://videothumb%d+%.webshots%.com/.+_)%d%d%d_%d%.jpg$")
  if base then
    table.insert(urls, { url=(base.."001_0.jpg") })
    table.insert(urls, { url=(base.."002_0.jpg") })
    table.insert(urls, { url=(base.."003_0.jpg") })
    table.insert(urls, { url=(base.."004_0.jpg") })
  end

  return urls
end

