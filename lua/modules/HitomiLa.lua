local domain = 'hitomi.la'

function set_https(s)
  if s:match('^//') then
    return 'https:' .. s
  else
    return s
  end
end

function getinfo()
	mangainfo.url=MaybeFillHost(module.RootURL, url)
	if not http.get(mangainfo.url) then return net_problem end
	local x=TXQuery.create(http.document)
	if x.xpathstring('//title'):lower()=='redirect' then
		if http.get(x.xpathstring('//a/@href')) then
			x.parsehtml(http.document)
		else return net_problem end
	end
	mangainfo.title = x.xpathstring('//div[starts-with(@class,"gallery")]/h1')
	mangainfo.coverlink=MaybeFillHost(module.rooturl, x.xpathstring('//div[@class="cover"]//img/@src'))
	mangainfo.coverlink = set_https(mangainfo.coverlink)
	mangainfo.authors=x.xpathstringall('//div[starts-with(@class,"gallery")]/h2/ul/li/a')
	mangainfo.genres=x.xpathstringall('//div[@class="gallery-info"]/table//tr/td//a')
	mangainfo.chapterlinks.add(x.xpathstring('//div[contains(@class,"cover-column")]/a/@href'))
	mangainfo.chapternames.add(mangainfo.title)
	return no_error
end

----------------------------------------------------------------------------------------------
--  direct translaton of https://ltn.hitomi.la/common.js and https://ltn.hitomi.la/reader.js

local adapose = false

function subdomain_from_galleryid(g, number_of_frontends)
        if (adapose) then
                return '0'
        end
        local o = g % number_of_frontends

		return string.char(97 + o)
end

function subdomain_from_url(url, base)
        local retval = 'a'
        if (base) then
                retval = base
        end
        
        local number_of_frontends = 3
        local b = 16
        
        local r = '^.*/[0-9a-f]/([0-9a-f]{2})/.*$'
        local m = re.replace(r,url,'$1')
        if not(m) then
                return retval
        end
        
        local g = tonumber(m, b) or nil
        if g then
                if (g < 0x30) then
                        number_of_frontends = 2
                end
                if (g < 0x09) then
                        g = 1
                end
                retval = subdomain_from_galleryid(g, number_of_frontends) .. retval
        end
        
        return retval
end

function url_from_url(url, base)
		return re.replace('//..?\\.hitomi\\.la/', url, '//'..subdomain_from_url(url, base)..'.hitomi.la/')
end


function full_path_from_hash(hash)
        if (hash:len() < 3) then
                return hash
        end
        return re.replace('^.*(..)(.)$', hash, '$2/$1/'..hash)
end


function url_from_hash(galleryid, image, dir, ext)
		ext = ext or dir or image.name:match('%.(.+)')
        dir = dir or 'images'
        
        return 'https://a.hitomi.la/'..dir..'/'..full_path_from_hash(image.hash)..'.'..ext
end

function url_from_url_from_hash(galleryid, image, dir, ext, base) 
        return url_from_url(url_from_hash(galleryid, image, dir, ext), base)
end

function image_url_from_image(galleryid, image, no_webp)
        local webp
        if (image['hash'] and image['haswebp'] and not(no_webp)) then
                webp = 'webp'
        end
        
        return url_from_url_from_hash(galleryid, image, webp)
end

-- end of https://ltn.hitomi.la/common.js
----------------------------------------------------------------------------------------------

function getpagenumber()  
	if http.get(MaybeFillHost(module.rooturl, url)) then
		x=TXQuery.Create(http.document)
		local galleryid=x.xpathstring('//script[contains(.,"var galleryid")]'):match('=%s*(%d+)') or ''
		local gallery_url=set_https(x.xpathstring('//script[contains(@src,"/galleries/")]/@src') or '')
		if gallery_url and http.get(gallery_url) then
			local no_webp=not module.GetOption('download_webp')
			local s=StreamToString(http.document):match('(%[.+%])')
			x.parsehtml(s)
			local v=x.xpath('json(*)()')
			local image={}
			local vi
			for i=1, v.count do
				vi=v.get(i)
				image.hash=x.xpathstring('./hash',vi)
				image.haswebp=x.xpathstring('./haswebp',vi)=='1'
				image.name=x.xpathstring('./name',vi)
				image.hasavif=x.xpathstring('./hasavif',vi)=='1'
				task.pagelinks.add(image_url_from_image(galleryid, image, no_webp))
			end
		end
	else
		return false
	end
	return true
end

function BeforeDownloadImage()
  http.headers.values['Pragma'] = 'no-cache'
  http.headers.values['Cache-Control'] = 'no-cache'
  http.headers.values['Referer'] = MaybeFillHost(module.rooturl, url)
  return true
end

function getnameandlink()
  if http.get(module.rooturl) then
    local x = TXQuery.Create(http.Document)
    if http.get('https://ltn.'..domain..'/index-all.nozomi') then
      local s = StreamToString(http.document)
      for i=1,s:len(),4 do
        local b1,b2,b3,b4=s:byte(i),s:byte(i+1),s:byte(i+2),s:byte(i+3)
        local n = b4 + (b3 << 8) + (b2 << 16) + (b1 << 24)
        links.add('https://'..domain..'/galleries/'..n..'.html')
        names.add(n)
      end
      return no_error
    end
  end
  return net_problem
end

function Init()
  local m = NewModule()
  m.website = 'HitomiLa'
  m.rooturl = 'https://'..domain
  m.category = 'H-Sites'
  m.ongetinfo='getinfo'
  m.ongetpagenumber='getpagenumber'
  m.ongetnameandlink='getnameandlink'
  m.OnBeforeDownloadImage = 'BeforeDownloadImage'
  m.AddOptionCheckBox('download_webp', 'Download WebP', true)
end