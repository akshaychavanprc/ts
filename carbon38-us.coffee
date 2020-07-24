exports = module.exports = {}

try
	# require('coffee-script')
	# shared = require('./shared')
	# HashMap = require('hashmap')
	fs = require('fs')
	shared = require('/opt/goldrush-worker/shared')
	HashMap = require('hashmap')
catch e
	console.error e.message, if e.code == 'MODULE_NOT_FOUND' then 'please install it (npm install module_name)' else ''
	process.exit e.code

urlList = {}		# URL List for Deep URL List
totalHash = new HashMap()
isListReady = true	# List ready for Deep URL List
all_urls=[]

# //____________________________________________________________________________________
# development enviromnet
isDevelopment = true
# //____________________________________________________________________________________
# /**
#  * @desc This function will scrape the product url and call shared.addProductDetailsToDatabase
#  * ***** If the product exist we just add sku history if there is a change in price or stock.
#  * @param URLs list URL's obtained from redis key web site url.
#  * @return data saved in mysql.
#  */
exports.scrapeTheProducts = (URLs, md5_file_name, done) ->
	deferred = shared.q.defer()
	base_url=shared.retailer.retailer_website_url.replace(/\/$/ig,'')
	index1 = 0
	isEmptyObject = (obj) ->
		!Object.keys(obj).length
	#Establishing Redis Connection
	common_client = shared.redis.createClient(shared.common_redisConfig.port, shared.common_redisConfig.IP)
	common_client.on 'error', (err) ->
		return
	getProductDetailsFromRedis = (url,doneCallback) ->
		setTimeout (->
			#To get content of md5_file_name from redis
			# shared.getmd5(md5_file_name).then((data) ->
			shared.getmd5(md5_file_name,shared.retailer.retailer_code).then((data) ->
				console.log md5_file_name+' :: '+url
				unless(data)
					doneCallback(null, null)
					return
				if data
					data=data.replace(/\\r|\\n|\\t|\\||\//ig,'')
					details =
						product: {}
						skuHistory: {}
						colors:{}
						images: {}
						product_categories: {}
						product_facet: {}
						retailer_locale_id:false
						taxonomies: []
						md5_files:[]
					$ = shared.cheerio.load(data)
					if !($('[name="product_id"]').attr('value'))
						doneCallback(null, null)
						return
					if (data.match(/_pa\.productId\s*\=\s*\"([^>]*?)\"/i))
						productCode=data.match(/_pa\.productId\s*\=\s*\"([^>]*?)\"/i)[1]
					else
						productCode = $('[name="product_id"]').attr('value')
					productCode=productCode.trim()
					if !(productCode)
						doneCallback(null, null)
						return
					if (data.match(/addProduct[\w\W]*?\'name\'\s*\:\s*\"([^>]*?)\"\,\s*\'category\'/i))
						productName=data.match(/addProduct[\w\W]*?\'name\'\s*\:\s*\"([^>]*?)\"\,\s*\'category\'/i)[1]
					else
						#productName=data.match(/dataLayerProduct[\w\W]*?\"name\"\s*\:\s*\"([^>]*?)\"/i)[1]
						productName=data.match(/product-data-layer[\w\W]*?\"name\"\s*\:\s*\"([^>]*?)\"/i)[1]
					productName=productName.replace(/\\/ig,'')
					if !(productName)
						doneCallback(null, null)
						return
					default_image_url=$('[property="og:image"]').eq(0).attr("content")
					unless(default_image_url)
						default_image_url=$('[class="product-images"] li a').eq(0).attr("href")
					prod_detail=""
					productDescription=""
					if $('[itemprop="description"]').attr('content')
						productDescription=$('[itemprop="description"]').attr('content')
					else if(data.match(/<div[^>]*?class="pdp_tab_title"[^>]*?>\s*PRODUCT[^>*?]DETAILS\s*<\/div>\s*([\w\W]*?)\s*<\/div>/i))
						productDescription = data.match(/<div[^>]*?class="pdp_tab_title"[^>]*?>\s*PRODUCT[^>*?]DETAILS\s*<\/div>\s*([\w\W]*?)\s*<\/div>/i)[1]
					productDescription=productDescription.replace(/<[^>]*?>/ig,' ')
					productDescription=productDescription.replace(/\s+/ig,' ')
					productDescription=productDescription.replace(/^\s*|\s*$/ig,'')
					productDescription=shared.entities.decodeHTML(productDescription)
					if($('[class="info"] [class="info-item js_tabs_container"]').eq(1).html())
						prod_detail=$('[class="info"] [class="info-item js_tabs_container"]').eq(1).html()
						prod_detail=prod_detail.replace(/<[^>]*?>/ig,' ')
						prod_detail=prod_detail.replace(/\s+/ig,' ')
						prod_detail=shared.entities.decodeHTML(prod_detail)
					else if(data.match(/<div[^>]*?class="pdp_tab_title"[^>]*?>\s*FABRIC[^>]*?CARE\s*<\/div>\s*([\w\W]*?)\s*<\/div>/i))
						prod_detail=data.match(/<div[^>]*?class="pdp_tab_title"[^>]*?>\s*FABRIC[^>]*?CARE\s*<\/div>\s*([\w\W]*?)\s*<\/div>/i)[1]
						prod_detail=prod_detail.replace(/<[^>]*?>/ig,' ')
						prod_detail=prod_detail.replace(/\s+/ig,' ')
						prod_detail=prod_detail.replace(/^\s*|\s*$/ig,'')
						prod_detail=shared.entities.decodeHTML(prod_detail)
					if(productDesciption=='')
						productDesciption=$('[class="product attribute description"] div p').text()
					if(prod_detail=='')
						prod_detail=$('[class="pdp_tab_box"]').text()
					brand=""
					if (data.match(/addProduct[\w\W]*?\'brand\'\s*\:\s*\"([^>]*?)\"/i))
						brand=data.match(/addProduct[\w\W]*?\'brand\'\s*\:\s*\"([^>]*?)\"/i)[1]
					else
						brand=$('[class="brand"] span').text()
					priceNow=''
					priceWas=''
					if ($('[class="pdp_price"] [class="price"] [class="old-price"]').html())
						priceNow = $('[class="pdp_price"] [class="price"]').text().trim().replace(/\s*\([^>]*?\)$/ig,'').trim()
						priceWas = $('[class="pdp_price"] [class="price"] [class="old-price"]').text().trim().replace(/\(/ig,'').replace(/\)/ig,'').trim()
						pricetext = $('[class="pdp_price"] [class="price"]').text().trim().replace(/\s+/ig,' ')
					else if ($('[class="pdp_info"] [class="price sale-price"]').text().trim())
						priceNow = $('[class="pdp_info"] [class="price sale-price"]').text().trim().replace(/\s*\([^>]*?\)\s*$/ig,'')
						priceWas = $('[class="pdp_info"] [class="price sale-price"]').text().trim().replace(/^\s*[^>]*?\s*\(/ig,'').replace(/\)\s*$/ig,'')
						pricetext = $('[class="pdp_info"] [class="price sale-price"]').text().trim().replace(/\s+/ig,' ')
					else
						#priceNow = $('[class="pdp_price"] [class="price"]').text().trim().replace(/\s*\([^>]*?\)$/ig,'').trim()
						priceNow = $('[class="product-info-price"] [class="price price-world"]').text().trim().replace(/\s*\([^>]*?\)$/ig,'').trim()
						priceWas = priceNow
						#pricetext = $('[class="pdp_price"] [class="price"]').text().trim().replace(/\s+/ig,' ')
						pricetext = $('[class="product-info-price"] [class="price price-world"]').text().trim().replace(/\s+/ig,' ')
					details.priceNow = priceNow
					details.priceWas = priceWas
					details['price_text'] = pricetext
					details.product['product_gold_key'] = productCode
					details.product['retailer_id'] = shared.retailer.retailer_id
					details.product['product_url'] = url
					details.product['name'] = productName
					details.product['description_overview'] = productDescription
					details.product['description_details'] = prod_detail
					details.product['brand'] = brand
					details.product['image_filename'] = default_image_url
					details['isStyleMerging'] = 'NO'
					details['delete_md5'] = true
					color=$('[class="prodColorList_item active"]').attr('data-color')
					unless(color)
						color = $('[class="product_color_title"] > span.current').text()
					# SKU collected
					sku=''
					size =''
					if ($('[class="swatch-attribute size"] [class="swatch-attribute-options clearfix"] div').html())
						$('[class="swatch-attribute size"] [class="swatch-attribute-options clearfix"] div').each (indx,el) ->
							size = $(el).attr('aria-label')
							unless(size)
								size = 'No Size'
							unless(color)
								color = 'No Raw Color'
							stock=true
							stock_info=$(el).attr('class')
							if (stock_info.match(/disabled/i))
								stock=false
							console.log "--- 11 color :: "+color+" -- size :: "+size+" -- stock :: "+stock+" -- priceNow :: "+priceNow+" -- priceWas :: "+priceWas
							details.skuHistory[index1] = [
								sku
								entities = [
									["color", color],
									["size" , size]
								]
								images =
									large: default_image_url
								priceNow
								priceWas
								stock
							]
							index1++
					else
						size = 'No Size'
						unless(color)
							color = 'No Raw Color'
						stock=true
						# console.log "--- 22 color :: "+color+" -- size :: "+size+" -- stock :: "+stock+" -- priceNow :: "+priceNow+" -- priceWas :: "+priceWas
						details.skuHistory[index1] = [
							sku
							entities = [
								["color", color],
								["size" , size]
							]
							images =
								large: default_image_url
							priceNow
							priceWas
							stock
						]
						index1++
					details.index=index1
					deferred.resolve details
					deferred.promise
				else
					shared.errorLogger 'Error ' + url
					doneCallback(null, null)
			)
			.then(shared.addProductDetailsToDatabase)
			.then(doneCallback)
		), 2000
		return

	shared.async.map URLs, getProductDetailsFromRedis, (err, results) ->
		if(results[0] == null)
			done(new Error('collection failed'))
			common_client.quit()
		else
			common_client.quit()
			done()

		deferred.resolve 'done'
		return
	deferred.promise

# //____________________________________________________________________________________
# /**
#  * @desc This function will scan all products URLs for each category; add them in redis
#  * @param URL list from facets function
#  * @return redis keys ( product url ) each key values are facets, categories.
# @getProductsFromRedis: This function  will push all url into common redis
exports.getProductsFromRedis = ->
	#Create a promise
	deferred = shared.q.defer()
	retailerCode = @retailerCode
	setTimeout (->
		#ip,process_id and retailer group name are  assigned into JSON object.
		machine_detail={}
		machine_detail['IP']=shared.ip.address()
		machine_detail['retailer_group_name']=shared.retailer.retailer_group_name
		machine_detail['Type']="HTML"
		machine_detail['URL']="PRODUCT"
		machine_detail['Lable']="detail"
		#Establishing local Redis Connection
		# client = shared.redis.createClient(shared.redisConfig.port, shared.redisConfig.IP)
		shared.client.on 'error', (err) ->
			deferred.resolve false
			shared.errorLogger 'Error ' + err
			process.exit 0
			return
		#Establishing common Redis Connection
		# common_client = shared.redis.createClient(shared.common_redisConfig.port, shared.common_redisConfig.IP)
		shared.common_client.on 'error', (err) ->
			deferred.resolve false
			shared.errorLogger 'Error ' + err
			process.exit 0
			return
		shared.client.set "list_status","Completed"
		shared.client.set "detail_status","Running"
		shared.client.smembers retailerCode, (err, result) ->
			shared.client.set("job_count",result.length)
			shared.common_client.select 1, (err) ->
				result.forEach (url) ->
					#product url is assigned into JSON object.
					shared.auth['url']=url
					shared.auth['proxy']=shared.retailer.proxy_detail
					shared.auth['headers']['Host']="www.carbon38.com"
					shared.auth['headers']['Accept']="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
					shared.auth['headers']['Accept-Encoding']="gzip, deflate, br"
					shared.auth['headers']['Accept-Language']="en-US,en;q=0.5"
					shared.auth['headers']['Connection']="keep-alive"
					auth_string=JSON.stringify(shared.auth)
					machine_detail_string=JSON.stringify(machine_detail)
					push_string=auth_string + shared.splitter + machine_detail_string
					#will push product_url to common redis
					shared.common_client.lpush retailerCode, push_string

				# client.quit()
				# common_client.quit()
				deferred.resolve result
				return
	), 3000
	deferred.promise

# //____________________________________________________________________________________
# /**
#  * @desc This function will scan all products URLs for each category; add them in redis
#  * @param URL list from facets function
#  * @return redis keys ( product url ) each key values are facets, categories.
count=0
all_AddProductsToRedis = (url,tags,q) ->
	# console.log "tags :"+tags
	# console.log "url :"+url
	if(url)
		delete(shared.auth['headers']['Content_Type'])
		shared.auth['headers']['authority']="www.carbon38.com"
		shared.auth['headers']['scheme']="https"
		shared.auth['headers']['Host']="www.carbon38.com"
		shared.auth['headers']['User-Agent']="Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.108 Safari/537.36"
		shared.auth['headers']['Accept']="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"
		shared.auth['headers']['Accept-Language']="en-US,en;q=0.9"
		shared.auth['headers']['Accept-Encoding']="gzip, deflate, br"
		shared.auth['headers']['sec-fetch-mode']="navigate"
		shared.auth['headers']['sec-fetch-site']="none"
		shared.download_new url,0,'list','IPROTATE',shared.retailer.retailer_code,false, (Data) ->
			if (Data)
				$ = shared.cheerio.load(Data)
				$('.product-item-link').each (index,el) ->
					productUrl1 = $(el).eq(0).attr('href')
					product_name = $(el).eq(0).text()
					if(productUrl1)
						unless(productUrl1.match(/http/i))
							productUrl1="https://www.carbon38.com" + productUrl1
						productUrl1 = productUrl1.match(/^\s*([^>]*?)\?/i)[1]
						pids = productUrl1
						if(totalHash.get(pids))
							productUrl=totalHash.get(pids)
						else
							productUrl=productUrl1
							totalHash.set(pids,productUrl)
							count++;
							# console.log "count :"+count
							product_name_object=JSON.stringify({"name":product_name,"product_url":productUrl})
							shared.client.sadd shared.retailer.retailer_code+"-name" , product_name_object, shared.redis.print

							shared.client.sadd shared.retailer.retailer_code , productUrl, shared.redis.print
							shared.client.incr "list_count"
						shared.client.sadd productUrl, tags, shared.redis.print
				next_page_url=''
				if($('[class="item pages-item-next"] a').eq(0).attr('href'))
					next_page_no="?p="+$('[class="item pages-item-next"] a').eq(0).attr('href')+"&dir=asc"
					if(url.match(/\?p\=\d+\&dir\=asc/i))
						next_page_url=url.replace(/\?p\=\d+\&dir\=asc/ig,next_page_no)
					else
						next_page_url = url+next_page_no
					all_urls[next_page_url]=tags
					q.push next_page_url,(err) ->

exports.addProductsToRedis = (Data) ->
	deferred = shared.q.defer()
	instance=Object.keys(all_urls).length
	sleep=shared.retailer.retailer_list_control_time/instance
	q = shared.async.cargo(((task, callback) ->
		task.forEach (tags) ->
			all_AddProductsToRedis(tags,all_urls[tags],q)
		callback()
	),1)
	#clears the queue finally
	q.drain = ->
		shared.client.set "7days_url",(shared.retailer.old_urls_list).length
		shared.retailer.old_urls_list.forEach (yesterday_url) ->
			#will push product_url to common redis
			shared.client.sadd shared.retailer.retailer_code ,yesterday_url, shared.redis.print
			# shared.common_client.lpush retailerCode, push_string
			tag_str='CATEGORY' + shared.splitter + 'menu_1=last 7 dayurl'
			shared.client.sadd yesterday_url, tag_str, shared.redis.print

		setTimeout (->
			deferred.resolve 'done'
			return
		), 30000
		return

	# pushes each element inside queue for process
	q.push Object.keys(all_urls),(err) ->

	q.saturated = ->  # once reaches the payload q.saturated is called to delay next set of values to process
		q.pause()
		setTimeout (->
		  q.resume()
		  return
		), 3000
	deferred.promise


# * getFacetsUrls, getDeepUrls methods are defined with no functionality as the retailer
# * website does not have deeper navigation categories and facets.
# * @param {array} urlList ; keys are main, subsection names and values are subsection's json url. Returns the same value.

exports.getFacetsUrls = ->
	deferred = shared.q.defer()
	deferred.resolve all_urls
	deferred.promise

# /*******************************************************************************************************************
#  * @desc this function will return third level urls of the main sections i.e sub-sections of Clothing,Accessories, etc.
#  * @param {array} list ; keys are main section name, value is the main section url
#  * @return {array} list of all deep level urls of the main sections and what ever if they ...
#  * have sub sections or not default is true; till we go into deep download function
#  * urlList array will feed getDeepURLs
#  */

exports.getDeepUrls = (urlList) ->
	deferred = shared.q.defer()
	index = 0
	markets_to_skip=shared.retailer.markets_to_skip.join('|').toLowerCase().split('|')
	getChilds = (section, doneCallback) ->
		getMoreChilds = (subSection, subDoneCallback) ->
			if urlList[@mainSection][subSection][1] == false
				return subDoneCallback(null, 1)
			index++
			setTimeout ((mainSection) ->
				childData = urlList[mainSection][subSection]
				listtest = []
				index1 = 0
				childData = childData.toString()
				delete urlList[mainSection][subSection]
				if childData
					$ = shared.cheerio.load(childData)
					getDeepUrls3 = (el2, DeepdoneCallback3) ->
						menu_3 = "menu_3="+$(el2).text().trim()
						menu_3_url = $(el2).attr('href')
						unless(menu_3_url.match(/http/i))
							menu_3_url="https://www.carbon38.com"+menu_3_url
						skip_string = (mainSection + shared.splitter + subSection + shared.splitter + menu_3).toLowerCase()
						skip_string=skip_string.replace(/menu_[\d]+\=/ig,"")
						unless(skip_string in markets_to_skip)
						# if(menu_3.match(/menu_3\=TOPS/i))
							# console.log "1=> skip_string :"+skip_string
							shared.auth['headers']['Host']="www.carbon38.com"
							shared.auth['headers']['Accept']="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
							shared.auth['headers']['Accept-Encoding']="gzip, deflate, br"
							shared.auth['headers']['Accept-Language']="en-US,en;q=0.5"
							shared.auth['headers']['Connection']="keep-alive"
							shared.download_new menu_3_url,0,'list','IPROTATE',shared.retailer.retailer_code,false, (Data) ->
								$ = shared.cheerio.load(Data)
								setTimeout (->
									getDeepUrls4 = (el3, DeepdoneCallback4) ->
										menu_4 = "menu_4="+$(el3).text().trim()
										menu_4_url = $(el3).attr('href')
										unless(menu_4_url.match(/http/i))
											menu_4_url="https://www.carbon38.com"+menu_4_url
										skip_string = (mainSection + shared.splitter + subSection + shared.splitter + menu_3 + shared.splitter + menu_4).toLowerCase()
										skip_string=skip_string.replace(/menu_[\d]+\=/ig,"")
										unless(skip_string in markets_to_skip)
										# if(menu_4.match(/menu_4\=Sweatshirts/i))
											# console.log "2=> skip_string :"+skip_string
											shared.auth['headers']['Host']="www.carbon38.com"
											shared.auth['headers']['Accept']="text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
											shared.auth['headers']['Accept-Encoding']="gzip, deflate, br"
											shared.auth['headers']['Accept-Language']="en-US,en;q=0.5"
											shared.auth['headers']['Connection']="keep-alive"
											shared.download_new menu_4_url,0,'list','IPROTATE',shared.retailer.retailer_code,false, (Data1) ->
												$ = shared.cheerio.load(Data1)
												tag='CATEGORY' + shared.splitter+mainSection+","+subSection+","+menu_3+","+menu_4
												all_urls[menu_4_url]=tag
												setTimeout (->
													if ($('.filter-options-title').text())
														getFacetUrls1 = (el, FacetdoneCallback1) ->
															facetName=$(el).text().trim().toLowerCase()
															if !(facetName==undefined | facetName==null | facetName=='')
																if !(facetName.match(/size|Price|^\s*$|designer|item\s*type/ig))
																	content=$(el).next()
																	getFacetUrls2 = (el1, FacetdoneCallback2) ->
																		facetVal=$(el1).eq(0).text().trim().toLowerCase()
																		if!(facetVal)
																			facetVal=$(el1).find('span').attr('data-color').trim().toLowerCase()
																		if !(facetVal==undefined | facetVal==null | facetVal=='')
																			if ($(el1).find('input').attr('value'))
																				facetUrl=$(el1).find('input').attr('value')
																			else if($(el1).find('a').attr('value'))
																				facetUrl=$(el1).find('a').attr('value')
																			else
																				facetUrl=$(el1).find('span').attr('value')
																			facetUrl=menu_4_url+"?p=1&dir=asc&order=position&limit=all&"+facetName+"="+facetUrl
																			colorVal = facetName+'='+facetVal
																			tag='CATEGORY' + shared.splitter+mainSection+","+subSection+","+menu_3+","+menu_4+","+colorVal
																			all_urls[facetUrl]=tag
																			FacetdoneCallback2(null,null)
																		else
																			FacetdoneCallback2(null,null)

																	shared.async.mapSeries $(content).find('label'), getFacetUrls2, (err, results) ->
																		FacetdoneCallback1(null, null)
																else
																	return FacetdoneCallback1(null,null)
															else
																return FacetdoneCallback1(null,null)
														shared.async.mapSeries $('.filter-options-title'), getFacetUrls1, (err, results) ->
															return DeepdoneCallback4(null,null)
													else
														tag='CATEGORY' + shared.splitter+mainSection+","+subSection+","+menu_3+","+menu_4
														all_urls[menu_4_url]=tag
														return DeepdoneCallback4(null,null)
												), 3000, @mainSection
										else
											return DeepdoneCallback4(null,null)
									shared.async.mapSeries $('.navigationSubmenu__item_normal a'), getDeepUrls4, (err, results) ->
										return DeepdoneCallback3(null,null)
								), 3000
						else
							return DeepdoneCallback3(null,null)
					shared.async.mapSeries $('[class="navigationSubmenu__item_bold"] a'), getDeepUrls3, (err, results) ->
						return subDoneCallback(null, null)
				else
					return subDoneCallback(null, null)

			# ), 100, @mainSection
			), 3000, @mainSection
			return

		shared.async.mapSeries Object.keys(urlList[section]), getMoreChilds.bind(mainSection: section), (err, results) ->
			doneCallback null, urlList[section]
		return

	shared.async.mapSeries Object.keys(urlList), getChilds, (err, results) ->
		deferred.resolve urlList
		return
	deferred.promise

# /***********************************************************************************
# This function will return URL for each category in women market.
# Ex: New Arrival, Clothing, Accessories and Outlet
# Param: {array} Category and URL
# return: {array} Subcategory values (new arival , clothing etc..) and its URLS

exports.getSecondLevelMenuUrls = (list) ->
	deferred = shared.q.defer()
	index = 0
	markets_to_skip=shared.retailer.markets_to_skip.join('|').toLowerCase().split('|')
	getChilds = (section, doneCallback) ->
		index++
		setTimeout (->
			url = list[section]
			urlList[section] = {}
			shared.download_new url,0,'list','IPROTATE',shared.retailer.retailer_code,false, (Data) ->
				if Data
					$ = shared.cheerio.load(Data)
					$('[class="navigationSubmenu"]').each (index,el) ->
						menu_2 =$(el).prev().text().trim().toLowerCase()
						menu_3_content = $(el).html()
						skip_string=(section + shared.splitter + menu_2).toLowerCase()
						skip_string=skip_string.replace(/menu_[\d]+\=/ig,"")
						unless(skip_string in markets_to_skip)
							urlList[section]["menu_2="+menu_2] = [menu_3_content]
						return

					doneCallback(null, urlList)
		# ), index * shared.timeout
		), 3000
		return

	urlList = {}

	shared.async.map Object.keys(list), getChilds, (err, results) ->
		deferred.resolve urlList
		return
	deferred.promise

# Setup retailer sets the markets to scrape as Women
# This method will collect only women list of URL

exports.getFirstLevelMenuUrls = (retailer) ->
	# Create a promise
	deferred = shared.q.defer()
	list = []
	retailer.markets_to_scrape.forEach (category) ->
		list["menu_1="+category] = retailer.retailer_scraper_url
		return
	deferred.resolve list
	deferred.promise
