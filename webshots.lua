
read_file = function(file)
  local f = io.open(file)
  local data = f:read("*all")
  f:close()
  return data
end

url_count = 0

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}

  -- progress message
  url_count = url_count + 1
  if url_count % 25 == 0 then
    print(" - Downloaded "..url_count.." URLs")
  end

  -- user page (album list)
  base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+)[^/]*$")
  if base then
    html = read_file(file)

    -- the tab pages
    table.insert(urls, { url=(base.."/profile"), link_expect_html=1 })
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
    end
  end

  -- people
  base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+/people)")
  if base then
    html = read_file(file)

    -- pagination
    for list, sort, start in string.gmatch(html, "people%?list=([^&]+)&amp;sort=(recent%-activity)&amp;start=(%d+)") do
      table.insert(urls, { url=(base.."?list="..list.."&sort="..sort.."&start="..start), link_expect_html=1 })
    end
  end

  -- bookmarks
  base = string.match(url, "^(http://community%.webshots%.com/user/[^?/]+/bookmarks)")
  if base then
    html = read_file(file)

    -- pagination
    for start in string.gmatch(html, "%?start=(%d+)") do
      table.insert(urls, { url=(base.."?start="..start), link_expect_html=1 })
    end
  end

  -- tags : won't do

  -- messages : TODO

  -- album
  base = string.match(url, "^(http://[^.]+.webshots%.com/album/[a-zA-Z0-9]+)")
  if base then
    html = read_file(file)

    -- pagination
    for start in string.gmatch(html, "%?start=(%d+)") do
      table.insert(urls, { url=(base.."?start="..start), link_expect_html=1 })
    end

    -- all comments are visible, no pagination

    -- photos
    for photo_url in string.gmatch(html, "http://[^\"/]+/photo/[a-zA-Z0-9]+") do
      table.insert(urls, { url=(photo_url), link_expect_html=1 })
    end
  end

  -- photo
  photo_id = string.match(url, "^http://[^.]+.webshots%.com/photo/([a-zA-Z0-9]+)$")
  if photo_id then
    html = read_file(file)

    -- all comments are visible, no pagination

    -- full size
    table.insert(urls, { url=("http://community.webshots.com/photo/fullsize/"..photo_id), link_expect_html=1 })

    -- image
    image_url = string.match(html, "src=(http://image[^ \"]+)\_ph%.jpg")
    table.insert(urls, { url=(image_url.."_ph.jpg") })
    table.insert(urls, { url=(image_url.."_fs.jpg") })

    -- other sizes : TODO
  end

  return urls
end

