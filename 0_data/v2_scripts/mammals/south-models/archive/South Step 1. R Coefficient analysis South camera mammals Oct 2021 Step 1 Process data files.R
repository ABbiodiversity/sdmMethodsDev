# R ABMI coefficients analysis for mammals in the south
# This is step 1, process data files to be used by step 2 (simple run with diagnostic figures).  Step 3, a bootstrapped version, has not been updated for the camera mammals, due to lack of any interest in those results
# The data file has one row per camera, with summaries of the species' photos, series and duration, as well as seasonal times camera was operating and detection distances per species group.  Pre-processed in Access and R.
# Also, processing of km2 grid for the province is done separately, mainly because of memory limits

datafile<-"C:/Dave/ABMI/Data/Mammals/2021/abmi-cmu-nwsar-bg_all-years_density_wide_2021-11-04.csv"  # Processed density files from Marcus for various proojects, combined
vegfile<-"C:/Dave/ABMI/Data/Site info/2021/abmi-cmu-nwsar-bg_all-years_veghf-soilhf-detdistveg_2021-10-06.csv"  #  File simplified and corrected from GIS raw point summary, and information added from images for missed deployments.  Note: this version may or may not have all previous years' corrections
HFgroupfile<-"C:/Dave/ABMI/Data/Site info/2020/lookup-soil-hf-v2020.csv"  # Lookup table for HF to HF group from Peter included as part of soil lookup Oct 2020. NOTE: ADD SuccAlien and NonlinLin columns to lookup table if not there this time.  Also, version from Peter was not complete - add any missing HF types to this file (incl. check spelling)
pmfile<-"C:/Dave/ABMI/Cameras/Coefficients/2020/Analysis south/Prediction matrix for ABMI South coefficients 2020.csv"  # Prediction matrix - shows which (grouped) veg types and HF to use to predict which coefficients.  Needs to be edited in Excel when grouping changes.
siteinfofile<-"C:/Dave/ABMI/Data/Site info/Site summary with climate.csv"
deploymentlocationsfile<-"C:/Dave/ABMI/Data/Mammals/2021/Deployment locations all Nov 2021.csv"  # Needed to fill in missing nearest sites below - missing AUB, but Sask not used anyway
soilgroupfile<-"C:/Dave/ABMI/Data/Site info/2020/lookup-soil-hf-v2020.csv"  # Lookup table for soils to soil group Oct 2020
lurefile<-"C:/Dave/ABMI/Data/Mammals/2021/abmi-cmu-nwsar-bg_all-years_lure_2021-11-04.csv"  # Lure info not included in dataset any more
dataset.out<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/R Dataset SpTable for ABMI South mammal coefficients Nov 2021.RData"  # To save combined species-veg-HF file, plus SpTable.

# Read data file
d1<-read.csv(datafile,stringsAsFactors=FALSE)
# Convert colnames to same formats as in previous years, to avoid changing many lines throughout this and subsequent scripts
colnames(d1)<-gsub("_summer","Summer",colnames(d1))
colnames(d1)<-gsub("_winter","Winter",colnames(d1))
colnames(d1)<-gsub("\\.","",colnames(d1))
# Eliminate projects that don't use ABMI protocols or are otherwise weird.
project.list<-c("ABMI Ecosystem Health","ABMI Northern Focal Areas","Big Grids","CMU","Northwest Species at Risk","ABMI Southern Focal Areas 2019")  # Qualifying projects, except that ABMI Ecosystem Health includes several unrelated projects (in the data file that I used) - those are excluded below
d1$Use<-0
for (i in 1:length(project.list))	d1$Use<-ifelse(substr(d1$project,1,nchar(project.list[i]))==project.list[i],1,d1$Use)  # Mark to use if in qualifying project
# Then take out weird projects included as part of ABMI Ecosystem Health project.  This may change in new datafile with updated project names.
d1$Use<-ifelse(substr(d1$location,1,5)=="OG-EI",0,d1$Use)  # Excluding all EI, even though interior deployment were used previously - just easier here
d1$Use<-ifelse(substr(d1$location,1,7)=="OG-CITS",0,d1$Use)
d1$Use<-ifelse(substr(d1$location,1,5)=="OG-RIVR",0,d1$Use)
d1<-d1[d1$Use==1,]

# Read in Soil + HF at sites and process
v<-read.csv(vegfile,stringsAsFactors=FALSE)
names(v)[which(names(v)=="SOILHFclass")]<-"SoilHF"  # Use previous easier name
v<-v[!is.na(v$SoilHF),]  # Can't use deployments with no soil+HF info
v$SoilHF<-ifelse(substr(v$location,1,6)=="ABMI-W","WetlandMargin",v$SoilHF)  # Set all ABMI-W sites to WetlandMargin - specific stratum targeted by that study's design
# Set up columns, 1 per soil or HF type
SoilHF.list<-sort(unique(v$SoilHF))
q<-array(0,c(nrow(v),length(SoilHF.list)))
colnames(q)<-SoilHF.list
v<-cbind(v,q)
for (i in SoilHF.list) v[,i]<-ifelse(v$SoilHF==i,1,0)  # Assign proportion of area = 1 to appropriate veg or HF column for each site
# Group HF types
HFgl<-read.csv(HFgroupfile)  # HF group lookup.  Check all SoilHF types are included
HFgl<-HFgl[HFgl$Sector!="Native",]  # Soil types now included in HF lookup - omit
names(HFgl)[which(names(HFgl)=="o..ID")]<-"HF_GROUP"  # Use old name from early 2020 lookup table to avoid changing script below
HFgroups<-unique(HFgl$UseInAnalysis)
HFgroups<-HFgroups[-which(HFgroups=="HFor")]   # Not used in south
for (i in HFgroups) {
  HFtypesingroup<-colnames(v)[na.omit(match(HFgl$HF_GROUP[HFgl$UseInAnalysis==i],colnames(v)))]
  if (i=="HFor") HFtypesingroup<-c(HFtypesingroup,names(v)[substr(names(v),1,2)=="CC"])  # Add the individual cutblock types to HFor group
  if (length(HFtypesingroup)>1) {
    v<-cbind(v,rowSums(v[,HFtypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    v<-cbind(v,v[,HFtypesingroup])  # If there is only one HF type in that HF group, just add it
  }
  if (length(HFtypesingroup)==0) HFgroups<-HFgroups[-which(HFgroups==i)]  # Remove that group from the list if there are one of that HF type in the camera sample
}
names(v)<-c(names(v)[1:(ncol(v)-length(HFgroups))],as.character(HFgroups))
# And broader groups - SuccAlien
HFgroups<-unique(HFgl$SuccAlien)
for (i in HFgroups) {
  HFtypesingroup<-colnames(v)[na.omit(match(HFgl$HF_GROUP[HFgl$SuccAlien==i],colnames(v)))]
  if (i=="Succ") HFtypesingroup<-c(HFtypesingroup,names(v)[substr(names(v),1,2)=="CC"])  # Add the individual cutblock types to Succ group
  if (length(HFtypesingroup)>1) {
    v<-cbind(v,rowSums(v[,HFtypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    v<-cbind(v,v[,HFtypesingroup])  # If there is only one HF type in that HF group, just add it
  }
  if (length(HFtypesingroup)==0) HFgroups<-HFgroups[-which(HFgroups==i)]  # Remove that group from the list if there are one of that HF type in the camera sample
}
names(v)<-c(names(v)[1:(ncol(v)-length(HFgroups))],as.character(HFgroups))
# And broader groups - NonlinLin
HFgroups<-unique(HFgl$NonlinLin)
for (i in HFgroups) {
  HFtypesingroup<-colnames(v)[na.omit(match(HFgl$HF_GROUP[HFgl$NonlinLin==i],colnames(v)))]
  if (i=="Nonlin") HFtypesingroup<-c(HFtypesingroup,names(v)[substr(names(v),1,2)=="CC"])  # Add the individual cutblock types to Nonlin group
  if (length(HFtypesingroup)>1) {
    v<-cbind(v,rowSums(v[,HFtypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    v<-cbind(v,v[,HFtypesingroup])  # If there is only one HF type in that HF group, just add it
  }
}
names(v)<-c(names(v)[1:(ncol(v)-length(HFgroups))],as.character(HFgroups))
# And extras
v$NonAgAlien<-v$Alien-v$Crop-v$RoughP-v$TameP
v$Cult<-v$Crop+v$TameP+v$RoughP
v$RurUrbInd<-v$Urban+v$Rural+v$Industrial+v$HardLin+v$Mine  # Not enough of each separate type sampled

# Combine soil types
Soilgl<-read.csv(soilgroupfile)  # Soil group lookup
Soilgl<-Soilgl[Soilgl$Sector=="Native",]
names(Soilgl)[which(names(Soilgl)=="o..ID")]<-"SOILclass"  # Use old name from early 2020 lookup table to avoid changing script below
Soilgl$UseInAnalysis<-as.character(Soilgl$UseInAnalysis)
Soilgroups<-unique(Soilgl$UseInAnalysis)
Soilgroups<-Soilgroups[-which(Soilgroups=="SoilWater")]  # None in the south?
for (i in Soilgroups) {
  Soiltypesingroup<-colnames(v)[na.omit(match(Soilgl$SOILclass[Soilgl$UseInAnalysis==i],colnames(v)))]
  if (length(Soiltypesingroup)>1) {
    v<-cbind(v,rowSums(v[,Soiltypesingroup])) # Add a column for each soil group, summing the component soil types
  } else {
    v<-cbind(v,v[,Soiltypesingroup])  # If there is only one soil type in that soil group, just add it
  }
}
names(v)<-c(names(v)[1:(ncol(v)-length(Soilgroups))],as.character(Soilgroups))

# Add the variables that combine soil types
v$ClayWet<-v$ClaySub+v$Other
v$SandyRapid<-v$SandyLoam+v$RapidDrain
v$ThinBlow<-v$ThinBreak+v$Blowout
v$Nonproductive<-v$ClaySub+v$Other+v$RapidDrain+v$ThinBreak+v$Blowout
v$Productive<-v$Loamy+v$SandyLoam
v$AllNative<-v$Nonproductive+v$Productive  # For models that combine all soil types
v$AllNativeSucc<-v$AllNative+v$Succ  # For models that combine all soil types+successional
v$AllExceptMargin<-v$AllNative+v$UNK+v$Water+v$Succ+v$Alien  # For models that combine everything, but leave Wetland Margin separately.  Check that this works: table(v$AllExceptMargin,v$WetlandMargin)

# Add lat long, natural regions, etc. to sites
# First add in nearest.sites for non-ABMI studies that do not have that info in the deployment name
s1<-read.csv(deploymentlocationsfile,stringsAsFactors=FALSE)  # Summarized from larger meta-data file - changes include adding nearest site where obvious from Deployment name, changing column names back to original names
s1$Year<-NULL  # No need for Year in this file - just creates duplicates in merge below
names(s1)[which(names(s1)=="Site.Name")]<-"location"
s1$Lat<-as.numeric(as.character(s1$Public.Latitude))
s1$Long<-as.numeric(as.character(s1$Public.Longitude))
# Do corrections for old/unique naming systems, where possible
s1$location<-gsub("-000","-",s1$location)
s1$location<-gsub("-00","-",s1$location)
s1$location<-gsub("-0","-",s1$location)
s1$location<-ifelse(substr(s1$location,1,5)=="ABMI-",substr(s1$location,6,nchar(s1$location)),s1$location)  # Remove initial "ABMI-" because not used in density file locations (but leave in other cases, like "OG-ABMI-...")
s1<-s1[duplicated(s1$location)==FALSE,]  # Get rid of duplicated locations
d1<-merge(d1,s1[,c("location","NearestSite","Long","Lat")],all.x=TRUE)  # Check for loss of info: d1$location[is.na(d1$NearestSite)] - AUB grid, a few LID, a few others
d1<-d1[!is.na(d1$NearestSite),]  # Get rid of those deployments without nearest site info or lat/long
d1$NearestSite<-as.numeric(as.character(d1$NearestSite))  # Warning message about NA's is okay - trying to change some "" records for NA's here
s<-read.csv(siteinfofile)  # To get ABMI site lat longs, and then natural regions via nearest ABMI sites
names(s)[which(names(s)=="PUBLIC_LONGITUDE")]<-"Long"
names(s)[which(names(s)=="PUBLIC_LATTITUDE")]<-"Lat"
names(s)[which(names(s)=="NATURAL_REGIONS")]<-"NR"
names(s)[which(names(s)=="NATURAL_SUBREGIONS")]<-"NSR"
names(s)[which(names(s)=="LANDUSE_FRAMEWORK")]<-"LUF"
for (i in 1:nrow(d1)) {  # Fill in missing nearest ABMI sites
  if (is.na(d1$NearestSite[i]) & !is.na(d1$Lat[i])) d1$NearestSite[i]<-s$SITE_ID[which.min(sqrt((d1$Long[i]-s$Long)^2 + (d1$Lat[i]-s$Lat)^2))]  # The nearest site based on lat long (without worrying about different km-scaling of lat and long here)
}
names(s)[which(names(s)=="pAspen_mean")]<-"pAspen"  # Change back to old name, used throughout subsequent scripts
q<-merge(d1,s[,c("SITE_ID","pAspen","NR","NSR","LUF","AHM","PET","FFP","MAP","MAT","MCMT","MWMT")],by.x="NearestSite",by.y="SITE_ID")  # Check for loss of sites
# Modify lat to reduce influence of northern sites on spatial models
q$TrueLat<-q$Lat
q$Lat<-ifelse(q$Lat>56.5,56.5,q$Lat)
# Then merge in veg
v$location_project<-paste(v$location,v$project,sep="_")
q0<-merge(q,v[,-(1:4)],by="location_project")  # Many sites lost from q (=d1) because in North and so no soils info in v.  So check for sites in v that didn't make it into q0: v$location[is.na(match(v$location,q0$location))]  Should all be weird projects, or North sites that had SoilHF info for some reason (probably HF)
d<-q0

# Remove sites not in South (grassland, parkland and dry mixedwood south of 56.7N), and also cutblocks and areas without soil info
d$UseAsSouth<-ifelse(d$NR=="Grassland" | d$NR=="Parkland" | d$NSR=="Dry Mixedwood","Y","N")
d$UseAsSouth<-ifelse(d$TrueLat>56.7,"N",d$UseAsSouth)
d<-d[d$UseAsSouth=="Y" & !is.na(d$UseAsSouth),]
d<-d[d$CutBlocks==0,]  # Not included in South models
d<-d[!is.na(d$UNK) & d$UNK==0,]  # Can't use deployments without soil info

# Add extra roll up HF types for models and factor for Peace River Area
d$EnSoftLinSeismic<-d$EnSoftLin+d$EnSeismic
d$SoftLin<-d$EnSoftLin+d$EnSeismic+d$TrSoftLin
d$PeaceRiver<-ifelse(d$TrueLat>54.5 & d$Long< -115,TRUE,FALSE)

# Add Lured info
lure<-read.csv(lurefile)
lure<-lure[duplicated(lure$location_project)==FALSE,]  # Not sure why there are duplicated records here
names(lure)[which(names(lure)=="lure")]<-"Lured"  # Keep the same as previous version, for subsequent scripts
q<-merge(d,lure[,c("location_project","Lured")],all.x=TRUE)  # Check for NAs in Lured - figure out correct value and add to lure file
d<-q

# Add weights for each record - because some sites sampled >1 time
# Eliminate summer records for any deployment with <10 days summer sampling, and ditto for winter.  And eliminate entirely any deployments that don't qualify in either season
names(d)[which(names(d)=="summer")]<-"SummerDays"  # Using previous name, because too late in the day to change this through the scripts!
names(d)[which(names(d)=="winter")]<-"WinterDays"  # Using previous name, because too late in the day to change this through the scripts!
d<-d[d$SummerDays>=10 | d$WinterDays>=10,]
i<-which(d$SummerDays<10)
j<-which(regexpr("Summer",names(d))>0)
j<-j[-1]  # First column is for Days - leave as is
d[i,j]<-NA  # Convert SummerDays to NA if SummerDays is <10 (and not already NA)
i<-which(d$WinterDays<10)
j<-which("Winter" %in% names(d)==TRUE)
j<-j[-1]  # First column is for Days - leave as is
d[i,j]<-NA
# Then weights based on number of qualifying visits (for each season)
q<-by(ifelse(d$SummerDays>=10,1,0),d$location,sum)
d$wt.s<-1/as.numeric(q[match(d$location,names(q))])
d$wt.s<-ifelse(d$wt.s==Inf,0,d$wt.s)  # no weight to locations that have never been sampled (10+ days) in summer
q<-by(ifelse(d$WinterDays>=10,1,0),d$location,sum)
d$wt.w<-1/as.numeric(q[match(d$location,names(q))])
d$wt.w<-ifelse(d$wt.w==Inf,0,d$wt.w)  # no weight to locdeploymentsation that have never been sampled (10+ days) in winter

# Set up list of species to analyse, separately for summer and winter
# Includes main analysis list as SpTable, and larger group to do use/availability for as SpTable.ua
FirstSpCol.s<-which(names(d)=="BadgerSummer")  # Find species names. Check if species list changes
LastSpCol.s<-which(names(d)=="WoodlandCaribouSummer")
FirstSpCol.w<-which(names(d)=="BadgerWinter")  # Find species names
LastSpCol.w<-which(names(d)=="WoodlandCaribouWinter")
# Summer species table
SpTable.s<-SpTable.s.ua<-names(d)[FirstSpCol.s:LastSpCol.s] # All speciesXseasons
SpTable.s<-SpTable.s[regexpr("Summer",SpTable.s)>0]  # and Summer only
SpTable.s.ua<-SpTable.s.ua[regexpr("Summer",SpTable.s.ua)>0]  # and Summer only
occ1.s<-NULL  # Figure out total number of occurrences of each species
for (i in 1:length(SpTable.s)) occ1.s[i]<-sum(sign(d[,SpTable.s[i]])*d$wt.s,na.rm=TRUE)
SpTable.s<-SpTable.s[-which(occ1.s<20)]  # Omit species with <20 occurrences
occ1.s<-NULL  # Figure out total number of occurrences of each species
for (i in 1:length(SpTable.s.ua)) occ1.s[i]<-sum(sign(d[,SpTable.s.ua[i]])*d$wt.s,na.rm=TRUE)  # Do not exclude parkland here,  - now used in use/availability in north (otherwise, no figures for veg ua of parkland species)
SpTable.s.ua<-SpTable.s.ua[-which(occ1.s<3)]  # Omit species with <3 occurrences for use/availability summaries
# and winter species table
SpTable.w<-SpTable.w.ua<-names(d)[FirstSpCol.w:LastSpCol.w] # All speciesXseasons
SpTable.w<-SpTable.w[regexpr("Winter",SpTable.w)>0]  # and Winter only
SpTable.w.ua<-SpTable.w.ua[regexpr("Winter",SpTable.w.ua)>0]  # and Winter only
occ1.w<-NULL  # Figure out total number of occurrences of each species
for (i in 1:length(SpTable.w)) occ1.w[i]<-sum(sign(d[,SpTable.w[i]])*d$wt.w,na.rm=TRUE)
SpTable.w<-SpTable.w[-which(occ1.w<20)]  # Omit species with <20 occurrences
occ1.w<-NULL  # Figure out total number of occurrences of each species
for (i in 1:length(SpTable.w.ua)) occ1.w[i]<-sum(sign(d[,SpTable.w.ua[i]])*d$wt.w,na.rm=TRUE)  # Do not exclude parkland here,  - now used in use/availability in north (otherwise, no figures for veg ua of parkland species)
SpTable.w.ua<-SpTable.w.ua[-which(occ1.w<3)]  # Omit species with <3 occurrences for use/availability summaries

#SpTable.w<-SpTable.w[SpTable.w!="FisherWinter"]  # These species do not need South models, and only have winter occurrences
SpTable.w<-SpTable.w[SpTable.w!="RedSquirrelWinter" & SpTable.w!="FisherWinter"]  # These species do not need South models, and only have winter occurrences

# Read prediction matrix into pm, so that it will be available in next step
pm<-read.csv(pmfile)

save(file=dataset.out,d,FirstSpCol.s,LastSpCol.s,FirstSpCol.w,LastSpCol.w,SpTable.s,SpTable.s.ua,SpTable.w,SpTable.w.ua,pm)

