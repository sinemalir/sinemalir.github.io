select
	fabd.ad_date,
	fc.campaign_name,
	fa.adset_name,
	fabd.spend,
	fabd.impressions,
	fabd.reach,
	fabd.clicks,
	fabd.leads,
	fabd.value
from
	facebook_ads_basic_daily fabd
left join facebook_campaign fc on
	fc.campaign_id = fabd.campaign_id
left join facebook_adset fa on
	fa.adset_id = fabd.adset_id
where
	spend>0;

with facebook_ads as (
select
	fabd.ad_date,
	fc.campaign_name,
	fa.adset_name,
	'Facebook Ads'::text as media_source,
	SUM(fabd.spend) as toplam_maliyet,
	SUM(fabd.impressions) as "gösterim_sayisi",
	SUM(fabd.clicks) as tiklama_sayisi,
	SUM(fabd.value) as toplam_donusum_degeri
from
	facebook_ads_basic_daily fabd
left join facebook_campaign fc on
	fc.campaign_id = fabd.campaign_id
left join facebook_adset fa on
	fa.adset_id = fabd.adset_id
where
	fabd.ad_date is not null
	and fabd.spend not in (0)
group by
	fabd.ad_date,
	fc.campaign_name,
	fa.adset_name
),
google_ads as (
select
	gabd.ad_date,
	gabd.campaign_name,
	gabd.adset_name,
	'Google Ads'::text as media_source,
	SUM(gabd.spend) as toplam_maliyet,
	SUM(gabd.impressions) as "gösterim_sayisi",
	SUM(gabd.clicks) as tiklama_sayisi,
	SUM(gabd.value) as toplam_donusum_degeri
from
	google_ads_basic_daily gabd
where
	gabd.ad_date is not null
	and gabd.spend not in (0)
group by
	gabd.ad_date,
	gabd.campaign_name,
	gabd.adset_name
)
select
	combined_ads.ad_date,
	combined_ads.media_source,
	combined_ads.campaign_name,
	combined_ads.adset_name,
	SUM(combined_ads.toplam_maliyet) as toplam_maliyet,
	SUM(combined_ads."gösterim_sayisi") as toplam_gösterim,
	SUM(combined_ads.tiklama_sayisi) as toplam_tiklama,
	SUM(combined_ads.toplam_donusum_degeri) as toplam_value
from
	(
	select
		ad_date,
		media_source,
		toplam_maliyet,
		"gösterim_sayisi",
		tiklama_sayisi,
		toplam_donusum_degeri,
		campaign_name,
		adset_name
	from
		facebook_ads
union all
	select
		ad_date,
		media_source,
		toplam_maliyet,
		"gösterim_sayisi",
		tiklama_sayisi,
		toplam_donusum_degeri,
		campaign_name,
		adset_name
	from
		google_ads
) combined_ads
group by
	combined_ads.ad_date,
	combined_ads.media_source,
	combined_ads.campaign_name,
	combined_ads.adset_name
order by
	combined_ads.ad_date desc;


--bonus
  
with facebook_ads as (
select
	fabd.ad_date,
	fc.campaign_name,
	fa.adset_name,
	SUM(fabd.value) as toplam_value,
	SUM(fabd.spend) as toplam_spend,
	case
		when SUM(fabd.spend) > 0 then
                ROUND(((cast(SUM(fabd.value) as numeric(10,
		2)) - cast(SUM(fabd.spend) as numeric(10,
		2))) / cast(SUM(fabd.spend) as numeric(10,
		2))) * 100,
		2)
		else 0
	end as ROMI
from
	facebook_ads_basic_daily fabd
left join facebook_campaign fc on
	fc.campaign_id = fabd.campaign_id
left join facebook_adset fa on
	fa.adset_id = fabd.adset_id
where
	fabd.spend > 0
group by
	fabd.ad_date,
	fc.campaign_name,
	fa.adset_name
having
	SUM(fabd.spend) > 500000
) ,
google_ads as (
select
	gabd.ad_date,
	gabd.campaign_name,
	gabd.adset_name,
	SUM(gabd.value) as toplam_value,
	SUM(gabd.spend) as toplam_spend,
	case
		when SUM(gabd.spend) > 0 then
                ROUND(((cast(SUM(gabd.value) as numeric(10,
		2)) - cast(SUM(gabd.spend) as numeric(10,
		2))) / cast(SUM(gabd.spend) as numeric(10,
		2))) * 100,
		2)
		else 0
	end as ROMI
from
	google_ads_basic_daily gabd
where
	gabd.spend > 0
group by
	gabd.ad_date,
	gabd.campaign_name,
	gabd.adset_name
)
select
	combined.campaign_name,
	combined.adset_name,
	MAX(combined.ROMI) as max_ROMI
from
	(
	select
		fa.campaign_name,
		fa.adset_name,
		fa.ROMI
	from
		facebook_ads fa
union all
	select
		ga.campaign_name,
		ga.adset_name,
		ga.ROMI
	from
		google_ads ga
) as combined
group by
	combined.campaign_name,
	combined.adset_name
order by
	max_ROMI desc
limit 1;
