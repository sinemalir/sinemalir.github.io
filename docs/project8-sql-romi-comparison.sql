with facebook_ads as (
select
	fabd.ad_date,
	coalesce(fabd.url_parameters,
	'') as url_parameters,
	coalesce(SUM(fabd.spend),
	0) as spend,
	coalesce(SUM(fabd.impressions),
	0) as impressions,
	coalesce(SUM(fabd.reach),
	0) as reach,
	coalesce(SUM(fabd.clicks),
	0) as clicks,
	coalesce(SUM(fabd.leads),
	0) as leads,
	coalesce(SUM(fabd.value),
	0) as value,
	'Facebook Ads'::text as media_source
from
	facebook_ads_basic_daily fabd
group by
	fabd.ad_date,
	fabd.url_parameters
),
google_ads as (
select
	gabd.ad_date,
	coalesce(gabd.url_parameters,
	'') as url_parameters,
	coalesce(SUM(gabd.spend),
	0) as spend,
	coalesce(SUM(gabd.impressions),
	0) as impressions,
	coalesce(SUM(gabd.reach),
	0) as reach,
	coalesce(SUM(gabd.clicks),
	0) as clicks,
	coalesce(SUM(gabd.leads),
	0) as leads,
	coalesce(SUM(gabd.value),
	0) as value,
	'Google Ads'::text as media_source
from
	google_ads_basic_daily gabd
group by
	gabd.ad_date,
	gabd.url_parameters
),
combined_ads as (
select
	*
from
	facebook_ads
union all
select
	*
from
	google_ads
),
monthly_ads as (
select
	DATE_TRUNC('month',
	ad_date) as ad_month,
	-- Ayın ilk günü
        NULLIF(LOWER(SUBSTRING(url_parameters FROM 'utm_campaign=([^&]+)')), 'nan') AS utm_campaign,
	coalesce(SUM(spend),
	0) as total_cost,
	coalesce(SUM(impressions),
	0) as number_of_impressions,
	coalesce(SUM(clicks),
	0) as number_of_clicks,
	coalesce(SUM(value),
	0) as conversion_value,
	-- Hesaplamalar
        case
		when coalesce(SUM(impressions),
		0) > 0 then ROUND((coalesce(SUM(clicks),
		0)::DECIMAL / coalesce(SUM(impressions),
		0)) * 100,
		2)
		else 0
	end as CTR,
	case
		when coalesce(SUM(clicks),
		0) > 0 then ROUND(coalesce(SUM(spend),
		0) / coalesce(SUM(clicks),
		0),
		2)
		else 0
	end as CPC,
	case
		when coalesce(SUM(impressions),
		0) > 0 then ROUND((coalesce(SUM(spend),
		0) / coalesce(SUM(impressions),
		0)) * 1000,
		2)
		else 0
	end as CPM,
	case
		when coalesce(SUM(spend),
		0) > 0 then 
                ROUND(
                    (cast(SUM(value) as DECIMAL(10,
		2)) - cast(SUM(spend) as DECIMAL(10,
		2))) 
                    / cast(SUM(spend) as DECIMAL(10,
		2)) * 100,
		2
                )
		else 0
	end as ROMI
from
	combined_ads
group by
	ad_month,
	utm_campaign
),
monthly_comparisons as (
select
	ma.ad_month,
	ma.utm_campaign,
	ma.total_cost,
	ma.number_of_impressions,
	ma.number_of_clicks,
	ma.conversion_value,
	ma.CTR,
	ma.CPC,
	ma.CPM,
	ma.ROMI,
	-- Önceki aya göre yüzde değişim hesaplamaları
        case
		when lag(ma.CTR) over (partition by ma.utm_campaign
	order by
		ma.ad_month) is not null
		and lag(ma.CTR) over (partition by ma.utm_campaign
	order by
		ma.ad_month) != 0
            then ROUND(((ma.CTR - lag(ma.CTR) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) 
                        / lag(ma.CTR) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) * 100,
		2)
		else null
	end as CTR_percentage_change,
	case
		when lag(ma.CPC) over (partition by ma.utm_campaign
	order by
		ma.ad_month) is not null
		and lag(ma.CPC) over (partition by ma.utm_campaign
	order by
		ma.ad_month) != 0
            then ROUND(((ma.CPC - lag(ma.CPC) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) 
                        / lag(ma.CPC) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) * 100,
		2)
		else null
	end as CPC_percentage_change,
	case
		when lag(ma.CPM) over (partition by ma.utm_campaign
	order by
		ma.ad_month) is not null
		and lag(ma.CPM) over (partition by ma.utm_campaign
	order by
		ma.ad_month) != 0
            then ROUND(((ma.CPM - lag(ma.CPM) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) 
                        / lag(ma.CPM) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) * 100,
		2)
		else null
	end as CPM_percentage_change,
	case
		when lag(ma.ROMI) over (partition by ma.utm_campaign
	order by
		ma.ad_month) is not null
		and lag(ma.ROMI) over (partition by ma.ad_month) != 0
            then ROUND(((ma.ROMI - lag(ma.ROMI) over (partition by ma.utm_campaign
	order by
		ma.ad_month)) 
                        / lag(ma.ROMI) over (partition by ma.ad_month)) * 100,
		2)
		else null
	end as ROMI_percentage_change
from
	monthly_ads ma
)
select
	ad_month,
	utm_campaign,
	total_cost,
	number_of_impressions,
	number_of_clicks,
	conversion_value,
	CTR,
	CPC,
	CPM,
	ROMI,
	CTR_percentage_change,
	CPC_percentage_change,
	CPM_percentage_change,
	ROMI_percentage_change
from
	monthly_comparisons
order by
	ad_month desc,
	utm_campaign;
