#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
package Cortefiel_ES;
use strict;
# use Net::SSL;
###########################################
sub Cortefiel_ES_DetailProcess()
{
	my $product_object_key = shift;
	my $url = shift;
	my $robotname = shift;
	my $retailer_id = shift;
	my $logger = shift;
	my $ProxyConfig = shift;
	my $ua = shift;
	my $dbobject = shift;
	my $imagesobject = shift;
	my $utilityobject = shift;
	my $Retailer_Random_String='Cor';
	my $mflag = 0;

	$robotname =~ s/\-\-Worker/\-\-Detail/igs;
	my $retailer_name = $robotname;
	$retailer_name =~ s/\-\-Detail\s*$//igs;
	$retailer_name = lc($retailer_name);
	$url =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;

	my $country=$retailer_name;
	$country=$1 if($country =~ m/[^>]*?\-([^>]*?)\s*$/is);
	$country=uc($country);

	# Get the Country Code from Retailer Name.
	my $ccode = $utilityobject->Trim($1) if($retailer_name =~m/\-([^>]*?)$/is);
	# Setting the Environment
	$utilityobject->SetEnv($ProxyConfig);

	return if($product_object_key eq '');

	my $url3=$url;
	$url3 =~ s/^\s+|\s+$//g;
	$product_object_key =~ s/^\s+|\s+$//g;
	REPING:
	# my $content2 = $utilityobject->Lwp_Get($url3);
	my %hash1=("authority"=>"cortefiel.com","accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9","accept-encoding"=>"gzip, deflate, br","accept-language"=>"en-US,en;q=0.9","user-agent"=>"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.89 Safari/537.36");
	# my %hash1=("authority"=>"cortefiel.com");
	my $content2 = $utilityobject->Lwp_Get($url3,\%hash1);
	goto PNF if($content2==1);

	# Declaring all required variables.
	my ($price,$price_text,$brand,$sub_category,$product_id,$product_name,$description,$main_image,$prod_detail,$alt_image,$out_of_stock,$color,$sku_id, $default_img, $color_url, $size);
	my ($new_in_check,$product_gold_key);
	# Get the Retailer_Product_Reference and call the UpdateProducthasTag to check if the same product reference exists.
	if ( $content2 =~ m/window\.universal_variable\.product\s*\=[^>]*?masterID\"\:\s*"\s*([^>]*?)\s*\"\s*\,/is )
	{
		$product_id = $utilityobject->Trim($1);
		$product_gold_key=$dbobject->goldkey_generation("",lc($retailer_name."_".$product_id));
		$utilityobject->product_gold_key_set($product_gold_key,$url);
		$new_in_check=$utilityobject->goldkey_lookup($product_gold_key);
		my $ckproduct_id = $dbobject->UpdateProducthasTag($product_id, $product_object_key,$robotname,$retailer_id);
		goto ENDOFF if($ckproduct_id == 1);
		undef ($ckproduct_id);
	}
	else
	{
		goto PNF;
	}

	my $transaction_check='no';
	if($new_in_check=~m/^\s*0\s*$/is)
	{
		$transaction_check='yes';
		open (FF,'>>/var/log/'.lc($retailer_name).'_NewIN.txt');
		print FF "$product_gold_key\t$product_object_key\t$product_id\t$url\n";
		close FF;
	}
	# Patten matching for product_name.
	if ( $content2 =~ m/\{\s*\"title\"\:\"\s*([^>]*?)\s*\"/is )
	{
		$product_name = $utilityobject->Trim($1);
		# $product_name=$utilityobject->Unicode_une($product_name);
		$product_name=$utilityobject->Translate($product_name,$country,'',$transaction_check);
		$product_name =~s/\'//igs;
		$product_name =~s/\\//igs;
	}
	# $brand='Cortefiel' if($product_name ne '');
	$brand='Cortefiel';
	# Patten matching for product description.
	if($content2=~m/Composici&oacute\;n([\w\W]*?)\s*\<\s*\/div\s*\>/is)
	{
		$prod_detail=$1;
		$prod_detail=~s/<[^>]*?>/ /igs;
		$prod_detail=~s/\&nbsp(?:\;)?\s*/ /igs;
		$prod_detail=$utilityobject->Trim($prod_detail);
	}
	if($content2=~m/description\s*\"\s*\:\s*\"([^>]*?)\s*\"\s*\,\s*\"url\s*\"/is)
	{
		$description=$1;
		$description=~s/<[^>]*?>/ /igs;
		$description=~s/\&nbsp(?:\;)?\s*/ /igs;
		$description=$utilityobject->Trim($description);
	}
	$prod_detail=$utilityobject->Translate($prod_detail,$country,'',$transaction_check);
	$description=$utilityobject->Translate($description,$country,'',$transaction_check);


	# Patten matching for price_text.
	if ( $content2 =~ m/<span\s*class="_2DzCmk_neUiZgBFjS38Clv">([\w\W]*?)<\/span>\s*<span\s*class="_1wJn08WlgdgvchKNPYAO5U\s*_3NgEMQtqWzAVKhARCkcsJy\s*js-product-price"\s*data-price="([\w\W]*?)">[\w\W]*?<\/span>/is )
	{
		my $price_text_contnet = $content2;
		my $sale_pr;
		# Patten matching for price.
		if ( $price_text_contnet =~m/<span\s*class="_2DzCmk_neUiZgBFjS38Clv">([\w\W]*?)<\/span>/im )
		{
			$price = $1;
			if($price_text_contnet=~m/<span\s*class="_2DzCmk_neUiZgBFjS38Clv">([\w\W]*?),([\w\W]*?)&euro;<\/span>/im)
			{
				$price = $1.'.'.$2;
			}
		}
		if ( $price_text_contnet =~m/<span\s*class="_1wJn08WlgdgvchKNPYAO5U\s*_3NgEMQtqWzAVKhARCkcsJy\s*js-product-price"\s*data-price="([\w\W]*?)">[\w\W]*?<\/span>/is )
		{
			$sale_pr = $1;
		}
		$price_text='EUR '.$price.' '.'EUR '.$sale_pr;
	}
	else{
		if($content2=~ m/<span class="_1wJn08WlgdgvchKNPYAO5U js-product-price" data-price="(.*?)">[\w\W]*?<\/span>/igm){
			$price = $1;
			$price_text='EUR '.$price;
		}

	}
	$price_text=~s/<\/strong>//igs;
	$price_text=~s/\s*EUR\s*$//igs;
	$price_text=~s/<[^>]*?>//igs;
	$price_text=~s/\,/./igs;
	$price_text=~s/\&\#8364\;//igs;
	$price_text=~s/\s+/ /igs;
	$price_text=~s/new//igs;
	$price=~s/\&\#8364\;//igs;
	$price=~s/\�//igs;
	$price=~s/\,/./igs;
	my (%AllColor,$tcolor,$clr,@totalColor);
	if($content2=~m/class="UL3gI0DXllXMRemhza2K4\s*js-color-selector"[\w\W]*?>\s*<a\s*href="([\w\W]*?)"\s*class="([\w\W]*?)"\s*title=([\w\W]*?)>/is)
	{
		while($content2=~m/class="UL3gI0DXllXMRemhza2K4\s*js-color-selector"[\w\W]*?>\s*<a\s*href="([\w\W]*?)"\s*class="([\w\W]*?)"\s*title=([\w\W]*?)>/igs)
		{
			my $sku_check=$2;
			my $color_url=$1.'&format=ajax';
			$color=$3;
			$color = $utilityobject->Trim($color);
			$color=$utilityobject->Translate($color,$country);
			$color_url=~s/amp\;//igs;

			my $color1=lc($color);
			# Color Duplication Incremented.
			if($AllColor{$color1}>0)
			{
				$AllColor{$color}++; # To increment colour value.
				my $tcolor = $color.'('.$AllColor{$color}.')';
				push @totalColor,$tcolor;
				$clr=$tcolor;
			}
			else
			{
				 push @totalColor,$color;
				 $AllColor{$color1}++; # To increment colour value.
				 $clr=$color;
			}
			my $tcolor2;
			# To Change color case.
			$clr = lc($clr);

			while($clr =~ m/([^>]*?)(?:\s+|$)/igs) # Splitting colour to get colour value to make case sensitive.
			{
				my $colour_id=$1;
				 if($tcolor2 eq '')
				 {
				  $tcolor2 = ucfirst($colour_id);
				 }
				 else
				 {
				  $tcolor2 = $tcolor2.' '.ucfirst($colour_id);
				 }
			}
			if($sku_check=~m/selected/is)
			{
				if($content2=~m/class="_2NS1-fPbGw9CfDv-ITpQhr scope_pdpSideBar js-size-selector">([\w\W]*?)<\/div>/igm)
				{
					my $sku_block=$1;

					if($sku_block=~m/<span\s*class="VeD_Crms98XrJg51gPauR gi-sizes-desktop">\s*<([\w\W]*?)>\s*<[\w\W]*?>([\w\W]*?)<\/label>\s*<\/span>/igm)
					{
						while($sku_block=~m/<span\s*class="VeD_Crms98XrJg51gPauR gi-sizes-desktop">\s*<([\w\W]*?)>\s*<[\w\W]*?>([\w\W]*?)<\/label>\s*<\/span>/igm)
						{
							my $in_stock=$1;
							$size=$2;
							$size=$utilityobject->DecodeText($size);
							$size=~s/'/./igs;
							if($in_stock=~m/disabled|unselectable/is)
							{
								$out_of_stock='y'
							}
							else
							{
								$out_of_stock='n'
							}
							$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$tcolor2);
							# sleep(2)
						}
					}
					else
					{
						$size='No size';
						$out_of_stock='n';
						$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$tcolor2);
						# sleep(2)
					}
				}
				else
				{
					$size='No size';
					$out_of_stock='n';
					$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$tcolor2);
				}

				if($content2 =~m/class="js-images-container _2jgJ6sUHaWAf5knmNN_lAI">\s*<[\w\W]*?src="([\w\W]*?)"/igm)
				{
					my $image_url = $1;
					$image_url='https:'.$image_url if($image_url=~m/^\/\//is);
					$image_url='https://cortefiel.com'.$image_url if($image_url!~m/http/is);
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);

					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$tcolor2,'y') if(defined $img_file);
				}
			}
			else
			{
				my $content_sku = $utilityobject->Lwp_Get($color_url);

				if($content_sku=~m/class="_2NS1-fPbGw9CfDv-ITpQhr scope_pdpSideBar js-size-selector">([\w\W]*?)<\/div>/igm)
				{
					my $sku_block=$1;

					if($sku_block=~m/<span\s*class="VeD_Crms98XrJg51gPauR gi-sizes-desktop">\s*<([\w\W]*?)>\s*<[\w\W]*?>([\w\W]*?)<\/label>\s*<\/span>/igm)
					{
						while($sku_block=~m/<span\s*class="VeD_Crms98XrJg51gPauR gi-sizes-desktop">\s*<([\w\W]*?)>\s*<[\w\W]*?>([\w\W]*?)<\/label>\s*<\/span>/igm)
						{
							my $in_stock=$1;
							$size=$2;
							$size=$utilityobject->DecodeText($size);
							$size=~s/'/./igs;
							if($in_stock=~m/disabled|unselectable/is)
							{
								$out_of_stock='y'
							}
							else
							{
								$out_of_stock='n'
							}
							$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$tcolor2);
						}
					}
					else
					{
						$size='No size';
						$out_of_stock='n';
						$dbobject->SaveSku($product_object_key,$url3,$product_name,$price,$price_text,$size,$tcolor2,$out_of_stock,$Retailer_Random_String,$robotname,$tcolor2);
					}
				}

				if($content_sku =~m/class="js-images-container _2jgJ6sUHaWAf5knmNN_lAI">\s*<[\w\W]*?src="([\w\W]*?)"/igm)
				{
					my $image_url = $1;
					$image_url='https:'.$image_url if($image_url=~m/^\/\//is);
					$image_url='https://cortefiel.com'.$image_url if($image_url!~m/http/is);
					# Downloading and save entry for product images.
					my $img_file = $imagesobject->download($image_url,'product',$retailer_name,$ua);

					# Save entry to Image table ,if image download is successful. Otherwise throw error in log.
					$dbobject->SaveImage($image_url,$img_file,'product',$Retailer_Random_String,$robotname,$tcolor2,'y') if(defined $img_file);
				}
			}
		}
	}

	# # Map the relevant sku's and images in DB.
	my $logstatus = $dbobject->Sku_has_ImageMapping($product_object_key, $Retailer_Random_String, $robotname);
	$logger->send("<product> $product_object_key -> Sku has Image not mapped") if($logstatus == 0);

	PNF:
	# # Insert product details and update the Product_List table based on values collected for the product.
	$dbobject->UpdateProductDetail($product_object_key,$product_id,$product_name,$brand,$description,$prod_detail,$robotname,$url3,$retailer_id,$mflag,'yes');
	# # Execute all the available queries for the product.
	$dbobject->ExecuteQueryString($product_object_key);

	ENDOFF:# Label for Duplicate entry.
	$dbobject->commit;
	# # Destory global variables in AnorakDB.
	$dbobject->Destroy();
}1;
