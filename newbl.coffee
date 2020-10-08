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
JSON_data_sku={}

# //____________________________________________________________________________________
# development enviromnet
isDevelopment = true
# //____________________________________________________________________________________
# /**
#  * @desc This function will scrap the product url and call shared.addProductDetailsToDatabase
#  * ***** If the product exist we just add sku history if there is a change in price or stock.
#  * @param URLs list URL's obtained from redis key web site url.
#  * @return data saved in mysql.
#  */

# //_
#___________________________________________________________________________________
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
	#shared.auth['json']=true
	isEmptyObject = (obj) ->
		!Object.keys(obj).length
	#Establishing Redis Connection
	common_client = shared.redis.createClient(shared.common_redisConfig.port, shared.common_redisConfig.IP)
	common_client.on 'error', (err) ->
		return
	getProductDetailsFromRedis = (url,doneCallback) ->
		setTimeout (->
			#To get content of md5_file_name from redis
			shared.getmd5(md5_file_name,shared.retailer.retailer_code).then((data) ->
			# shared.getmd5(md5_file_name).then((data) ->
				unless(data)
					doneCallback(null, null)
					return
				if data
					details =
						product: {}
						skuHistory: {}
						colors:{}
						images: {}
						retailer_locale_id:false
						taxonomies: []
						md5_files:[]
					$ = shared.cheerio.load(data)
					#shared.auth['json']=true

					if(data.match(/<div\s*class\=\"status\-badge__message\s*\">\s*sold\s*out\s*<[^>]*?>/i))
						doneCallback(null, null)

					if($('.container.product-detail'))

						productCode = $('.container.product-detail').attr('data-pid')
					else
						if(data.match(/"queryString": "pid=(.*?)"/i))
							productCode=data.match(/"queryString": "pid=(.*?)"/i)[1]
						else
							doneCallback(null, null)

					productDescription=''
					prod_detail=''
					brand=''
					productName=''
					prod_detail = ''
					prod_detail1 = ''
					prod_detail2 = ''
					pricetext = ''

					if(data.match(/<title>\s*([^>]*?)\s*<\/title>/i))
						productName = data.match(/<title>\s*([^>]*?)\s*<\/title>/i)[1]
						productName=productName.replace(/\'/ig,'')
						#'
						productName=productName.replace(/\\/ig,'')
						productName=productName.replace(/\-\s*New\s*Balance\s*\-\s*US\s*\-\s*2/ig,'')

					if $('.col-12.value.content.short-description')
						productDescription = $('.col-12.value.content.short-description').text()
						productDescription=productDescription.replace(/<[^>]*?>/ig,' ')
						productDescription=productDescription.replace(/\s+/ig,' ')

					if $('.product-detail.col-lg-8.d-none.d-lg-block.mt-lg-9')
						prod_detail1 = $('.product-detail.col-lg-8.d-none.d-lg-block.mt-lg-9').text().trim()
						prod_detail1=prod_detail1.replace(/\s+/ig,' ')

					if $('.features-bucket').text()
						prod_detail2 = $('.features-bucket').eq(0).text().trim()
						prod_detail2=prod_detail2.replace(/\s+/ig,' ')

					prod_detail = prod_detail1

					if(data.match(/data\-brand\=\"([^>]*?)\"/i))
						brand = data.match(/data\-brand\=\"([^>]*?)\"/i)[1]
					else
						brand ='New Balance'

					image_url = $('.tile-image').attr('data-src')
					priceNow=''
					priceWas=''
					pricetext = ''
					data1=''
					data2=''
					Json_data1=''
					Json_data2=''
					pricetext = $('.sales.font-body-large ').eq(0).text().trim()
					priceNow=$('.sales.font-body-large ').eq(0).text().trim()
					priceWas=priceNow
					if($('.strike-through.sales.font-body-large .value'))
						priceWas=$('.strike-through.sales.font-body-large .value').eq(0).attr('content')

					console.log('akshay 177')
					if(data.match(/productInventory\["[\W\w]*?"\]\s*=\s*([\W\w]*?);<\/script>/i))
						console.log("akshay 11")
						data11 = data.match(/productInventory\["[\W\w]*?"\]\s*=\s*([\W\w]*?);<\/script>/i)[1]
						console.log("akshay 17")
						console.log(data11)
						Json_data1=shared.json_converter(data11)
						console.log("akshay 12")
					if(data.match(/<script>productInfo.*?=\s*(.*?);<\/script>/i))
						console.log('akshay 22')
						data22=data.match(/<script>productInfo.*?=\s*(.*?);<\/script>/i)[1]
						Json_data2=shared.json_converter(data22)
						console.log("ak pass")
					console.log('akshay 2')


					details['price_text'] = pricetext
					details.product['product_gold_key'] = productCode
					details.product['retailer_id'] = shared.retailer.retailer_id
					details.product['product_url'] = url
					details.product['name'] = productName
					details.product['description_overview'] = productDescription
					details.product['description_details'] = prod_detail
					details.product['brand'] = brand
					details.product['image_filename'] = image_url
					details['isStyleMerging'] = 'NO'
					details['delete_md5'] = true

					sku_color = 'color_check'

					sku=''
					size_hash={}
					JSON_data_sku={}
					JSON_image_sku={}
					JSON_color_raw_sku = {}
					color_size_all_hash={}
					image_map={}
					size_all=[]
					color_all=[]
					color_length =''
					size_length =''
					#priceNow = ''
					#priceWas = ''

					Object.keys(Json_data2['variants']).forEach (skuid0) ->
						style_id = Json_data2['variants'][skuid0]['id']
						style_key = Json_data2['variants'][skuid0]['size']
						JSON_data_sku[style_id]=style_key
						console.log("ak11")
					$('.mr-2.mr-lg-3.mb-2.mb-lg-3.variation-attribute.style-attribute').each (index, el) ->
						JSON_image_sku[image_key]
						image_key=$(el).find('span').attr('data-attr-value')
						image_url1 = $(el).find('span').attr('style')
						if(image_url1.match(/background-image: url\((.*?)\?\$pdp/i))
							image_url1=image_url1.match(/background-image: url\((.*?)\?\$pdp/i)[1]
						color_raw = $(el).attr('aria-label')
						if(color_raw.match(/Select Style/i))
							color_raw=color_raw.replace(/Select Style/ig,'')
						JSON_image_sku[image_key] = image_url1
						JSON_color_raw_sku[image_key] = color_raw



					if(Json_data1!='' && Json_data2!='' )
						console.log("inside if")
						Object.keys(Json_data2['variants']).forEach (sku_id1) ->
							color_id = Json_data2['variants'][sku_id1]['style']
							size_id=Json_data2['variants'][sku_id1]['id']
							image_id_color = Json_data2['variants'][sku_id1]['style']
							image_url = JSON_image_sku[image_id_color]
							size=JSON_data_sku[size_id]
							color=JSON_color_raw_sku[color_id]
							color=shared.entities.decodeHTML(color)
							image_map[color] = image_url
							if(Json_data2['variants'][sku_id1]['width'])
								console.log("insidde widt")
								width_id = Json_data2['variants'][sku_id1]['width']
								#width_id=JSON_data_sku[width_id]
								size = size+" "+width_id
								console.log("width"+width_id)

							color_size_all = color+size
							#image_url=image_url+'?$pdpflexf2$&fmt=webp&wid=944&hei=944'
							console.log("akshay sizeid"+size_id)
							console.log("size: "+size)
							stock=false
							color_size_all_hash[color_size_all]=color_size_all
							Object.keys(Json_data1['variants']).forEach (key,value) ->
								console.log("ak 332 " +key+ " -- "+value)
								sku_id2=key
								console.log('ak skuid2 '+sku_id2+ 'size_id'+size_id)
								if(sku_id2==size_id)
									console.log("inside12")
									console.log("aaaa"+Json_data1['variants'][key]['status'])
									if(Json_data1['variants'][key]['status']=='IN_STOCK')

										stock=true
									else
										stock=false
								else
									stock=false

							console.log("out")
							console.log("color"+color)
							console.log("size"+size)
							console.log("color112 "+color)
							console.log(" size "+size)
							console.log("image url "+image_url)
							console.log(" price "+priceNow)
							console.log("pw" +priceWas)
							console.log(" stock 111"+stock)
							if!(size in size_all)
								size_all.push(size)
							console.log("aaout")
							if!(color in color_all)
								color_all.push(color)
							if(priceWas==''  || priceWas==undefined)
								priceWas=priceNow
							console.log("color 11"+color+" size "+size+"image url "+image_url+" price "+priceNow+"  "+priceWas+" stock "+stock)

							details.skuHistory[index1] = [
								sku
								entities = [
									["color", color],
									["size" , size]
								]
								images =
									large: image_url
								priceNow
								priceWas
								stock
							]
							index1++
						color_all.forEach (color_array) ->
							color = color_array
							stock = false
							if(priceWas=='' || priceWas==undefined)
								priceWas=priceNow
							image_url=image_map[color_array]

							size_all.forEach (size) ->
								hash_check = color+size
								if!(color_size_all_hash.hasOwnProperty(hash_check))
									console.log("color 22"+color+" size "+size+"image url "+image_url+" price "+priceNow+"  "+priceWas+" stock "+stock)
									details.skuHistory[index1] = [
										sku
										entities = [
											["color", color],
											["size" , size]
										]
										images =
											large: image_url
										priceNow
										priceWas
										stock
									]
									index1++
					deferred.resolve details
					deferred.promise
				else
					shared.errorLogger 'Error ' + url
					doneCallback(null, null)
			)
			.then(shared.addProductDetailsToDatabase)
			.then(doneCallback)
		), 4000
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
