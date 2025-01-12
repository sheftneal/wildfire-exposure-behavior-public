#-------------------------------------------------------------------------------
# Plot Map of Smoke Day Trends
# Written by: Anne Driscoll
#-------------------------------------------------------------------------------
# Load grid
grid = readOGR(file.path(path_boundaries, "10km_grid"), "10km_grid")
county_proj = "+proj=longlat +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +no_defs"
grid = spTransform(grid, CRS(county_proj))

# Load smoke days over grid
sparse_smoke_days = readRDS(file.path(path_smoke, "sparse_smoke_grid.RDS"))
# Get annual count of smoke days of at least medium or heavy density for 2011-2020
# in each grid cell
sparse_smoke_days %<>% 
  filter(date > "20110101") %>%
  mutate(year = substr(date, 1, 4)) %>%
  group_by(id, year) %>%
  summarise(med_heavy_days = sum(medium>0 | dense>0), 
            heavy_days = sum(dense>0))

# Fill for non-smoke days
year_panel = expand.grid(id = unique(grid$ID), year = unique(sparse_smoke_days$year))
sparse_smoke_days %<>%
  merge(year_panel, by=c("id", "year"), all=T) %>%
  mutate(med_heavy_days = ifelse(is.na(med_heavy_days), 0, med_heavy_days),
         heavy_days = ifelse(is.na(heavy_days), 0, heavy_days))

# Calculate smoke day trends
# Takes ~ 10 minutes
id_vec = unique(grid$ID)
betas = data.frame(id=as.character(id_vec), 
                   beta_days_16_27=as.numeric(NA), 
                   beta_days_27=as.numeric(NA))
start_time = Sys.time()
for (i in 1:length(id_vec)) {
  cur_id = id_vec[i]
  cur_smoke = sparse_smoke_days[sparse_smoke_days$id == cur_id,]
  
  beta_days_16_27 = lm(med_heavy_days ~ as.numeric(year), cur_smoke)$coefficients[[2]]
  beta_days_27 = lm(heavy_days ~ as.numeric(year), cur_smoke)$coefficients[[2]]
  
  betas[i, 2:3] = c(beta_days_16_27, beta_days_27)
}
end_time = Sys.time()
end_time - start_time

# Prepare smoke day trends data for plotting
grid_geo = fortify(grid, region="ID")
data = merge(grid_geo, betas, by="id", all=T)
data = data %>% arrange(id, piece, order)

# Read in EPA locations
epa_ll = readOGR(file.path(path_epa, "epa_station_locations"), 
                 "epa_station_locations") 
epa_ll = epa_ll[epa_ll$lon >= -125.18 & epa_ll$lon <= -66.63 &
                  epa_ll$lat >= 24.64 & epa_ll$lat <= 49.41,]

# Prepare for plotting
cols = c('#000080', '#0047AB', '#0096FF', '#89CFF0', '#ffffff',
         '#EE4B2B', '#D22B2B', '#DC143C', '#800000')
lim = c(min(betas$beta_days_27)-0.01, max(betas$beta_days_27)+0.01)
diff = c(seq(lim[1], 0, length.out=4), 0, seq(0, lim[2], length.out=4))

# Plot map and save
g = ggplot() + # the data
  geom_polygon(data=data, aes(long,lat,group=group, fill=beta_days_27)) + # Make polygons 
  geom_point(aes(lon, lat), size=0.0001, data=epa_ll@data) + 
  scale_fill_gradientn(limits=lim, colors=cols, values=scales::rescale(diff), n.breaks = 6) + 
  theme(line = element_blank(),  # Remove the background, tickmarks, etc
        axis.text=element_blank(),
        axis.title=element_blank(),
        panel.background = element_blank()) + 
  coord_map("bonne", mean(data$lat)) + labs(fill="")
ggsave(file.path(path_figures, "figure01a.pdf"),
       plot = g, width=10, height=5, units="in")

#-------------------------------------------------------------------------------
# Figure 1 Panels b and c
# Written by: Marshall Burke
#-------------------------------------------------------------------------------
# Load data
df <- read_rds(file.path(path_smokePM, 'station_smoke_pm.rds'))
df <- df %>% mutate(smokepm = smokepm*smoke_day)
dfs <- df %>% mutate(year=year(date)) %>% group_by(epa_id,year) %>% summarise(smokepm=mean(smokepm,na.rm=T),region=first(region),division=first(division))

# Plot percentiles over time in annual distribution
yrs <- 2006:2020
colz <- apply(sapply("purple", col2rgb)/255, 2, function(x) rgb(x[1], x[2], x[3], alpha=c(0.1,0.3,0.5,0.7)))
pdf(file.path(path_figures, 'figure01b-c.pdf'),width=4,height=6)
par(mfrow=c(2,1),mar=c(4,4,1,1))
qts = c(0.01,0.05,0.1,0.25,0.5,0.75,0.9,0.95,0.99)
pctl <- dfs %>% group_by(year) %>% filter(year<2021) %>% summarise(val = quantile(smokepm,probs=qts,na.rm=T))
pctl$quant = rep(qts,length(yrs))
plot(1,type = "n",ylim=c(0,14),xlim=c(1,length(yrs)+1),axes=F,xlab="year",ylab="annual smoke PM (ug/m3)")
ll=length(yrs)
for (i in 1:4) {
  polygon(c(1:ll,ll:1),c(pctl$val[pctl$quant==qts[i]],rev(pctl$val[pctl$quant==qts[length(qts)-i+1]])),col=colz[i],border = NA)
}
lines(1:ll,pctl$val[pctl$quant==0.5])
axis(2,las=1)
yz = c(2006,2010,2014,2018,2020)
axis(1,at=which(yrs%in%yz),yz,cex.axis=0.8)

# Same thing but for daily distribution
pctl <- df %>% group_by(year) %>% filter(year<2021 & smokepm>0) %>% summarise(val = quantile(smokepm,probs=qts,na.rm=T))
pctl$quant = rep(qts,length(yrs))
plot(1,type = "n",ylim=c(0,200),xlim=c(1,length(yrs)+1),axes=F,xlab="year",ylab="daily smoke PM (ug/m3)")
ll=length(yrs)
for (i in 1:4) {
  polygon(c(1:ll,ll:1),c(pctl$val[pctl$quant==qts[i]],rev(pctl$val[pctl$quant==qts[length(qts)-i+1]])),col=colz[i],border = NA)
}
lines(1:ll,pctl$val[pctl$quant==0.5])
axis(2,las=1)
axis(1,at=which(yrs%in%yz),yz,cex.axis=0.8)
dev.off()
