# R ABMI coefficients analysis for mammals in the south
# It uses only the best soil+HF and age model for map predictions and figures
# This is the non-bootstrap version, with figures and maps to check results
# Data has already been processed to density (/km2)
# Run step 1 first to set up the data files, and also km2 processing

library(mgcv)  # For binomial GAM
library(mapproj)  # For projected maps
library(binom)  # For exact binomial confidence intervals
library(pROC)  # For AUC of ROC

# Set up file names for various outputs
fname.fig<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Figures/Best model/"  # Start of figure file, one per species for veg+HF.  Subdirectory, species name and extension will be added
fname.map<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Maps/"  # Start of map file, one per species for, spatial+climate map, current, reference and difference maps.  Subdirectory, species name and extension will be added.  Note: the web uses only whole-province maps, so naming here can be non-official
fname.sumout<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Coefficient tables/Mammal coefficients South Nov 2021 Best model"  # For exporting coefficient tables
fname.Robjects<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/R objects/R objects South mammal coefficients Nov 2021 Best model"  # Start of file name to save each species' models
fname.Robjects.sum<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/R objects/R objects South mammals Coefficient tables Nov 2021 Best model.Rdata"
fname.km2summaries<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Km2 summaries/Best model/Km2 South reference and current Nov 2021" # Start of file name for km2 grid reference and current output for each species
fname.useavail<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Figures/Use availability/"  # Subdirectory for use-availability figures and table
km2file.out<-"C:/Dave/ABMI/Data/Km2 grid/2020/R km2 grid current and backfilled processed 2016 SOUTH Oct 2020.Rdata"    # File with processed km2 grid files

# File name for previously processed datafile+veg+HF, km2 grid info, SpTable, and look-up matrix for veg groups
dataset.out<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/R Dataset SpTable for ABMI South mammal coefficients Nov 2021.RData"
load(dataset.out)
d<-d[d$Water==0,]
SpTable<-sort(unique(c(gsub("Summer","",SpTable.s),gsub("Winter","",SpTable.w))))
SpTable.ua<-sort(unique(c(gsub("Summer","",SpTable.s.ua),gsub("Winter","",SpTable.w.ua))))

# Specify space/climate model options for each species in SpTable  1=based on total abundance, 2=based on presence/absence only, 3=none.  Based on results of cross-validation at site and regional level.
sc.option<-rep(2,length(SpTable))
#sc.option[match(c("Coyote","Muledeer"),SpTable)]<-1  # NOTE: Offsets may not be working sensibly with total abundance
#sc.option[match(c("Elk","WhitetailedDeer"),SpTable)]<-3  # Can't match the patchy herd distribution for elk, or get sensible results for WTD
data.frame(SpTable,sc.option)  # Check that these are in right order

taxa.file<-read.csv("C:/Dave/ABMI/Data/Mammals/Mammal taxa.csv")  # To get proper species names
sp.names<-as.character(taxa.file$Species[match(SpTable,taxa.file$Label)])
sp.names.ua<-as.character(taxa.file$Species[match(SpTable.ua,taxa.file$Label)])
SeasName<-c("Summer","Winter")  # For labeling figures, etc.

# Figure parameters set up based on any possible variable in the soil+HF models
fp<-read.csv("C:/Dave/ABMI/Cameras/Coefficients/2020/Analysis south/Soil HF plot lookup.csv")  # Figure parameters, set up for all possible variables
fp$col1<-as.character(fp$col1)

load(km2file.out)
km2$Intercept<-1
km2.b$Intercept<-1
km2$PeaceRiver<-ifelse(km2$TrueLat>54.5 & km2$Long< -115,1,0)
km2.b$PeaceRiver<-ifelse(km2.b$TrueLat>54.5 & km2.b$Long< -115,1,0)

load("C:/Dave/ABMI/Data/Km2 grid/R object water dominated km2.rdata")  # Water-dominated km2 rasters to add to maps km2.water

# Set up km2 prediction matrices
# For climate+space effects only - for diagnostic mapping of these effects
km2.sc<-data.frame(km2[,c("Intercept","Lat","Long","TrueLat","AHM","PET","FFP","MAP","MAT","MCMT","MWMT","PeaceRiver")],Lat2=km2$Lat^2,Lat3=km2$Lat^3,Long2=km2$Long^2,LatLong=km2$Lat*km2$Long,Lat2Long2=km2$Lat^2*km2$Long^2,
                   LongMAT=km2$Long*km2$MAT,MAPPET=km2$MAP*km2$PET,MATAHM=km2$MAT*km2$AHM,MAPFFP=km2$MAP*km2$FFP,MAT2=km2$MAT*(km2$MAT+10),MWMT2=km2$MWMT^2)
DF.res.null<-data.frame(Lat=mean(d$Lat),Long=mean(d$Long),AHM=mean(d$AHM),PET=mean(d$PET),FFP=mean(d$FFP),MAP=mean(d$MAP),MAT=mean(d$MAT),MCMT=mean(d$MCMT),MWMT=mean(d$MWMT),
                        Lat2=mean(d$Lat)^2,Long=mean(d$Long)^2,LatLong=mean(d$Lat)*mean(d$Long),MAPPET=mean(d$MAP)*mean(d$PET),MATAHM=mean(d$MAT)*mean(d$AHM),MAPFFP=mean(d$MAP)*mean(d$FFP),MAT2=mean(d$MAT)^2,MWMT2=mean(d$MWMT)^2,
                        PeaceRiver=0)  # Means, used to plot residual relationships
# Truncate mapped area to just approximate polygon around sampled points.  Polygon determined by trial and error from map
jpeg(file="C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Maps/Spatial projection area SOUTH.jpg",height=600,width=400)
dplot(km2$Long,km2$TrueLat,pch=16,cex=0.3)  # Southern region
points(d$Long,d$TrueLat,pch=16,cex=1,col="red")  # Sampled points
#poly.long<-c(-118.5,-117.9,-115.2,-112.5,-112.7,-120.1,-120.1,-118.5)
#poly.lat<-c(52,57.4,58.2,58.8,60.1,60.1,52,52)
#pip<-in.out(matrix(c(poly.long,poly.lat),c(length(poly.long),2)),matrix(c(km2$Long,km2$TrueLat),c(nrow(km2),2)))
pip<-rep(FALSE,nrow(km2))  # Not using any mapping restriction polygon now
points(km2$Long[pip==TRUE],km2$TrueLat[pip==TRUE],col="grey80",pch=16,cex=0.3)
points(d$Long,d$TrueLat,pch=16,cex=1,col="red2")  # Sampled points
km2.sc<-km2.sc[pip==FALSE,]
km2.1<-km2[pip==FALSE,]  # This has all km2 variables, including veg+HF for full projections
km2.b.1<-km2.b[pip==FALSE,]  # This has all km2 variables, including veg+HF for full projections
graphics.off()

# Set up information for mapping
city.y<-c(51,53,49,56,58,55)+c(3,33,42,44,31,10)/60
city.x<- -c(114,113,112,111,117,118)-c(5,30,49,23,8,48)/60
city<-c("Calgary","Edmonton","Lethbridge","Fort McMurray","High Level","Grande Prairie")
m<-mapproject(c(km2.sc$Long,city.x,km2.water$Long),c(km2.sc$TrueLat,city.y,km2.water$Lat),projection="albers",par=c(49,60))  # These have to be projected together, otherwise get slightly different results, don't know why
km2.sc$proj.x<-m$x[1:nrow(km2.sc)]  # Projected x-value for km2 raster longitudes
km2.sc$proj.y<-m$y[1:nrow(km2.sc)]  # Projected y-value for km2 raster latitudes
m.city.x<-m$x[(nrow(km2.sc)+1):(nrow(km2.sc)+length(city))]  # Projected x for cities locations
m.city.y<-m$y[(nrow(km2.sc)+1):(nrow(km2.sc)+length(city))]  # Projected y for cities locations
m.water<-data.frame(x=m$x[(nrow(km2.sc)+length(city)+1):length(m$x)],y=m$y[(nrow(km2.sc)+length(city)+1):length(m$y)])
m.title<-mapproject(-115,60.5,projection="albers",par=c(49,60))  # Just coordinates for the map title
c1<-rev(c("#D73027","#FC8D59","#FEE090","#E0F3F8","#91BFDB","#4575B4"))  # Colour gradient for reference and current
c2<-colorRampPalette(c1, space = "rgb") # Function to interpolate among these colours for reference and current
d1<-c("#C51B7D","#E9A3C9","#FDE0EF","#E6F5D0","#A1D76A","#4D9221")  # Colour gradient for difference map
d2<-colorRampPalette(d1, space = "rgb") # Function to interpolate among these colours for difference map

# Set up variables to store results
vnames.b<-c("ClaySub","Other","RapidDrain","Loamy","SandyLoam","ThinBreak","Blowout")  # Variable names to use in reference predictions
# .pa used for presence/absence components, .agp for abundance-given-presence, .sc for space/climate, .s for summer, .w for winter
vnames.pa<-c("Loamy","SandyLoam","RapidDrain","ClaySub","ThinBreak","Blowout","Other","RoughP","TameP","Crop","Rural","Urban","Industrial","Mine","Well","HardLin","EnSoftLin","EnSeismic","TrSoftLin","WetlandMargin")  # Names of coefficients
Coef.pa<-Coef.pa.se<-array(0,c(2,length(SpTable),length(vnames.pa)))  # Set up tables to store coefficients and their SE's - Season, species, variable
dimnames(Coef.pa)<-dimnames(Coef.pa.se)<-list(c("Summer","Winter"),SpTable,vnames.pa)
vnames.agp<-c("Loamy","SandyLoam","RapidDrain","ClaySub","ThinBreak","Blowout","Other","RoughP","TameP","Crop","Rural","Urban","Industrial","Mine","Well","HardLin","EnSoftLin","EnSeismic","TrSoftLin","WetlandMargin")  # Names of coefficients
Coef.agp<-Coef.agp.se<-array(0,c(2,length(SpTable),length(vnames.agp)))  # Set up tables to store coefficients and their SE's - Season, species, variable
dimnames(Coef.agp)<-dimnames(Coef.agp.se)<-list(c("Summer","Winter"),SpTable,vnames.agp)
Coef.mean<-Coef.lci<-Coef.uci<-array(0,c(2,length(SpTable),length(vnames.pa)))  # To store combined presence * abundance|presence estimates and their CI's (CI's because not symmetrical SE's) - Season, species, variable
dimnames(Coef.mean)<-dimnames(Coef.lci)<-dimnames(Coef.uci)<-list(c("Summer","Winter"),SpTable,vnames.agp)
Coef.pa.all<-Coef.pa.lci.all<-Coef.pa.uci.all<-Coef.mean.all<-Coef.lci.all<-Coef.uci.all<-array(0,c(length(SpTable),length(vnames.pa)))  # To store combined presence * abundance|presence estimates and their CI's (CI's because not symmetrical SE's) - average of Summer and Winter
colnames(Coef.pa.all)<-colnames(Coef.pa.lci.all)<-colnames(Coef.pa.uci.all)<-colnames(Coef.mean.all)<-colnames(Coef.lci.all)<-colnames(Coef.uci.all)<-vnames.pa
rownames(Coef.pa.all)<-rownames(Coef.pa.lci.all)<-rownames(Coef.pa.uci.all)<-rownames(Coef.mean.all)<-rownames(Coef.lci.all)<-rownames(Coef.uci.all)<-SpTable
vnames.sc<-c("Intercept","Lat","Long","LatLong","Lat2","Lat3","Long2","Lat2Long2","PET","AHM","MAT","FFP","MAP","MAPFFP","MAPPET","MATAHM","MWMT","MCMT","MWMT2","MAT2","LongMAT","PeaceRiver")
Res.coef<-array(0,c(length(SpTable),length(vnames.sc))) # Done for both seasons together
colnames(Res.coef)<-vnames.sc
rownames(Res.coef)<-SpTable
Coef.pAspen.pa<-Coef.se.pAspen.pa<-Coef.pAspen.agp<-Coef.se.pAspen.agp<-array(0,c(2,length(SpTable)))  # To store separate coefficient for pAspen effect - Season, species
dimnames(Coef.pAspen.pa)<-dimnames(Coef.se.pAspen.pa)<-dimnames(Coef.pAspen.agp)<-dimnames(Coef.se.pAspen.agp)<-list(c("Summer","Winter"),SpTable)
Coef.pAspen.pa.all<-Coef.se.pAspen.pa.all<-Coef.pAspen.agp.all<-Coef.se.pAspen.agp.all<-NULL  # For pAspen coefficients averaged across seasons
lure.pa<-lure.agp<-array(NA,c(2,length(SpTable)))  # To store lure coefficients for pres/abs, abundance | presence - Season, species
# Arrays to save aic weights for each age model, and for which sets of models are best.
aic.wt.pa.save<-array(NA,c(2,length(SpTable),30))  # To save aic weights for each species, presence/absence - Season, species, model.  Need to change the second dimension if number of models changes
aic.wt.agp.save<-array(NA,c(2,length(SpTable),30))  # To save aic weights for each species, abundance|presence.  . - Season, species, model.  Need to change the second dimension if number of models changes
dimnames(aic.wt.pa.save)<-dimnames(aic.wt.agp.save)<-list(c("Summer","Winter"),SpTable)
auc.fit<-NULL  # AUC for the presence/absence fit, one value for each species

# Loop through species
# For each species, models are fit for summer (and coefficient figures plotted), then for winter (and coefficient figures plotted), then results are combined (and plotted) and space/climate residual models are fit (and maps are plotted)
for (sp in 1:length(SpTable)) {
  d1<-data.frame(location_project=d$location_project,Lured=d$Lured,count.summer=NA,count.winter=NA,p.pa.summer=NA,p.agp.summer=NA,p.summer=NA,p.pa.winter=NA,p.agp.winter=NA,p.winter=NA)  # Set up data.frame to keep counts and predictions for the species for each season - to use in SC modeling using residuals after year-round average prediction
  # Loop through seasons
  for (seas in 1:2) { # 1=Summer, 2=Winter
    if (seas==1) {  # Set season-specific variables
      SpSeas<-paste(SpTable[sp],"Summer",sep="")
      SeasDays<-d$SummerDays
      SeasWt<-d$wt.s  # Set up in first script
    }
    if (seas==2) {
      SpSeas<-paste(SpTable[sp],"Winter",sep="")
      SeasDays<-d$WinterDays
      SeasWt<-d$wt.w  # Set up in first script
    }
    if ((seas==1 & SpSeas%in%SpTable.s==TRUE) | (seas==2 & SpSeas%in%SpTable.w==TRUE)) {  #Only run if that species is in the species table for that season
      print(paste(sp,length(SpTable),SpTable[sp],seas,date()))
      d.sp<-d[,c(1:(FirstSpCol.s-1),(LastSpCol.w+1):ncol(d),which(colnames(d)==SpSeas))]  # Extract site descriptors and just the target species.  Assumes species columns are Sp1Summer, Sp1Winter...SpnSummer, SpnWinter
      colnames(d.sp)[ncol(d.sp)]="Count"  # Change the species count column name to "Count"
      i<-which(!is.na(d.sp$Count) & SeasDays>10)  # Use use locations with sampling in that season and enough days
      d.sp<-d.sp[i,]
      SeasDays<-SeasDays[i]
      SeasWt<-SeasWt[i]
      # Calculate lure effect on pres/abs for that species
      d.sp$Lured<-as.character(d.sp$Lured)
      UseForLure<-grepl("^[[:digit:]]+",d.sp$location)  # Only use ongrid sites for lure calibration (paired lure/not).  These are now identified by locations starting with digits
      q<-by(sign(d.sp$Count[UseForLure==TRUE]),d.sp$Lured[UseForLure==TRUE],mean)
      lure.pa[seas,sp]<-q["Yes"]/q["No"]

      # 1. Fit models to soil types and HF types - presence/absence
      # 1.1 Fit soil models
      m.pa<-list(NULL)
      pCount<-sign(d.sp$Count)/ifelse(d.sp$Lured=="Yes",lure.pa[seas,sp],1)  # Standardize all to no-lure
      pCount<-pCount/max(pCount)  # This is in case the lure effect is <1
      d.sp$pCount.pa<-pCount  # Used in the age models below
      m.pa[[1]]<-try(glm(pCount~ClayWet+SandyLoam+RapidDrain+ThinBlow+RurUrbInd+Well+RoughP+TameP+Crop+EnSoftLinSeismic+TrSoftLin+WetlandMargin+SeasDays,
                         family="binomial",data=d.sp,weights=SeasWt))  # Intercept is Loamy.  HF types as finely divided as possible with data. Energy SoftLin with Sesimic, too few seismic
      m.pa[[2]]<-try(update(m.pa[[1]], .~. - SandyLoam - RapidDrain + SandyRapid))  # Intercept is Loamy. Combine sandy loam and rapid drain
      m.pa[[3]]<-try(update(m.pa[[1]], .~. - RapidDrain - ThinBlow - ClayWet + Nonproductive))  # Intercept is Loamy. Combine non-productive soils
      m.pa[[4]]<-try(update(m.pa[[3]], .~. - SandyLoam - Nonproductive))  # Intercept is all native soil.  Combine all soils
      m.pa[[5]]<-try(update(m.pa[[2]], .~. - Crop - TameP - RoughP + Cult))  # Intercept is Loamy. Combine cultivation and sandy loam and rapid drain
      m.pa[[6]]<-try(update(m.pa[[3]], .~. - Crop - TameP - RoughP + Cult))  # Intercept is Loamy. Combine cultivation and non-productive soils
      m.pa[[7]]<-try(update(m.pa[[4]], .~. - Crop - TameP - RoughP + Cult))  # Intercept is all native soil.  Combine cultivation and all soils
      m.pa[[8]]<-try(update(m.pa[[5]], .~. - RurUrbInd - Well + NonAgAlien - EnSoftLinSeismic - TrSoftLin + Succ))  # Intercept is Loamy. Combine non-ag alien and also combine successional (with sandy loam and rapid drain combined)
      m.pa[[9]]<-try(update(m.pa[[6]], .~. - RurUrbInd - Well + NonAgAlien - EnSoftLinSeismic - TrSoftLin + Succ))  # Intercept is Loamy. Combine non-ag alien and also combine successional (with non-productive combined)
      m.pa[[10]]<-try(update(m.pa[[7]], .~. - RurUrbInd - Well + NonAgAlien - EnSoftLinSeismic - TrSoftLin + Succ))  # Intercept is all native soil.  Combine non-ag alien and also combine successional (with all soils combined)
      m.pa[[11]]<-try(update(m.pa[[8]], .~. - NonAgAlien - Cult + Alien))  # Intercept is Loamy. Combine all alien (with sandy loam and rapid drain combined)
      m.pa[[12]]<-try(update(m.pa[[9]], .~. - NonAgAlien - Cult + Alien))  # Intercept is Loamy. Combine all alien (with non-productive combined)
      m.pa[[13]]<-try(update(m.pa[[10]], .~. - NonAgAlien - Cult + Alien))  # Intercept is all native soil.  Combine all alien (with all soils combined)
      m.pa[[14]]<-try(update(m.pa[[13]], .~. - Succ))  # Intercept is everything except alien and wetland margin.  Combine successional with all non-HF soils
      m.pa[[15]]<-try(update(m.pa[[14]], .~. - Alien))  # Intercept is everything except  wetland margin.  Combine alien with successional and all non-HF soils
      # Add models with pAspen term
      for (i in 1:15) m.pa[[i+15]]<-try(update(m.pa[[i]],.~.+pAspen))
      # AIC calculation  (I'm using AIC here, because this is primarily for prediction, rather than finding a minimal best model)
      nModels.pa<-length(m.pa)
      aic.ta<-rep(999999999,(nModels.pa))
      for (i in 1:(nModels.pa)) {
        if (!is.null(m.pa[[i]]) & class(m.pa[[i]])[1]!="try-error") {  # last part is to not used non-converged models, unless none converged
          aic.ta[i]<-AICc(m.pa[[i]])
        }
      }
      aic.delta<-aic.ta-min(aic.ta)
      aic.exp<-exp(-1/2*aic.delta)
      aic.wt.pa<-aic.exp/sum(aic.exp)
      best.model.pa<-which.max(aic.wt.pa)
      aic.wt.pa.save[seas,sp,]<-aic.wt.pa

      # 1.2 Then do abundance | presence model
      d.p<-d.sp[d.sp$Count>0,]  # Just presence records
      d.p$SeasDays<-SeasDays[d.sp$Count>0]
      UseForLure.p<-UseForLure[d.sp$Count>0]  # Adjust abundance for lure effect using only on grid ABMI sites
      q<-by(d.p$Count[UseForLure.p==TRUE],d.p$Lured[UseForLure.p==TRUE],mean)
      lure.agp[seas,sp]<-q["Yes"]/q["No"]
      pCount<-d.p$Count/ifelse(d.p$Lured=="Yes",lure.agp[seas,sp],1)
      j<-0
      m.agp<-list(NULL)
      mnums<-NULL  # To keep track of which models were actually fit
      for (i in 1:nModels.pa) {
        x<-min(colSums(d.p[,attr(m.pa[[i]]$terms,"term.labels")]))  # Minimum number of presence records in each veg+HF type included in the model
        if (x>3) {  # Only use the model if each type is represented by >3 presence records
          j<-j+1
          m.agp[[j]]<-glm(m.pa[[i]]$formula,data=d.p,family=gaussian(link="log")) # Note: Weights not being used here, because haven't tracked whether each species was present on more than one visit for revisited deployments
          mnums<-c(mnums,i)
        }
      }
      if (is.null(m.agp[[1]])) m.agp[[1]]<-glm(pCount~SeasDays,family=gaussian(link="log"),data=d.p)  # If there are no agp models (because there are never >3 records in each type in any model, incl. WetlandMargin that is in all models), use simple intercept+days
      # AIC calculation  (I'm using AIC here, because this is primarily for prediction, rather than finding a minimal best model)
      nModels.agp<-length(m.agp)
      aic.ta<-rep(999999999,(nModels.agp))
      for (i in 1:(nModels.agp)) {
        if (!is.null(m.agp[[i]]) & class(m.agp[[i]])[1]!="try-error") {  # last part is to not used non-converged models, unless none converged
          aic.ta[i]<-AICc(m.agp[[i]])
        }
      }
      aic.delta<-aic.ta-min(aic.ta)
      aic.exp<-exp(-1/2*aic.delta)
      aic.wt.agp<-aic.exp/sum(aic.exp)
      best.model.agp<-which.max(aic.wt.agp)
      aic.wt.agp.save[seas,sp,mnums]<-aic.wt.agp

      # 1.3 Predict from models for 100% of each veg type and for each site - pres/abs - using only the best model
      Intercept<-rep(c("Loamy","Loamy","Loamy","AllNative","Loamy","Loamy","AllNative","Loamy","Loamy","AllNative","Loamy","Loamy","AllNative","AllNativeSucc","AllExceptMargin"),2)[best.model.pa]   # Change this if models change
      terms.pa<-c(attr(m.pa[[best.model.pa]]$terms,"term.labels"),Intercept)
      Coef1.pa<-Coef1.pa.se<-rep(NA,length(terms.pa))
      names(Coef1.pa)<-names(Coef1.pa.se)<-terms.pa
      for (i in 1:length(terms.pa)) {
        pm1<-rep(0,length(terms.pa))
        pm1[i]<-1
        names(pm1)<-terms.pa
        pm1<-data.frame(t(pm1))
        p<-predict(m.pa[[best.model.pa]],newdata=data.frame(SeasDays=100,pAspen=0,pm1),se.fit=T)  # Predictions made at 0% Aspen.  Aspen effect added later, and plotted as separate points
        Coef1.pa[i]<-plogis(p$fit)  # Ordinal scale
        Coef1.pa.se[i]<-p$se.fit  # logit scale
      }
      # Adjust so that mean prediction at standardized SeasDays across all qualifying sites = mean observed count.  This is to compensate for inaccuracies due to fitting SeasDays coefficients
      pCount<-sign(d.sp$Count)/ifelse(d.sp$Lured=="Yes",lure.pa[seas,sp],1)  # Standardize all to no-lure
      pCount<-pCount/max(pCount)  # This is in case the lure effect is <1
      p.adj<-predict(m.pa[[best.model.pa]],newdata=data.frame(SeasDays=100,d.sp))  # Prediction for each data point, but at standardized days
      Coef1.pa<-plogis(qlogis(Coef1.pa)+qlogis(mean(pCount))-qlogis(mean(plogis(p.adj))))  # Adjustment made on logit scale.  Var doesn't change on logit scale(?)
      # And predict for each site - used for age model below
      d.sp$p<-predict(m.pa[[best.model.pa]])  # Logit scale

      # 1.4 Predict from models for 100% of each veg type and for each site - abund|pres
      terms.pa1<-terms.pa[terms.pa!="SeasDays"]
      terms.pa1<-terms.pa1[terms.pa1!="pAspen"]
      Coef1.agp<-Coef1.agp.se<-rep(NA,length(terms.pa1))  # For agp coefficients averaged to terms in best pa model
      names(Coef1.agp)<-names(Coef1.agp.se)<-terms.pa1
      i<-best.model.agp
      p<-predict(m.agp[[i]],newdata=data.frame(pm,SeasDays=100,pAspen=0),se.fit=T)  # For each type. Predictions made at 0% Aspen.  Aspen effect added later, and plotted as separate points
      tTypeMean.agp<-p$fit
      tTypeVar.agp<-p$se.fit^2  # Using variance, for consistency with other scripts at this point
      names(tTypeMean.agp)<-names(tTypeVar.agp)<-pm$VegType
      # Adjust so that mean prediction at standardized SeasDays across all qualifying sites = mean observed count.  This is to compensate for inaccuracies due to fitting SeasDays coefficients
      pCount<-d.p$Count/ifelse(d.p$Lured=="Yes",lure.agp[seas,sp],1)
      p.adj<-predict(m.agp[[i]],newdata=data.frame(SeasDays=100,d.p))  # Prediction for each data point, but at standardized days
      tTypeMean.agp<-log(exp(tTypeMean.agp)+mean(pCount)-mean(exp(p.adj)))  # Var doesn't change on log scale
      # Then average those for each broader group included in the best pa model
      for (i in 1:length(terms.pa1)) {
        j<-pm$VegType[which(pm[,terms.pa1[i]]==1)]  # Names of fine hab+HF types included in that broader group
        x<-tTypeMean.agp[as.character(j)]
        x.var<-tTypeVar.agp[as.character(j)]
        Coef1.agp[i]<-mean(x)  # Simple mean, log scale
        Coef1.agp.se[i]<-sqrt(mean(x.var))  # This is for straight-up mean, log scale
      }

      # 3. Assemble presence/absence coefficients for each soil+HF type to populate entire Coef.pa matrix, then multiply by appropriate Coef.agp term to generate Coef.mean matrix
      for (i in 1:length(terms.pa1)) {
        j<-as.character(pm$VegType[pm[,terms.pa1[i]]==1])  # The fine veg+HF types that are covered by the (potentially broader) variable included in the best model
        for (j1 in 1:length(j)) {
          # Stand types that do not have age classes in full coefficients
          Coef.pa[seas,sp,j[j1]]<-Coef1.pa[terms.pa1[i]]  # Fill in the non-age coefficient
          Coef.pa.se[seas,sp,j[j1]]<-Coef1.pa.se[terms.pa1[i]]  # Fill in the non-age coefficient
          Coef.agp[seas,sp,j[j1]]<-exp(Coef1.agp[terms.pa1[i]])  # Same for agp - using the classes in pa model - convert to ordinal scale
          Coef.agp.se[seas,sp,j[j1]]<-Coef1.agp.se[terms.pa1[i]]  # Fill in the non-age coefficient - still log scale
          Coef.mean[seas,sp,j[j1]]<-Coef.pa[seas,sp,j[j1]]*Coef.agp[seas,sp,j[j1]]
          Coef.lci[seas,sp,j[j1]]<-plogis(qlogis(Coef.pa[seas,sp,j[j1]])-Coef.pa.se[seas,sp,j[j1]]*1.28) * exp(log(Coef.agp[seas,sp,j[j1]])-Coef.agp.se[seas,sp,j[j1]]*1.28)  # Using 10% intervals for each to multiply to 5% intervals (assuming independence - checked empirically)
          Coef.uci[seas,sp,j[j1]]<-plogis(qlogis(Coef.pa[seas,sp,j[j1]])+Coef.pa.se[seas,sp,j[j1]]*1.28) * exp(log(Coef.agp[seas,sp,j[j1]])+Coef.agp.se[seas,sp,j[j1]]*1.28)  # Using 10% intervals for each to multiply to 5% intervals (assuming independence - checked empirically)
        }  # Next fine veg+HF type within broader class
      }  # Next broader class in best model

      # 3.1 Store pAspen coefficients
      if ("pAspen" %in% attr(m.pa[[best.model.pa]]$terms,"term.labels")) {
        Coef.pAspen.pa[seas,sp]<-m.pa[[best.model.pa]]$coef["pAspen"]  # Logit scale
        Coef.se.pAspen.pa[seas,sp]<-summary(m.pa[[best.model.pa]])$coef["pAspen","Std. Error"]
      } else {
        Coef.pAspen.pa[seas,sp]<-Coef.se.pAspen.pa[seas,sp]<-0
      }
      if ("pAspen" %in% attr(m.agp[[best.model.agp]]$terms,"term.labels")) {
        Coef.pAspen.agp[seas,sp]<-m.agp[[best.model.agp]]$coef["pAspen"]  # Logit scale
        Coef.se.pAspen.agp[seas,sp]<-summary(m.agp[[best.model.agp]])$coef["pAspen","Std. Error"]
      } else {
        Coef.pAspen.agp[seas,sp]<-Coef.se.pAspen.agp[seas,sp]<-0
      }

      # 3.2 Predictions for each site, as offsets below
      d.sp$t.p.pa<-colSums(Coef1.pa[terms.pa1]*t(d.sp[,terms.pa1]))  # Prediction of presence/absence at each site - ordinal scale
      d.sp$t.p.pa<-plogis(qlogis(d.sp$t.p.pa)+Coef.pAspen.pa[seas,sp]*d.sp$pAspen) # And pAspen effect
      d.sp$t.p.agp<-colSums(Coef1.agp[terms.pa1]*t(d.sp[,terms.pa1]))  # Prediction of abundance|presence at each site - log scale
      d.sp$t.p.agp<-d.sp$t.p.agp+Coef.pAspen.agp[seas,sp]*d.sp$pAspen # And pAspen effect (still log scale)
      d.sp$p.ta<-d.sp$t.p.pa*exp(d.sp$t.p.agp)  # Prediction (ordinal scale) of total abundance at each site

      # Further adjustments so that mean(Coef.mean) = mean(observed density).  Adjusts for geometric mean issue, and also for any remaining issues with Days adjustments.  Do at this point, because have predictions including pAspen effect
      pCount<-ifelse(d.sp$Lured=="Yes",d.sp$Count/(lure.pa[seas,sp]*lure.agp[seas,sp]),d.sp$Count)
      Coef.mean[seas,sp,]<-Coef.mean[seas,sp,]*mean(pCount)/mean(d.sp$p.ta)
      Coef.lci[seas,sp,]<-Coef.lci[seas,sp,]*mean(pCount)/mean(d.sp$p.ta)
      Coef.uci[seas,sp,]<-Coef.uci[seas,sp,]*mean(pCount)/mean(d.sp$p.ta)

      # 3.3 Store values for season
      j<-match(d.sp$location_project,d1$location_project)
      if (seas==1) {
        d1$count.summer[j]<-d.sp$Count
        d1$p.pa.summer[j]<-d.sp$t.p.pa
        d1$p.agp.summer[j]<-exp(d.sp$t.p.agp)
        d1$p.summer[j]<-d.sp$p.ta
      } else {
        d1$count.winter[j]<-d.sp$Count
        d1$p.pa.winter[j]<-d.sp$t.p.pa
        d1$p.agp.winter[j]<-exp(d.sp$t.p.agp)
        d1$p.winter[j]<-d.sp$p.ta
      }

      # 4. Coefficient figures
      # 4.1. Combined total abundance - Non-treed (pAspen set to 0 for Coef tables)
      # Custom figure for each best model and age options
      x<-col1<-y<-y.lci<-y.uci<-y1<-y1.lci<-y1.uci<-w<-class<-space1<-NULL
      for (i in 1:length(terms.pa1)) {
        j<-match(terms.pa1[i],fp$Class)
        x<-c(x,fp$x[j])
        veg.to.use<-as.character(pm$VegType[pm[,terms.pa1[i]]==1])[1]  # To use Coef.mean, find the first fine veg+HF types that is included in the (potentially broader) variable being plotted
        y<-c(y,Coef.mean[seas,sp,veg.to.use])
        y.lci<-c(y.lci,Coef.lci[seas,sp,veg.to.use])
        y.uci<-c(y.uci,Coef.uci[seas,sp,veg.to.use])
        y1<-c(y1,plogis(qlogis(Coef.pa[seas,sp,veg.to.use])+Coef.pAspen.pa[seas,sp])*exp(log(Coef.agp[seas,sp,veg.to.use])+Coef.pAspen.agp[seas,sp]))  # Add effect of aspen, on appropriate link scales, for treed figure
        col1<-c(col1,fp$col1[j])
        w<-c(w,fp$width[j])
        class<-c(class,terms.pa1[i])
        space1<-c(space1,fp$spaceafter[j])
      }
      y1.lci<-y.lci*y1/y  # This assumes no error in pAspen coefficient (because we don't have the covariances)
      y1.uci<-y.uci*y1/y  # This assumes no error in pAspen coefficient (because we don't have the covariances)
      ord<-order(x)  # Sort all by x
      y<-y[ord]
      y.lci<-y.lci[ord]
      y.uci<-y.uci[ord]
      y1<-y1[ord]
      y1.lci<-y1.lci[ord]
      y1.uci<-y1.uci[ord]
      col1<-col1[ord]
      w<-w[ord]
      class<-class[ord]
      space1<-space1[ord]
      x<-x[ord]
      # Rectify spaces between x's
      for (i in 1:(length(x)-1)) {
        for (j in (i+1):length(x)) x[j]<-x[j]+space1[i]-(x[i+1]-x[i])  # Alter all subsequent positions accordingly
      }
      # Make bar plot
      ymax<-min(max(c(y.uci,y1.uci),na.rm=TRUE),2*max(c(y,y1),na.rm=TRUE))  # This keeps the figures readable when there are extreme UCI's
      space<-c(1,x[-1]-x[-length(x)])-0.99  # The spacing between bars
      density<-ifelse(substr(class,1,2)=="CC",50,NA)
      fname<-paste(fname.fig,"Non-treed/Soil+HF figure best model ",SpTable[sp]," ",SeasName[seas],".png",sep="")
      png(file=fname,width=ifelse(length(y)>7,1500,1000),height=700)
      par(mai=c(1.9,1,0.2,0.3))
      x1<-barplot(y,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F)[,1]  # To get strips on CC bars - probably not needed here for South, but left anyway
      abline(h=pretty(c(0,ymax)),col="grey80")
      x1<-barplot(y,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]  # To get strips on CC bars, and to put bars in front of horizontal axis lines
      x1<-barplot(y,space=space,width=w,border="white",density=density,col=col1,ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]
      axis(side=2,tck=0.02,cex.axis=0.9,col.axis="grey50",col.ticks="grey50",las=2,at=pretty(c(0,ymax)))
      box(bty="l",col="grey50")
      for (i in 1:length(x1)) {
        lines(rep(x1[i],2),c(y[i],y.uci[i]),col=col1[i])
        lines(rep(x1[i],2),c(y[i],y.lci[i]),col="grey90")
      }
      mtext(side=1,at=x1,line=1,adj=0.5,class,col=col1,cex=1.2)
      mtext(side=3,at=x1[1],adj=0,paste(sp.names[sp],SeasName[seas],"- South Non-treed"),col="grey30",cex=1.2)
      text(max(x1),ymax*0.98,paste("Detected at",sum(sign(d.sp$Count)),"of",nrow(d.sp),SeasName[seas],"camera locations"),cex=1.1,adj=1,col="grey40") # Add sample size
      graphics.off()
      # And treed version
      ymax<-min(max(c(y.uci,y1.uci),na.rm=TRUE),2*max(c(y,y1),na.rm=TRUE))  # This keeps the figures readable when there are extreme UCI's
      space<-c(1,x[-1]-x[-length(x)])-0.99  # The spacing between bars
      density<-ifelse(substr(class,1,2)=="CC",50,NA)
      fname<-paste(fname.fig,"Treed/Soil+HF figure best model ",SpTable[sp]," ",SeasName[seas],".png",sep="")
      png(file=fname,width=ifelse(length(y)>7,1500,1000),height=700)
      par(mai=c(1.9,1,0.2,0.3))
      x1<-barplot(y1,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F)[,1]  # To get strips on CC bars - probably not needed here for South, but left anyway
      abline(h=pretty(c(0,ymax)),col="grey80")
      x1<-barplot(y1,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]  # To get strips on CC bars, and to put bars in front of horizontal axis lines
      x1<-barplot(y1,space=space,width=w,border="white",density=density,col=col1,ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]
      axis(side=2,tck=0.02,cex.axis=0.9,col.axis="grey50",col.ticks="grey50",las=2,at=pretty(c(0,ymax)))
      box(bty="l",col="grey50")
      for (i in 1:length(x1)) {
        lines(rep(x1[i],2),c(y1[i],y1.uci[i]),col=col1[i])
        lines(rep(x1[i],2),c(y1[i],y1.lci[i]),col="grey90")
      }
      mtext(side=1,at=x1,line=1,adj=0.5,class,col=col1,cex=1.2)
      mtext(side=3,at=x1[1],adj=0,paste(sp.names[sp],SeasName[seas],"- South Treed"),col="grey30",cex=1.2)
      text(max(x1),ymax*0.98,paste("Detected at",sum(sign(d.sp$Count)),"of",nrow(d.sp),SeasName[seas],"camera locations"),cex=1.1,adj=1,col="grey40") # Add sample size
      graphics.off()
    }  # End if for that species being in the species table for that season
  } # Next season

  # 5.1. Combine Summer and winter coefficients
  # Use these for mapping, below (pres/abs needed for cases where space/climate residual models are just for pres/abs)
  if (paste(SpTable[sp],"Summer",sep="") %in% SpTable.s  & paste(SpTable[sp],"Winter",sep="") %in% SpTable.w) {
    Coef.pa.all[sp,]<-(Coef.pa[1,sp,]+Coef.pa[2,sp,])/2
    Coef.mean.all[sp,]<-(Coef.mean[1,sp,]+Coef.mean[2,sp,])/2
    Coef.lci.all[sp,]<-(Coef.lci[1,sp,]+Coef.lci[2,sp,])/2
    Coef.uci.all[sp,]<-(Coef.uci[1,sp,]+Coef.uci[2,sp,])/2
  }
  if (paste(SpTable[sp],"Summer",sep="") %in% SpTable.s  & (paste(SpTable[sp],"Winter",sep="") %in% SpTable.w == FALSE)) {
    Coef.pa.all[sp,]<-Coef.pa[1,sp,]
    Coef.mean.all[sp,]<-Coef.mean[1,sp,]
    Coef.lci.all[sp,]<-Coef.lci[1,sp,]
    Coef.uci.all[sp,]<-Coef.uci[1,sp,]
  }
  if (paste(SpTable[sp],"Winter",sep="") %in% SpTable.w  & (paste(SpTable[sp],"Summer",sep="") %in% SpTable.s == FALSE)) {
    Coef.pa.all[sp,]<-Coef.pa[2,sp,]
    Coef.mean.all[sp,]<-Coef.mean[2,sp,]
    Coef.lci.all[sp,]<-Coef.lci[2,sp,]
    Coef.uci.all[sp,]<-Coef.uci[2,sp,]
  }

  Coef.pAspen.pa.all[sp]<-(Coef.pAspen.pa[1,sp]+Coef.pAspen.pa[2,sp])/2  # Assume simple mean on link scale
  Coef.se.pAspen.pa.all[sp]<-(Coef.se.pAspen.pa[1,sp]+Coef.se.pAspen.pa[2,sp])/2  # Assume simple mean on link scale
  Coef.pAspen.agp.all[sp]<-(Coef.pAspen.agp[1,sp]+Coef.pAspen.agp[2,sp])/2  # Assume simple mean on link scale
  Coef.se.pAspen.agp.all[sp]<-(Coef.se.pAspen.agp[1,sp]+Coef.se.pAspen.agp[2,sp])/2  # Assume simple mean on link scale

  # 5.2. Figure for overall coefficients
  # Do the next three lines here to use count.all in figure
  d1$count.all<-ifelse(!is.na(d1$count.summer) & !is.na(d1$count.winter),(d1$count.summer+d1$count.winter)/2, ifelse(is.na(d1$count.summer),0,d1$count.summer)+ifelse(is.na(d1$count.winter),0,d1$count.winter))  # Use unweighted average if both available, because predictions are for equal effort (100 days) per season.  Otherwise, use just whichever season is available
  d1$p.pa.all<-ifelse(!is.na(d1$count.summer) & !is.na(d1$count.winter),(d1$p.pa.summer+d1$p.pa.winter)/2, ifelse(is.na(d1$count.summer),0,d1$p.pa.summer)+ifelse(is.na(d1$count.winter),0,d1$p.pa.winter))  # Use (average) prediction(s) for whichever season(s) have/has available count
  d1$p.all<-ifelse(!is.na(d1$count.summer) & !is.na(d1$count.winter),(d1$p.summer+d1$p.winter)/2, ifelse(is.na(d1$count.summer),0,d1$p.summer)+ifelse(is.na(d1$count.winter),0,d1$p.winter))  # Use (average) prediction(s) for whichever season(s) have/has available count
  x<-col1<-y<-y.lci<-y.uci<-y1<-y1.lci<-y1.uci<-w<-class<-space1<-NULL
  for (i in 1:length(vnames.agp)) {
    j<-match(vnames.agp[i],fp$Class)
    x<-c(x,fp$x[j])
    veg.to.use<-as.character(pm$VegType[pm[,vnames.agp[i]]==1])[1]  # To use Coef.mean, find the first fine veg+HF types that is included in the (potentially broader) variable being plotted
    y<-c(y,Coef.mean.all[sp,veg.to.use])
    y.lci<-c(y.lci,Coef.lci.all[sp,veg.to.use])
    y.uci<-c(y.uci,Coef.uci.all[sp,veg.to.use])
    y1<-c(y1,plogis(qlogis(Coef.pa.all[sp,veg.to.use])+Coef.pAspen.pa.all[sp])*exp(log(Coef.mean.all[sp,veg.to.use]/Coef.pa.all[sp,veg.to.use])+Coef.pAspen.agp.all[sp]))  # Add effect of aspen, on appropriate link scales, for treed figure.  This part gives Ceof.agp.mean
    col1<-c(col1,fp$col1[j])
    w<-c(w,fp$width[j])
    class<-c(class,vnames.agp[i])
    space1<-c(space1,fp$spaceafter[j])
  }
  y1.lci<-y.lci*y1/y  # This assumes no error in pAspen coefficient (because we don't have the covariances)
  y1.uci<-y.uci*y1/y  # This assumes no error in pAspen coefficient (because we don't have the covariances)
  ord<-order(x)  # Sort all by x
  y<-y[ord]
  y.lci<-y.lci[ord]
  y.uci<-y.uci[ord]
  y1<-y1[ord]
  y1.lci<-y1.lci[ord]
  y1.uci<-y1.uci[ord]
  col1<-col1[ord]
  w<-w[ord]
  class<-class[ord]
  space1<-space1[ord]
  x<-x[ord]
  # Rectify spaces between x's
  for (i in 1:(length(x)-1)) {
    for (j in (i+1):length(x)) x[j]<-x[j]+space1[i]-(x[i+1]-x[i])  # Alter all subsequent positions accordingly
  }
  # Make bar plot
  ymax<-min(max(c(y.uci,y1.uci),na.rm=TRUE),2*max(c(y,y1),na.rm=TRUE))  # This keeps the figures readable when there are extreme UCI's
  space<-c(1,x[-1]-x[-length(x)])-0.99  # The spacing between bars
  density<-ifelse(substr(class,1,2)=="CC",50,NA)
  fname<-paste(fname.fig,"Non-treed/Soil+HF figure best model ",SpTable[sp],".png",sep="")
  png(file=fname,width=ifelse(length(y)>7,1500,1000),height=700)
  par(mai=c(1.9,1,0.2,0.3))
  x1<-barplot(y,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F)[,1]  # To get strips on CC bars - probably not needed here for South, but left anyway
  abline(h=pretty(c(0,ymax)),col="grey80")
  x1<-barplot(y,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]  # To get strips on CC bars, and to put bars in front of horizontal axis lines
  x1<-barplot(y,space=space,width=w,border="white",density=density,col=col1,ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]
  axis(side=2,tck=0.02,cex.axis=0.9,col.axis="grey50",col.ticks="grey50",las=2,at=pretty(c(0,ymax)))
  box(bty="l",col="grey50")
  for (i in 1:length(x1)) {
    lines(rep(x1[i],2),c(y[i],y.uci[i]),col=col1[i])
    lines(rep(x1[i],2),c(y[i],y.lci[i]),col="grey90")
  }
  mtext(side=1,at=x1,line=1,adj=0.5,class,col=col1,cex=1.2)
  mtext(side=3,at=x1[1],adj=0,paste(sp.names[sp],"- South Non-treed"),col="grey30",cex=1.2)
  text(max(x1),ymax*0.98,paste("Detected at",sum(sign(d1$count.all)),"of",nrow(d1),"camera locations"),cex=1.1,adj=1,col="grey40") # Add sample size
  graphics.off()
  # And treed version
  ymax<-min(max(c(y.uci,y1.uci),na.rm=TRUE),2*max(c(y,y1),na.rm=TRUE))  # This keeps the figures readable when there are extreme UCI's
  space<-c(1,x[-1]-x[-length(x)])-0.99  # The spacing between bars
  density<-ifelse(substr(class,1,2)=="CC",50,NA)
  fname<-paste(fname.fig,"Treed/Soil+HF figure best model ",SpTable[sp],".png",sep="")
  png(file=fname,width=ifelse(length(y)>7,1500,1000),height=700)
  par(mai=c(1.9,1,0.2,0.3))
  x1<-barplot(y1,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F)[,1]  # To get strips on CC bars - probably not needed here for South, but left anyway
  abline(h=pretty(c(0,ymax)),col="grey80")
  x1<-barplot(y1,space=space,width=w,border="white",col="grey30",ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]  # To get strips on CC bars, and to put bars in front of horizontal axis lines
  x1<-barplot(y1,space=space,width=w,border="white",density=density,col=col1,ylim=c(0,ymax),yaxt="n",ylab="Relative abundance",col.lab="grey50",cex.lab=1.2,axisnames=F,add=TRUE)[,1]
  axis(side=2,tck=0.02,cex.axis=0.9,col.axis="grey50",col.ticks="grey50",las=2,at=pretty(c(0,ymax)))
  box(bty="l",col="grey50")
  for (i in 1:length(x1)) {
    lines(rep(x1[i],2),c(y1[i],y1.uci[i]),col=col1[i])
    lines(rep(x1[i],2),c(y1[i],y1.lci[i]),col="grey90")
  }
  mtext(side=1,at=x1,line=1,adj=0.5,class,col=col1,cex=1.2)
  mtext(side=3,at=x1[1],adj=0,paste(sp.names[sp],"- South Treed"),col="grey30",cex=1.2)
  text(max(x1),ymax*0.98,paste("Detected at",sum(sign(d1$count.all)),"of",nrow(d1),"camera locations"),cex=1.1,adj=1,col="grey40") # Add sample size
  graphics.off()

  # 6. Residual variation due to location and climate
  # These models are fit to the residual variation after the average Winter and winter predictions (or whichever one(s) are available).
  # Average Winter and winter counts and predictions, and add explanatory variables from d to d1.  Check first that DeploymentYears in d1 and d are still in same order
  dplot(1:nrow(d),match(d$location_project,d1$location_project),cex=0.3)  # Needs to be a straight 1:1 line
  d1<-cbind(d1,d[,c("Lat","TrueLat","Long","PET","AHM","MAT","FFP","MAP","MWMT","MCMT")])
  d1$wt<-(d$wt.w+d$wt.s)/2
  if (sc.option[sp]==2 | sc.option[sp]==1) { # Presence/absence model only.  It is run for option 1 here solely to do fit AUC; the total abundance models replace these in the next section for option 1.
    # Climate and spatial variable sets are tried
    UseForLure<-grepl("^[[:digit:]]+",d1$location)  # Only use ongrid sites for lure calibration (paired lure/not).  These are now identified by locations starting with digits
    dtemp<-d1[UseForLure==TRUE,]  # To calculate lure effect only with ABMI paired'ish sites
    lure1<-mean(sign(dtemp$count.all[dtemp$Lured=="Yes"]))/mean(sign(dtemp$count.all[dtemp$Lured=="No"]))  # Lure effect on presence/absence
    pCount1<-sign(d1$count.all)/ifelse(d1$Lured=="Yes",lure1,1)
    pCount1<-pCount1/max(pCount1)  # In case lure effect is <1
    m.sc.pa<-list(NULL)
    wt1<-d1$wt  # Need to do this to use model.matrix below for plotting
    m.sc.pa[[1]]<-try(glm(pCount1~offset(qlogis(0.998*d1$p.pa.all+0.001))-1,data=d1,family="binomial",weights=wt1))
    m.sc.pa[[2]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long))  # Note that "Lat" here is the truncated latitude, where southern points are treated as being further south.  ("TrueLat" is the actual latitude of the site)
    m.sc.pa[[3]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)))
    m.sc.pa[[4]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)+I(Lat^3)))
    m.sc.pa[[5]]<-try(update(m.sc.pa[[1]],.~.+PET))  # Was EREF, but not available in current climate variable summary, so all EREF changed to PET
    m.sc.pa[[6]]<-try(update(m.sc.pa[[1]],.~.+AHM))
    m.sc.pa[[7]]<-try(update(m.sc.pa[[1]],.~.+MAT))
    m.sc.pa[[8]]<-try(update(m.sc.pa[[1]],.~.+FFP))
    m.sc.pa[[9]]<-try(update(m.sc.pa[[1]],.~.+MAP+FFP))
    m.sc.pa[[10]]<-try(update(m.sc.pa[[1]],.~.+MAP+FFP+MAP:FFP))
    m.sc.pa[[11]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP+PET+AHM))
    m.sc.pa[[12]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP+PET+AHM+PET:MAP+MAT:AHM))
    m.sc.pa[[13]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP))
    m.sc.pa[[14]]<-try(update(m.sc.pa[[1]],.~.+MWMT+MCMT))
    m.sc.pa[[15]]<-try(update(m.sc.pa[[1]],.~.+AHM+PET))
    m.sc.pa[[16]]<-try(update(m.sc.pa[[1]],.~.+MAT+I(MAT*(MAT+10)) ))  #
    m.sc.pa[[17]]<-try(update(m.sc.pa[[1]],.~.+MWMT+MCMT+FFP+MAT))
    m.sc.pa[[18]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)+I(Lat^2*Long^2)))
    m.sc.pa[[19]]<-try(update(m.sc.pa[[1]],.~.+MAT+I(MAT*(MAT+10))+I(Long*MAT) ))
    # Models with spatial and climate variables together not currently used, because highly correlated
    nModels.sc.pa<-length(m.sc.pa)
    # BIC calculation to select best covariate set Uses BIC for more conservative variable set
    bic.sc.pa<-rep(999999999,nModels.sc.pa)
    for (i in 1:(nModels.sc.pa)) {
      if (!is.null(m.sc.pa[[i]]) & class(m.sc.pa[[i]])[1]!="try-error") {
        bic.sc.pa[i]<-BIC(m.sc.pa[[i]])
      }
    }
    best.model.sc.pa<-which.min(bic.sc.pa)
  }

  # Do AUC of fit here, before the total abundance option is run for option 1
  if (sc.option[sp]==1 | sc.option[sp]==2) p<-plogis(predict(m.sc.pa[[best.model.sc.pa]]))
  if (sc.option[sp]==3) p<-plogis(d1$p.pa.all)  # The original veg+HF only prediction if there is no sc model (this prediction is on the ordinal scale, despite the "t." in the name...)
  auc.fit[sp]<-auc(roc(sign(d1$count.all),p))  # No correction for lure here.

  if (sc.option[sp]==1) { # Model full total abundance
    # Climate and spatial variables sets are tried
    dtemp<-d1[substr(d1$DeploymentYear,1,4)=="ABMI" & substr(d1$DeploymentYear,1,6)!="ABMI-W",]  # To calculate lure effect only with ABMI (notABMI-W) sites
    lure1<-mean(dtemp$count.all[dtemp$Lured=="Yes"])/mean(dtemp$count.all[dtemp$Lured=="No"])  # Lure effect on total abundance
    pCount1<-d1$count.all/ifelse(d1$Lured=="Yes",lure1,1)
    log.offset<-min(pCount1[pCount1>0])/2
    #		if (SpTable[sp]=="WhitetailedDeer") log.offset<-0.5  # Reduce the effect of the relatively few 0's
    pCount1<-log(pCount1+log.offset)  # Using log(x+offset)
    log.adj<-mean(log(d1$p.all+log.offset)-pCount1)  # Compensate for geometric mean issue
    pCount1<-pCount1+log.adj
    m.sc.pa<-list(NULL)
    wt1<-d1$wt  # Need to do this to use model.matrix below for plotting
    m.sc.pa[[1]]<-try(glm(pCount1~offset(log(d1$p.all+log.offset))-1,data=d1,family=gaussian,weights=wt1))
    m.sc.pa[[2]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long))  # Note that "Lat" here is the truncated latitude, where southern points are treated as being further south.  ("TrueLat" is the actual latitude of the site)
    m.sc.pa[[3]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)))
    m.sc.pa[[4]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)+I(Lat^3)))
    m.sc.pa[[5]]<-try(update(m.sc.pa[[1]],.~.+PET))
    m.sc.pa[[6]]<-try(update(m.sc.pa[[1]],.~.+AHM))
    m.sc.pa[[7]]<-try(update(m.sc.pa[[1]],.~.+MAT))
    m.sc.pa[[8]]<-try(update(m.sc.pa[[1]],.~.+FFP))
    m.sc.pa[[9]]<-try(update(m.sc.pa[[1]],.~.+MAP+FFP))
    m.sc.pa[[10]]<-try(update(m.sc.pa[[1]],.~.+MAP+FFP+MAP:FFP))
    m.sc.pa[[11]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP+PET+AHM))
    m.sc.pa[[12]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP+PET+AHM+PET:MAP+MAT:AHM))
    m.sc.pa[[13]]<-try(update(m.sc.pa[[1]],.~.+MAT+MAP))
    m.sc.pa[[14]]<-try(update(m.sc.pa[[1]],.~.+MWMT+MCMT))
    m.sc.pa[[15]]<-try(update(m.sc.pa[[1]],.~.+AHM+PET))
    m.sc.pa[[16]]<-try(update(m.sc.pa[[1]],.~.+MAT+I(MAT*(MAT+10)) ))  #
    m.sc.pa[[17]]<-try(update(m.sc.pa[[1]],.~.+MWMT+MCMT+FFP+MAT))
    m.sc.pa[[18]]<-try(update(m.sc.pa[[1]],.~.+Lat+Long+Lat:Long+I(Lat^2)+I(Long^2)+I(Lat^2*Long^2)))
    m.sc.pa[[19]]<-try(update(m.sc.pa[[1]],.~.+MAT+I(MAT*(MAT+10))+I(Long*MAT) ))  # Version including Long did not work as well
    #		for (i in 1:19) m.sc.pa[[i+19]]<-update(m.sc.pa[[i]],.~.+NSR1)
    # Models with spatial and climate variables together not currently used, because highly correlated
    nModels.sc<-length(m.sc.pa)
    # BIC calculation to select best covariate set Uses BIC for more conservative variable set
    bic.sc<-rep(999999999,nModels.sc)
    for (i in 1:(nModels.sc)) {
      if (!is.null(m.sc.pa[[i]]) & class(m.sc.pa[[i]])[1]!="try-error") {
        bic.sc[i]<-BIC(m.sc.pa[[i]])
      }
    }
    best.model.sc.pa<-which.min(bic.sc)
  }
  # No models if option=3

  # Change models if necessary when a non-best model is more accurate than the best model - CHECK WITH NEW DATA
  if (SpTable[sp]=="Redfox") best.model.sc.pa<-2  # Only model that doesn't produce extreme values in very southernmost Rockies foothills (winsorizing doesn't help, because current is higher in agriculture)
  if (SpTable[sp]=="Badger") best.model.sc.pa<-6  # Best model = NULL misses tapering off in parkland
  c1<-coef(m.sc.pa[[best.model.sc.pa]])  # Variable names in best sc model

  # And post-hoc modifications of coefficients when necessary - CHECK WITH NEW DATA
  if (SpTable[sp]=="WhitetailedJackRabbit" | SpTable[sp]=="Badger") c1<-c(c1,"PeaceRiver"= -16)  # Censor out Peace River area for these species
  if (SpTable[sp]=="StripedSkunk") c1<-c(c1,"PeaceRiver"= -2)  # Reduce Peace River area for this species

  # Save coefficients for the subset of climate and/or spatial variables
  if (sc.option[sp]==1 | sc.option[sp]==2) {
    vnames<-names(c1)
    vnames1<-ifelse(vnames=="(Intercept)","Intercept",vnames)  # This is for the names used in km2.res (where "(", "^", etc. can't be used)
    vnames1<-ifelse(vnames1=="I(Lat^2)","Lat2",vnames1)
    vnames1<-ifelse(vnames1=="I(Lat^3)","Lat3",vnames1)
    vnames1<-ifelse(vnames1=="I(Long^2)","Long2",vnames1)
    vnames1<-ifelse(vnames1=="I(MAT * (MAT + 10))","MAT2",vnames1)
    vnames1<-ifelse(vnames1=="I(MWMT^2)","MWMT2",vnames1)
    vnames1<-ifelse(vnames1=="I(Lat^2 * Long^2)","Lat2Long2",vnames1)
    vnames1<-ifelse(vnames1=="I(Long * MAT)","LongMAT",vnames1)
    vnames1<-gsub(":","",vnames1)
    Res.coef[sp,match(vnames1,colnames(Res.coef))]<-c1
    if (length(c1)==0) Res.coef[sp,]<-0  # For case when models were fit, but best one was null
  }
  # If option=3, the res coefs are already 0

  # 6.3 Mapping of residual climate/spatial effect
  # This is just the additional climate and spatial effect, not the basic veg type effects
  # Done in the original way, since this is just for us
  if (sc.option[sp]==1 | sc.option[sp]==2) {
    vnames<-names(c1)  # Figure out the names of the included variables in the km2 raster data frame
    vnames<-ifelse(vnames=="(Intercept)","Intercept",vnames)
    vnames<-ifelse(vnames=="I(Lat^2)","Lat2",vnames)
    vnames<-ifelse(vnames=="I(Lat^3)","Lat3",vnames)
    vnames<-ifelse(vnames=="I(Long^2)","Long2",vnames)
    vnames<-ifelse(vnames=="I(MAT * (MAT + 10))","MAT2",vnames)
    vnames<-ifelse(vnames=="I(MWMT^2)","MWMT2",vnames)
    vnames<-ifelse(vnames=="I(Lat^2 * Long^2)","Lat2Long2",vnames)
    vnames<-ifelse(vnames=="I(Long * MAT)","LongMAT",vnames)
    vnames<-gsub(":","",vnames)
    km2.sc1<-km2.sc[,vnames]
    if (sc.option[sp]==1) km2.p1<-exp(rowSums( t(c1*t(km2.sc1))))   # Predictions from just the climate and spatial part of the residual model for each km2 raster - log-link total abundance
    if (sc.option[sp]==2) km2.p1<-plogis(rowSums( t(c1*t(km2.sc1))))   # Predictions from just the climate and spatial part of the residual model for each km2 raster - logit-link presence/absence
    km2.p1<-ifelse(km2.p1>quantile(km2.p1,0.99),quantile(km2.p1,0.99),km2.p1)
    km2.p1<-km2.p1/max(km2.p1)
    if (max(km2.p1)==min(km2.p1)) {
      km2.p1<-rep(0.5,length(km2.p1))  # make all white map if null model is best
    } else {
      km2.p1<-(km2.p1-min(km2.p1))/(max(km2.p1)-min(km2.p1))
    }
    r<-ifelse(km2.p1<0.5,1,(1-km2.p1)*2)[!is.na(km2.p1)]  # RGB for map (white at no change, more green for more positive residual effect, more red for more negative
    g<-ifelse(km2.p1>0.5,1,km2.p1*2)[!is.na(km2.p1)]  # RGB for map
    b<-(1-abs(km2.p1-0.5)*2)[!is.na(km2.p1)]  # RGB for map
    fname<-paste(fname.map,"Climate and spatial/",SpTable[sp],".jpg",sep="")
    jpeg(filename=fname,width=5,height=5.7,units="in",res=300)
    dplot(km2.sc$Long[!is.na(km2.p1)],km2.sc$TrueLat[!is.na(km2.p1)],pch=15,cex=0.4,col=rgb(r,g,b),xlab="",ylab="")
    points(km2.water$Long,km2.water$Lat,pch=15,cex=0.3,col=rgb(0.5,0.4,0.9))
    points(d1$Long,d1$TrueLat,cex=1.5*sqrt(d1$count.all)+0.2,col="yellow",lwd=2)  # Add data points, size proportional to count
    title(paste("Climate+spatial",sp.names[sp]))
    graphics.off()
  }

  # 6.4 Full map for South
  # This includes veg types, pAspen, and additional climate and spatial effects
  km2.pveg<-colSums(Coef.mean.all[sp,]*t(km2.1[,colnames(Coef.mean.all)]))   # Prediction based on veg types only.  Note: water, barren and mines not included, so they are treated as 0.  km2.1 is the truncated version of km2
  km2.pres<-colSums(Res.coef[sp,]*t(km2.sc[,colnames(Res.coef)]))  # Prediction of residual effect (note: Uses truncated latitude "Lat", but point is plotted at true latitude)
  # Need to separate out pa and agp components to apply pAspen effects
  km2.pveg.pa<-colSums(Coef.pa.all[sp,]*t(km2.1[,colnames(Coef.pa.all)]))   # Presence/absence prediction based on veg types only.  Note: water, barren and mines not included, so they are treated as 0.  km2.1 is the truncated version of km2
  km2.pveg.agp<-ifelse(km2.pveg.pa<0.0001,0,km2.pveg/km2.pveg.pa)  # This is the abundance-given-presence prediction for each km2 raster, to be multiplied by the sc-adjusted presence/absence
  km2.pveg.pa<-plogis(qlogis(km2.pveg.pa)+Coef.pAspen.pa.all[sp]*km2.1$pAspen)  # Add pAspen effect pa
  km2.pveg.agp<-exp(log(km2.pveg.agp)+Coef.pAspen.agp.all[sp]*km2.1$pAspen)  # And pAspen effect agp
  km2.pveg<-km2.pveg.pa*km2.pveg.agp
  # And ref
  km2.pveg.ref<-colSums(Coef.mean.all[sp,vnames.b]*t(km2.b.1[,vnames.b]))   # Prediction based on non-HF veg types only for reference.  km2.b.1 is the truncated version of km2.b
  km2.pres.ref<-colSums(Res.coef[sp,]*t(km2.sc[,colnames(Res.coef)]))  # Prediction of residual effect (note: Uses truncated latitude "Lat", but point is plotted at true latitude)
  # Need to separate out pa and agp components to apply pAspen effects
  km2.pveg.pa.ref<-colSums(Coef.pa.all[sp,vnames.b]*t(km2.b.1[,vnames.b]))   # Presence/absence prediction based on veg types only.  Note: water, barren and mines not included, so they are treated as 0.  km2.1 is the truncated version of km2
  km2.pveg.agp.ref<-ifelse(km2.pveg.pa.ref<0.0001,0,km2.pveg.ref/km2.pveg.pa.ref)  # This is the abundance-given-presence prediction for each km2 raster, to be multiplied by the sc-adjusted presence/absence
  km2.pveg.pa.ref<-plogis(qlogis(km2.pveg.pa.ref)+Coef.pAspen.pa.all[sp]*km2.b.1$pAspen)  # Add pAspen effect pa
  km2.pveg.agp.ref<-exp(log(km2.pveg.agp.ref)+Coef.pAspen.agp.all[sp]*km2.b.1$pAspen)  # And pAspen effect agp
  km2.pveg.ref<-km2.pveg.pa.ref*km2.pveg.agp.ref
  if (sc.option[sp]==1 | sc.option[sp]==3) {  # Use this also for no model - all 0 coefficients become 1 multipliers on exp scale
    km2.p<-km2.pveg*exp(km2.pres) # Using simple multiplication of residual effect, to avoid offset problems
    km2.p.ref<-km2.pveg.ref*exp(km2.pres.ref)  # Using simple multiplication of residual effect, to avoid offset problems - here, for log-linked residual total abundance predictions
  }
  if (sc.option[sp]==2) {  # Logit scale, and need to extract veg presence/absence and AGP components
    km2.p<-plogis(qlogis(0.998*km2.pveg.pa+0.001)+km2.pres) * km2.pveg.agp  # Here, for logit-linked residual presence/absence predictions.  And multiply by agp to get total abundance.
    km2.p<-ifelse(is.na(km2.p),0,km2.p)  # This is if the prediction is 0
    # And repeat for reference
    km2.p.ref<-plogis(qlogis(0.998*km2.pveg.pa.ref+0.001)+km2.pres.ref) * km2.pveg.agp.ref  # Using simple multiplication of residual effect, to avoid offset problems - here, for logit-linked residual presence/absence predictions. And multiply by agp to get total abundance.
    km2.p.ref<-ifelse(is.na(km2.p.ref),0,km2.p.ref)  # This is if the prediction is 0
  }
  x.ref1<-km2.p.ref  # Colour gradient direct with predicted abundance
  x.curr1<-km2.p
  #	x.curr1<-ifelse(x.curr1<min(pCount),min(pCount),x.curr1)  # Some extreme low values otherwise
  #	x.ref1<-ifelse(x.ref1<min(pCount),min(pCount),x.ref1)
  x.ref.trunc<-ifelse(x.ref1>quantile(c(x.ref1,x.curr1),0.99,na.rm=T),quantile(c(x.ref1,x.curr1),0.99,na.rm=T),x.ref1)  # Clip to 99 percentile, to prevent colour scaling problems with a few high values
  x.curr.trunc<-ifelse(x.curr1>quantile(c(x.ref1,x.curr1),0.99,na.rm=T),quantile(c(x.ref1,x.curr1),0.99,na.rm=T),x.curr1)  # Clip to 99 percentile, to prevent colour scaling problems with a few high values
  x.curr<-x.curr.trunc/max(c(x.ref.trunc,x.curr.trunc),na.rm=T)
  x.ref<-x.ref.trunc/max(c(x.ref.trunc,x.curr.trunc),na.rm=T)
  # 6.4.1 Current
  c3<-c2(1000)[1+999*x.curr]
  fname<-paste(fname.map,"Current/",SpTable[sp],".jpg",sep="")
  jpeg(file=fname,width=600,height=1000)
  plot(km2.sc$proj.x,km2.sc$proj.y,pch=15,cex=0.2,col=c3,xaxt="n",yaxt="n",xlab="",ylab="",bty="n",xlim=range(c(km2.sc$proj.x,m.water$x)),ylim=range(c(km2.sc$proj.y,m.water$y)))
  points(m.water$x,m.water$y,pch=15,cex=0.2,col=rgb(0.4,0.3,0.8))
  #points(km2.sc$proj.x[km2$NatRegion=="Rocky Mountain"],km2.sc$proj.y[km2$NatRegion=="Rocky Mountain"],pch=15,cex=0.2,col="lightcyan4")
  #text(-0.025,-0.745,"Insufficient \n   data",col="white",cex=0.9)
  mtext(side=3,at=m.title$x,paste(sp.names[sp],"Current"),adj=0.5,cex=1.4,col="grey40")
  mtext(side=3,at=m.title$x,line=-1,paste("Detected at",sum(sign(d1$count.all)),"of",nrow(d),"camera locations"),adj=0.5,cex=1.2,col="grey40")
  points(m.city.x,m.city.y,pch=18,col="grey10")
  text(m.city.x,m.city.y,city,cex=0.8,adj=-0.1,col="grey10")
  graphics.off()
  # 6.4.2 Reference
  c3<-c2(1000)[1+999*x.ref]
  fname<-paste(fname.map,"Reference/",SpTable[sp],".jpg",sep="")
  jpeg(file=fname,width=600,height=1000)
  plot(km2.sc$proj.x,km2.sc$proj.y,pch=15,cex=0.2,col=c3,xaxt="n",yaxt="n",xlab="",ylab="",bty="n",xlim=range(c(km2.sc$proj.x,m.water$x)),ylim=range(c(km2.sc$proj.y,m.water$y)))
  points(m.water$x,m.water$y,pch=15,cex=0.2,col=rgb(0.4,0.3,0.8))
  #points(km2$proj.x[km2$NatRegion=="Rocky Mountain"],km2$proj.y[km2$NatRegion=="Rocky Mountain"],pch=15,cex=0.2,col="lightcyan4")
  #text(-0.025,-0.745,"Insufficient \n   data",col="white",cex=0.9)
  mtext(side=3,at=m.title$x,paste(sp.names[sp],"Reference"),adj=0.5,cex=1.4,col="grey40")
  mtext(side=3,at=m.title$x,line=-1,paste("Detected at",sum(sign(d1$count.all)),"of",nrow(d),"camera locations"),adj=0.5,cex=1.2,col="grey40")
  points(m.city.x,m.city.y,pch=18,col="grey10")
  text(m.city.x,m.city.y,city,cex=0.8,adj=-0.1,col="grey10")
  graphics.off()
  # 6.4.3 Difference
  trunc<-quantile(c(km2.p,km2.p.ref),0.99,na.rm=T)
  diff<-(ifelse(km2.p>trunc,trunc,km2.p)-ifelse(km2.p.ref>trunc,trunc,km2.p.ref))/trunc
  diff<-sign(diff)*abs(diff)^0.5
  d3<-d2(1000)[500+499*diff]
  fname<-paste(fname.map,"Difference/",SpTable[sp],".jpg",sep="")
  jpeg(file=fname,width=600,height=1000)
  plot(km2.sc$proj.x,km2.sc$proj.y,pch=15,cex=0.2,col=d3,xaxt="n",yaxt="n",xlab="",ylab="",bty="n",xlim=range(c(km2.sc$proj.x,m.water$x)),ylim=range(c(km2.sc$proj.y,m.water$y)))
  points(m.water$x,m.water$y,pch=15,cex=0.2,col=rgb(0.4,0.3,0.8))
  #points(km2$proj.x[km2$NatRegion=="Rocky Mountain"],km2$proj.y[km2$NatRegion=="Rocky Mountain"],pch=15,cex=0.2,col="lightcyan4")
  #text(-0.025,-0.745,"Insufficient \n   data",col="white",cex=0.9)
  mtext(side=3,at=m.title$x,paste(sp.names[sp],"Difference"),adj=0.5,cex=1.4,col="grey40")
  mtext(side=3,at=m.title$x,line=-1,paste("Detected at",sum(sign(d1$count.all)),"of",nrow(d),"camera locations"),adj=0.5,cex=1.2,col="grey40")
  points(m.city.x,m.city.y,pch=18,col="grey10")
  text(m.city.x,m.city.y,city,cex=0.8,adj=-0.1,col="grey10")
  graphics.off()

  # 7. Output by species
  # 7.1 km2 raster reference and current abundance - not run, to simplify things
  q<-data.frame(LinkID=km2.1$LinkID,Ref=km2.p.ref,Curr=km2.p)  # km2.1 is the truncated version of km2
  fname<-paste(fname.km2summaries," ",SpTable[sp],".csv",sep="")
  write.table(q,file=fname,sep=",",row.names=FALSE)

  # 7.2 Save AIC wts for each species - models themselves not being saved in R format, because haven't been using
  fname<-paste(fname.Robjects," ",SpTable[sp],".Rdata",sep="")
  save(file=fname,aic.wt.pa.save,aic.wt.agp.save,bic.sc.pa)
}  # Next species

# 8. Export .csv files for website or other uses
# Veg and HF coefficients
lu.names<-read.csv("C:/Dave/ABMI/Cameras/Coefficients/2020/Analysis south/Lookup for coefficient table names South June 2020.csv")  # To translate names used for coefficients here to official names
Coef.mean.all<-cbind(Coef.mean.all,rep(0,nrow(Coef.mean.all)),rep(0,nrow(Coef.mean.all)))  # Add columns for bare and water
Coef.lci.all<-cbind(Coef.lci.all,rep(0,nrow(Coef.lci.all)),rep(0,nrow(Coef.lci.all)))  # Add columns for bare and water
Coef.uci.all<-cbind(Coef.uci.all,rep(0,nrow(Coef.uci.all)),rep(0,nrow(Coef.uci.all)))  # Add columns for bare and water
Coef.pa.all<-cbind(Coef.pa.all,rep(0,nrow(Coef.pa.all)),rep(0,nrow(Coef.pa.all)))  # Add columns for bare and water
colnames(Coef.mean.all)[(ncol(Coef.mean.all)-1):ncol(Coef.mean.all)]<-c("Bare","Water")  # Currently not modeled so assumed to be 0
colnames(Coef.lci.all)[(ncol(Coef.lci.all)-1):ncol(Coef.lci.all)]<-c("Bare","Water")  # Currently not modeled so assumed to be 0
colnames(Coef.uci.all)[(ncol(Coef.uci.all)-1):ncol(Coef.uci.all)]<-c("Bare","Water")  # Currently not modeled so assumed to be 0
colnames(Coef.pa.all)[(ncol(Coef.pa.all)-1):ncol(Coef.pa.all)]<-c("Bare","Water")  # Currently not modeled so assumed to be 0
#i<-match(lu.names$CoefName,colnames(Coef.mean.all))  # Check for NA's
i<-1:ncol(Coef.mean.all)  # Assume official names being used here
Coef.official<-Coef.mean.all[,i]
#i<-match(lu.names$CoefName,colnames(Coef.lci.all))  # Check for NA's
i<-1:ncol(Coef.lci.all)  # Assume official names being used here
Coef.official.lci<-Coef.lci.all[,i]
#i<-match(lu.names$CoefName,colnames(Coef.uci.all))  # Check for NA's
i<-1:ncol(Coef.uci.all)  # Assume official names being used here
Coef.official.uci<-Coef.uci.all[,i]
#colnames(Coef.official)<-colnames(Coef.official.lci)<-colnames(Coef.official.uci)<-lu.names$OfficialName
rownames(Coef.official)<-rownames(Coef.official.lci)<-rownames(Coef.official.uci)<-rownames(Coef.pa.all)<-SpTable
# and climate/space coefficients
Res.coef.official<-Res.coef  # Seems to be in right format already
# Save
fname<-paste(fname.sumout,"OFFICIAL coefficients.Rdata")
save(file=fname,Coef.official,Coef.official.lci,Coef.official.uci,Res.coef.official,Coef.pa.all)  # Save to compile later with South results
# pAspen coefficient
fname<-paste(fname.sumout,"pApen coefficients.csv")
write.table(data.frame(Sp=SpTable,pAspen.pa=Coef.pAspen.pa.all,pAspen.agp=Coef.pAspen.agp.all),file=fname,sep=",",row.names=FALSE)

# AUC fit
q<-data.frame(Sp=SpTable,AUC.fit=auc.fit)
write.table(q,file="C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/AUC of fit for camera mammals South Nov 2021.csv",sep=",",row.names=F)

# Lure effects
fname<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Lure effects South Nov 2021.csv"
q<-data.frame(Season="Summer",Measure="PresAbs",t(lure.pa[1,]))
q<-rbind(q,data.frame(Season="Summer",Measure="AGP",t(lure.agp[1,])))
q<-rbind(q,data.frame(Season="Winter",Measure="PresAbs",t(lure.pa[2,])))
q<-rbind(q,data.frame(Season="Winter",Measure="AGP",t(lure.agp[2,])))
names(q)<-c("Season","Measure",SpTable)
write.table(q,file=fname,sep=",",row.names=FALSE)

# Veg+HF Model weights
fname<-"C:/Dave/ABMI/Cameras/Coefficients/2021/Analysis south/Model weights Veg+HF South Nov 2021.csv"
q<-data.frame(Season="Summer",Measure="PresAbs",Model=1:ncol(aic.wt.pa.save[1,,]),t(aic.wt.pa.save[1,,]))
q<-rbind(q,data.frame(Season="Summer",Measure="AGP",Model=1:ncol(aic.wt.agp.save[1,,]),t(aic.wt.agp.save[1,,])))
q<-rbind(q,data.frame(Season="Winter",Measure="PresAbs",Model=1:ncol(aic.wt.pa.save[2,,]),t(aic.wt.pa.save[2,,])))
q<-rbind(q,data.frame(Season="Winter",Measure="AGP",Model=1:ncol(aic.wt.agp.save[2,,]),t(aic.wt.agp.save[2,,])))
names(q)<-c("Season","Measure","Model",SpTable)
write.table(q,file=fname,sep=",",row.names=FALSE)

# NOT UPDATED - new new categories don't make sense, and don't matter to mammals anyway
# 9. Use/availability figures for all species with >3 detections (separate section, because larger species list)
# Uses Peter's terminology and lines from his script
#library(RColorBrewer)
#d1<-d  # NOT excluding any sites or areas
#x<-data.frame(Productive=d1$Productive,Clay=d1$Clay,Saline=d1$Saline,RapidDrain=d1$RapidDrain,Wetland=d1$SoilWetland,Crop=d1$Crop,TameP=d1$TameP,RoughP=d1$RoughP,RurUrbInd=d1$RurUrbInd,Well=d1$Well,HardLin=d1$HardLin,SoftLin=d1$SoftLin)  # No UrbInd sampled
#pAvail<-colMeans(x*d1$TotalDays)  # Correction here is only for sampling length.  Detection distance not included, for simplicity
#pAvail<-pAvail/sum(pAvail)  # Proportional availability of types
#col<-brewer.pal(8, "Accent")[c(1,2,3,4,5,rep(8,7))]
#op<-par(mar=c(6,4,2,2)+0.1, las=2)
#SpTable.ua<-sort(unique(gsub("Winter","",SpTable.w.ua))) # Original SpTable.w.ua and SpTable.s.ua mixed up.  Just check that this is all species
#SpTable.ua<-sort(unique(gsub("Summer","",SpTable.ua)))
#WRSI<-rWRSI<-array(NA,c(length(SpTable.ua),length(col)))  # Store results for each species
#colnames(WRSI)<-colnames(rWRSI)<-names(x)
#for (sp in 1:length(SpTable.ua)) {
#	y.w<-d[,paste(SpTable.ua[sp],"Winter",sep="")]
#	y.s<-d[,paste(SpTable.ua[sp],"Summer",sep="")]
#	y.ave<-(ifelse(is.na(y.w),0,y.w*d$WinterDays)+ifelse(is.na(y.s),0,y.s*d$SeasDays)) / (ifelse(is.na(y.s),0,d$SeasDays) + ifelse(is.na(y.w),0,d$WinterDays))
#	y.ave<-ifelse(is.na(y.ave),0,y.ave)  # Glitch in CMU data compilation in 2019 - species that didn't occur at all in that dataset are still NA here, should be 0.
#	fname<-paste(fname.fig,"Use availability/",SpTable.ua[sp],".png",sep="")
#	png(file=fname,width=480,height=480)
#		par(mar=c(6,4,2,2)+0.1, las=2)
#		pUse<-colMeans(x * sign(y.ave))
#		pUse<-pUse/sum(pUse)
#		WRSI[sp,]<-pUse/pAvail  # Simple use/availability
#		rWRSI[sp,]=(exp(2 * log(WRSI[sp,])) - 1)/(1 + exp(2 * log(WRSI[sp,])))  # Transform to -1 to 1 (from Peter)
#		x1<-barplot(rWRSI[sp,], horiz=FALSE, ylab="Affinity",space=NULL, col=col, border=col, ylim=c(-1,1), axes=FALSE)
#		axis(side=2)
#		abline(h=0, col="red4", lwd=2)
#		mtext(side=3,at=x1[1],adj=0,taxa.file$Species[match(SpTable.ua[sp],taxa.file$Label)],cex=1.2,col="grey40",las=1)
#		# Add sample size
#		text(max(x1),0.97,paste("Detected at",sum(sign(y.ave)),"of",nrow(d),"camera locations"),cex=1.2,adj=1,col="grey40")
#	graphics.off()
#}
#par(op)
# Save table for all species
#ua<-data.frame(SpLabel=SpTable.ua,Species=taxa.file$Species[match(SpTable.ua,taxa.file$Label)],WRSI,rWRSI)  # Original version
#names(ua)<-c("SpLabel","Species",paste(names(x),"WRSI"),paste(names(x),"rWRSI"))  # Original version
#UseavailSouth<-rWRSI  # Official version
#rownames(UseavailSouth)<-SpTable.ua  # Official version
#fname<-paste(fname.useavail,"UseavailSouth.Rdata",sep="")
#save(UseavailSouth,file=fname)

# 10. Information for header file saying what information is available for what species - to be compiled with north
q<-data.frame(SpeciesID=SpTable.ua,ScientificName=NA,TSNID=NA,CommonName=taxa.file$Species[match(SpTable.ua,taxa.file$Label)],
              ModelNorth=NA,ModelSouth=!is.na(match(SpTable.ua,SpTable)),Nonnative=FALSE,
              LinkHabitatNorth=NA,LinkHabitatSouth=ifelse(is.na(match(SpTable.ua,SpTable)),NA,"Logit/Log"),
              LinkSpclimNorth=NA,LinkSpclimSouth=ifelse(is.na(match(SpTable.ua,SpTable)),NA,c("Log","Logit")[sc.option[match(SpTable.ua,SpTable)]]),
              ModelNorthWinter=NA,ModelNorthSummer=NA,
              ModelSouthWinter=!is.na(match(SpTable.ua,gsub("Winter","",SpTable.w))),ModelSouthSummer=!is.na(match(SpTable.ua,gsub("Summer","",SpTable.s))),
              UseavailNorth=NA,UseavailSouth=TRUE)
fname<-paste(fname.sumout," Header table south.csv",sep="")
write.table(file=fname,q,sep=",",row.names=FALSE)

# 11. Extra section - produces initial grouping of sites for cross-validation.  May have to be revised by eye.
# Ermias version
D.coord <- d[ , c("Long", "TrueLat")]
names(D.coord) <- c("longitude", "latitude")
# require(fossil)
# geodist <- earth.dist (D.coord)  # Too slow!
geodist<-dist(data.frame(long=111*D.coord$longitude,lat=65*D.coord$latitude))
geo.gps <- hclust (geodist , method = "ward") #I have checked other algorithms and ward seems to give a better cluster
Group.geo <- cutree (geo.gps, k=24) #k is number of clusters#
plot(d$Long,d$TrueLat,pch=18,cex=2.5,col=rainbow(24,s=0.5)[Group.geo], main="Geographical distance based groupings")
text(d$Long,d$TrueLat,d$Site,cex=0.6)
ds<-data.frame(DeploymentYear=d$DeploymentYear,Group=Group.geo)
ds<-ds[duplicated(ds$DeploymentYear)==FALSE,]
write.table(file="C:/Dave/ABMI/Data/Site info/Groups for BS and subareas/Site groupings for South mammals 24 groups Nov 2021.csv",ds,sep=",",row.names=F)




