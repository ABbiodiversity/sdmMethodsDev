# Initial step to process 1km2 province-wide grid info file - soil + HF for SOUTH
# The south region includes all areas that have soil information.  So one step here is to exclude km2 units that have no soil information.
# This is made more complex because we need to base that on the reference map, since we don't know if soil info is available for current units that are 100% HF.  So, the current and reference have to be processed together, despite the risk of memory problems.

km2hffile<-"C:/Dave/ABMI/Data/Km2 grid/2020/veg-hf_grid_v61hf2016v3WildFireUpTo2016.Rdata" # 1km2 grid veg+hf R object from Peter
km2infofile<-"C:/Dave/ABMI/Data/Km2 grid/2017/kgrid_table_km.Rdata"   # 1km2 grid info from Daiyuan processed by Peter - lat long, natural region, subregion, climate variables, etc.
HFgroupfile<-"C:/Dave/ABMI/Data/Site info/2020/lookup-soil-hf-v2020.csv"  # Lookup table for HF to HF group from Peter included as part of soil lookup Oct 2020.
soilgroupfile<-"C:/Dave/ABMI/Data/Site info/2020/lookup-soil-hf-v2020.csv"  # Lookup table for soils to soil group Oct 2020

km2file.out<-"C:/Dave/ABMI/Data/Km2 grid/2020/R km2 grid current and backfilled processed 2016 SOUTH Oct 2020.Rdata"  # File to save processed km2 grid files

# Load 1km2 soil+HF and convert to data frame (and hope memory doesn't explode)
load(km2hffile)  # dd_kgrid with [["soil_current"]] and [["soil_reference"]] relevant here
soil_current<-dd_kgrid[["soil_current"]]
soil_reference<-dd_kgrid[["soil_reference"]]
rm(dd_kgrid)  # To save memory
gc()
# Convert to data.frame, and convert areas to proportions of km2 unit
soil_current<-data.frame(as.matrix(soil_current))  # Convert to data.frame
km2.area<-rowSums(soil_current)
for (i in seq(1,nrow(soil_current),10000)) {  # Convert to proportions in chunks, otherwise memory fails
  print(paste(i,nrow(soil_current),date()))
  j<-ifelse(i+9999>nrow(soil_current),nrow(soil_current),i+9999)
  soil_current[i:j,]<-soil_current[i:j,]/km2.area[i:j]
}
soil_current$LinkID<-rownames(soil_current)
# Have to process reference at this point, because there is no other way of knowing which 1km2 rasters had no soil information if they are currently 100% HF
soil_reference<-data.frame(as.matrix(soil_reference))  # Convert to data.frame
km2.area<-rowSums(soil_reference)
for (i in seq(1,nrow(soil_reference),10000)) {  # Convert to proportions in chunks, otherwise memory fails
  print(paste(i,nrow(soil_reference),date()))
  j<-ifelse(i+9999>nrow(soil_reference),nrow(soil_reference),i+9999)
  soil_reference[i:j,]<-soil_reference[i:j,]/km2.area[i:j]
}
soil_reference$LinkID<-rownames(soil_reference)

# Add in info about km2 rasters - lat, long, natural region and subregion, LUF
load(km2infofile)  # kgrid with info for km2 rasters
names(kgrid)[which(names(kgrid)=="POINT_X")]<-"Long"
names(kgrid)[which(names(kgrid)=="POINT_Y")]<-"TrueLat"
kgrid$Lat<-ifelse(kgrid$TrueLat>56.5,56.5,kgrid$TrueLat)  # Modified latitude when applying spatial models, to reduce influence of sites in northern parkland
kgrid<-data.frame(LinkID=rownames(kgrid),kgrid[,c("Lat","Long","TrueLat","NRNAME","NSRNAME","LUF_NAME","AHM","PET","FFP","MAP","MAT","MCMT","MWMT")],pAspen=kgrid$pAspen)
names(kgrid)[which(names(kgrid)=="NRNAME")]<-"NR"  # Simpler and consistent with last year
names(kgrid)[which(names(kgrid)=="NSRNAME")]<-"NSR"
names(kgrid)[which(names(kgrid)=="LUF_NAME")]<-"LUF"
km2<-merge(soil_current,kgrid,by="LinkID")  # Check for loss of data - dimenstions of km2 and soil_current should be the same
rm(soil_current)
gc()
km2.b<-merge(soil_reference,kgrid,by="LinkID")    # Check for loss of data - dimenstions of km2.b and soil_reference should be the same
rm(soil_reference)
gc()

# Reduce both current and reference to just 1km2 rasters that have soil information, and south of 56.7N
# This is complicated by the fact that water is added, so km2 rasters with no soil information can still have <100% UNK soil because of water
i<-which(km2.b$UNK==0 & km2.b$UNK+km2.b$Water<0.99)  # km2 rasters that have no unknown soil and that are not dominated by water.  This excludes water-dominated rasters within the soils area, but these are not mapped anyway.
km2<-km2[i,]
km2.b<-km2.b[i,]  # Assumes LinkIDs are in same order in km2 and km2.b - check
km2<-km2[km2$TrueLat<56.7,]
km2.b<-km2.b[km2.b$TrueLat<56.7,]

# Combine soil types
Soilgl<-read.csv(soilgroupfile)  # Soil group lookup - needs to be modified if someone wants to use different soil groupings
Soilgl<-Soilgl[Soilgl$Sector=="Native",]
names(Soilgl)[which(names(Soilgl)=="o..ID")]<-"ID"  # Use old name from mid-2020 lookup table to avoid changing script below
Soilgroups<-unique(Soilgl$UseInAnalysis)
for (i in Soilgroups) {  # Go through each soil group, figure out which finer soil types are in that group, and sum their areas
  Soiltypesingroup<-colnames(km2)[na.omit(match(Soilgl$ID[Soilgl$UseInAnalysis==i],colnames(km2)))]
  if (length(Soiltypesingroup)>1) {
    km2<-cbind(km2,rowSums(km2[,Soiltypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    km2<-cbind(km2,km2[,Soiltypesingroup])  # If there is only one soil type in that HF group, just add it
  }
}
names(km2)<-c(names(km2)[1:(ncol(km2)-length(Soilgroups))],as.character(Soilgroups))
# Add WetlandMargin type (always =0, because doesn't exist in GIS)
km2$WetlandMargin<-0
# And for back-filled
for (i in Soilgroups) {  # Go through each soil group, figure out which finer soil types are in that group, and sum their areas
  Soiltypesingroup<-colnames(km2.b)[na.omit(match(Soilgl$ID[Soilgl$UseInAnalysis==i],colnames(km2.b)))]
  if (length(Soiltypesingroup)>1) {
    km2.b<-cbind(km2.b,rowSums(km2.b[,Soiltypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    km2.b<-cbind(km2.b,km2.b[,Soiltypesingroup])  # If there is only one soil type in that HF group, just add it
  }
}
names(km2.b)<-c(names(km2.b)[1:(ncol(km2.b)-length(Soilgroups))],as.character(Soilgroups))
# Add WetlandMargin type (always =0, because doesn't exist in GIS)
km2.b$WetlandMargin<-0

# Group HF types (current only - no HF in back-filled)
HFgl<-read.csv(HFgroupfile)  # HF group lookup
HFgl<-HFgl[HFgl$Sector!="Native",]  # HF now included in soil types
names(HFgl)[which(names(HFgl)=="o..ID")]<-"HF_GROUP"  # Use old name from early 2020 lookup table to avoid changing script below
HFgroups<-unique(HFgl$UseInAnalysis)
HFgroups<-HFgroups[-which(HFgroups=="HFor")]   # Not used in south
for (i in HFgroups) {  # Go through each HF group, figure out which finer HF types are in that group, and sum their areas
  HFtypesingroup<-colnames(km2)[na.omit(match(HFgl$HF_GROUP[HFgl$UseInAnalysis==i],colnames(km2)))]
  if (length(HFtypesingroup)>1) {
    km2<-cbind(km2,rowSums(km2[,HFtypesingroup])) # Add a column for each HF group, summing the component HF types
  } else {
    km2<-cbind(km2,km2[,HFtypesingroup])  # If there is only one HF type in that HF group, just add it
  }
}
names(km2)<-c(names(km2)[1:(ncol(km2)-length(HFgroups))],as.character(HFgroups))

save(file=km2file.out,km2,km2.b)


