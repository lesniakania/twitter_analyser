﻿select count(*), date_part('month', twitts.date) as data from twitts where date_part('year', twitts.date)=2010 group by data order by data;