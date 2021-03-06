local dirurls = 'abcdefghijklmnopqrstuvwxyz'

function GetDirectoryPageNumber()
	page = dirurls:len()
	return no_error
end

function GetNameAndLink()
	local i = (tonumber(url) or 0) + 1
	if http.get(module.rooturl..'/manga-list/'..dirurls:sub(i, i)) then
	    TXQuery.create(http.document).xpathhrefall('//*[@class="manga-item"]//a', links, names)
		return no_error
	else
		return net_problem
	end
end

function GetInfo()
	mangainfo.url = MaybeFillHost(module.rooturl, url)
	if http.get(mangainfo.url) then
		local x = TXQuery.create(http.document)
		
		mangainfo.coverlink = x.xpathstring('//*[@class="panel-body"]//img/@src')
		mangainfo.title     = x.xpathstring('//h1')
		mangainfo.authors   = x.xpathstring('//li[.="Author"]/preceding-sibling::li')
		mangainfo.artists   = x.xpathstring('//li[.="Artist"]/preceding-sibling::li')
		mangainfo.genres    = x.xpathstring('//*[@class="dl-horizontal"]/dt[starts-with(.,"Categories")]/following-sibling::dd[1]/string-join(*,", ")')
		mangainfo.summary   = x.xpathstring('//*[contains(@class,"movie-detail")]')
		mangainfo.status    = MangaInfoStatusIfPos(x.xpathstring('//*[@class="dl-horizontal"]/dt[starts-with(.,"Status")]/following-sibling::dd[1]'))
		
		local v, vi, i = x.XPath('//ul[@class="chp_lst"]/li/a')
		for i = 1, v.count do
			vi = v.get(i)
			mangainfo.chapterlinks.add(vi.getattribute('href'))
			mangainfo.chapternames.add(x.xpathstring('span[1]',vi))
		end
		InvertStrings(mangainfo.chapterlinks, mangainfo.chapternames)
		return no_error
	else
		return net_problem
	end
end

function GetPageNumber()
	task.pagelinks.clear()
	task.pagenumber = 0
	local u = MaybeFillHost(module.rooturl, url)
	if not string.find(u:lower(), '/all%-pages') then
		u = AppendURLDelim(u)..'all-pages'
	end
	if http.get(u) then
		TXQuery.Create(http.document).xpathstringAll('//*[contains(@class,"content-list")]//img/@src', task.pagelinks)
		return true
	else
		return false
	end
end

function Init()
	m=NewModule()
	m.Website                    = 'ReadMangaToday'
	m.RootURL                    = 'https://www.readmng.com'
	m.Category                   = 'English'
	m.OnGetDirectoryPageNumber   = 'GetDirectoryPageNumber'
	m.OnGetNameAndLink           = 'GetNameAndLink'
	m.OnGetInfo                  = 'GetInfo'
	m.OnGetPageNumber            = 'GetPageNumber'
end
