
read_file = function(file)
  local f = io.open(file)
  local data = f:read("*all")
  f:close()
  return data
end

url_count = 0
album_count = 0
photo_count = 0

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  -- progress message
  url_count = url_count + 1
  if url_count % 50 == 0 then
    print(" - Downloaded "..url_count.." URLs")
  end

  -- user page (album list)
  local base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+)[^/]*$")
  if base then
    local html = read_file(file)

    if base == url then
      print(" + User profile loaded.")
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
    for album_url in string.gmatch(html, "http://[^\"/]+/album/[^\"#/]+") do
      table.insert(urls, { url=(album_url), link_expect_html=1 })
      album_count = album_count + 1
    end

    if album_count == 1 then
      print(" + Found "..album_count.." album so far")
    else
      print(" + Found "..album_count.." albums so far")
    end
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
      photo_count = photo_count + 1
    end

    if photo_count == 1 then
      print(" + Found "..photo_count.." photo so far")
    else
      print(" + Found "..photo_count.." photos so far")
    end
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
    table.insert(urls, { url=(image_url.."_ph.jpg") })
    table.insert(urls, { url=(image_url.."_fs.jpg") })

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
    -- contact the inlinePhoto api
    local photo_sizes = { 100, 200, 425, 500, 600 }
    for i, s in ipairs(photo_sizes) do
      table.insert(urls, { url=("http://inlineapi.webshots.com/inlinePhoto?tab="..s.."&photoId="..photo_id.."&maxX="..s.."&maxY="..s.."&fitType=shrink&quality=85") })
    end
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

  return urls
end

