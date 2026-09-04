# ---
# title: "Data standardization"
# author: "Brandon Allen"
# created: "2024-12-10"
# inputs: ["0_data/species/raw/R Dataset SpTable for ABMI North Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData";
#          "0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData"]
# outputs: ["0_data/species/processed/bryophyte-model-data.Rdata";
#           "0_data/species/processed/lichen-model-data.Rdata";
#           "0_data/species/processed/vascular-plant-model-data.Rdata";
#           "0_data/species/processed/mite-model-data.Rdata"]
# notes: 
#   "This script standardized the species and landcover information required for modeling.
#    All files are based off of Ermias original processing scripts. Additional scripts will
#    be required to reproduce the inputs for this script"
# ---

# 1.0 Bryophytes ----
rm(list=ls())
gc()

# 1.1 Load the species data and prediction matrix for the north
load("0_data/species/raw/R Dataset SpTable for ABMI North Moss coefficients 2024_Quad.RData")
veg.data <- qd
veg.pm <- pm
veg.species.list <- SpTable

# 1.2 Load the species data and prediction matrix for the south
load("0_data/species/raw/R Dataset SpTable for ABMI South Moss coefficients 2024_Quad.RData")
soil.data <- qd
soil.pm <- pm
soil.species.list <- SpTable

rm(d, pm, qd, FirstSpCol, LastSpCol, SppToCheck, SpTable, SpTable.ua)

# 1.3 Create the climate data
climate.data <- veg.data[, 1:402]
climate.data$Easting <- climate.data$UTMX
climate.data$Northing <- climate.data$UTMY
climate.data$Easting2 <- climate.data$Easting * climate.data$Easting
climate.data$Northing2 <- climate.data$Northing * climate.data$Northing
climate.data$EastingNorthing <- climate.data$Northing * climate.data$Easting

climate.data$MAPPET <- climate.data$MAP * climate.data$PET
climate.data$MAT2 <- climate.data$MAT * climate.data$MAT
climate.data$CMDMAT <- climate.data$CMD * climate.data$MAT
climate.data$MWMT2 <- climate.data$MWMT * climate.data$MWMT

climate.data$bio9 <- climate.data$MTD
climate.data$bio15 <- climate.data$PS

# Veg
veg.data$Easting <- veg.data$UTMX
veg.data$Northing <- veg.data$UTMY
veg.data$Easting2 <- veg.data$Easting * veg.data$Easting
veg.data$Northing2 <- veg.data$Northing * veg.data$Northing
veg.data$EastingNorthing <- veg.data$Northing * veg.data$Easting

veg.data$MAPPET <- veg.data$MAP * veg.data$PET
veg.data$MAT2 <- veg.data$MAT * veg.data$MAT
veg.data$CMDMAT <- veg.data$CMD * veg.data$MAT
veg.data$MWMT2 <- veg.data$MWMT * veg.data$MWMT

veg.data$bio9 <- veg.data$MTD
veg.data$bio15 <- veg.data$PS

# Lowland 
veg.data$Lowland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                        "BlackSpruce2", "BlackSpruce3",
                                        "BlackSpruce4", "BlackSpruce5",
                                        "BlackSpruce6", "BlackSpruce7",
                                        "BlackSpruce8", "TreedFen", 
                                        "TreedSwamp", "GraminoidFen",
                                        "Marsh", "ShrubbyFen",
                                        "ShrubbySwamp", "ShrubbyBog")])
# Peatland
veg.data$Peatland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                         "BlackSpruce2", "BlackSpruce3",
                                         "BlackSpruce4", "BlackSpruce5",
                                         "BlackSpruce6", "BlackSpruce7",
                                         "BlackSpruce8", "TreedFen", 
                                         "GraminoidFen", 
                                         "ShrubbyFen","ShrubbyBog")])

# Mineral
veg.data$Mineral <- rowSums(veg.data[, c("TreedSwamp", "ShrubbySwamp", 
                                          "Marsh")])

# Upland
veg.data$Upland <- rowSums(veg.data[, c("DeciduousR", "Deciduous1", 
                                        "Deciduous2", "Deciduous3",
                                        "Deciduous4", "Deciduous5",
                                        "Deciduous6", "Deciduous7",
                                        "Deciduous8", "MixedwoodR", 
                                        "Mixedwood1", "Mixedwood2", 
                                        "Mixedwood3", "Mixedwood4", 
                                        "Mixedwood5", "Mixedwood6", 
                                        "Mixedwood7", "Mixedwood8",
                                        "PineR", "Pine1", 
                                        "Pine2", "Pine3",
                                        "Pine4", "Pine5",
                                        "Pine6", "Pine7",
                                        "Pine8", "WhiteSpruceR", 
                                        "WhiteSpruce1", "WhiteSpruce2", 
                                        "WhiteSpruce3", "WhiteSpruce4", 
                                        "WhiteSpruce5", "WhiteSpruce6", 
                                        "WhiteSpruce7", "WhiteSpruce8")])

# CCR1234
veg.data$CCR1234 <- rowSums(veg.data[, c("CCDeciduousR", "CCDeciduous1", 
                                        "CCDeciduous2", "CCDeciduous3",
                                        "CCDeciduous4", "CCMixedwoodR",
                                        "CCMixedwood1", "CCMixedwood2",
                                        "CCMixedwood3", "CCMixedwood4", 
                                        "CCPineR", "CCPine1",
                                        "CCPine2", "CCPine3",
                                        "CCPine4", "CCWhiteSpruceR",
                                        "CCWhiteSpruce1", "CCWhiteSpruce2",
                                        "CCWhiteSpruce3", "CCWhiteSpruce4")])


# Soil
soil.data$Easting <- soil.data$UTMX
soil.data$Northing <- soil.data$UTMY
soil.data$Easting2 <- soil.data$Easting * soil.data$Easting
soil.data$Northing2 <- soil.data$Northing * soil.data$Northing
soil.data$EastingNorthing <- soil.data$Northing * soil.data$Easting

soil.data$MAPPET <- soil.data$MAP * soil.data$PET
soil.data$MAT2 <- soil.data$MAT * soil.data$MAT
soil.data$CMDMAT <- soil.data$CMD * soil.data$MAT
soil.data$MWMT2 <- soil.data$MWMT * soil.data$MWMT

soil.data$bio9 <- soil.data$MTD
soil.data$bio15 <- soil.data$PS
soil.data$paspen <- soil.data$pAspen

# 1.4 Standardize row names
rownames(climate.data) <- climate.data$SiteYearQu
rownames(veg.data) <- veg.data$SiteYearQu
rownames(soil.data) <- soil.data$SiteYearQu

veg.data <- veg.data[rownames(climate.data), ]
soil.data <- soil.data[rownames(climate.data), ]

# 1.5 Add a protocol factor
climate.data$Protocol <- as.factor(ifelse(climate.data$Year < 2009, "Old", "New"))
veg.data$Protocol <- as.factor(ifelse(veg.data$Year < 2009, "Old", "New"))
soil.data$Protocol <- as.factor(ifelse(soil.data$Year < 2009, "Old", "New"))

# 1.6 Save the results
save(climate.data, veg.data, soil.data, veg.pm, soil.pm, veg.species.list, soil.species.list,
     file = "0_data/species/processed/bryophyte-model-data.Rdata")

# 2.0 Lichens ----
rm(list=ls())
gc()

# 2.1 Load the species data and prediction matrix for the north
load("0_data/species/raw/R Dataset SpTable for ABMI North Lichen coefficients 2024_Quad.RData")
veg.data <- qd
veg.pm <- pm
veg.species.list <- SpTable

# 2.2 Load the species data and prediction matrix for the south
load("0_data/species/raw/R Dataset SpTable for ABMI South Lichen coefficients 2024_Quad.RData")
soil.data <- qd
soil.pm <- pm
soil.species.list <- SpTable

rm(d, pm, qd, FirstSpCol, LastSpCol, SppToCheck, SpTable, SpTable.ua)

# 2.3 Create the climate data
climate.data <- veg.data[, 1:447]
climate.data$Easting <- climate.data$UTMX
climate.data$Northing <- climate.data$UTMY
climate.data$Easting2 <- climate.data$Easting * climate.data$Easting
climate.data$Northing2 <- climate.data$Northing * climate.data$Northing
climate.data$EastingNorthing <- climate.data$Northing * climate.data$Easting

climate.data$MAPPET <- climate.data$MAP * climate.data$PET
climate.data$MAT2 <- climate.data$MAT * climate.data$MAT
climate.data$CMDMAT <- climate.data$CMD * climate.data$MAT
climate.data$MWMT2 <- climate.data$MWMT * climate.data$MWMT

climate.data$bio9 <- climate.data$MTD
climate.data$bio15 <- climate.data$PS

# Veg
veg.data$Easting <- veg.data$UTMX
veg.data$Northing <- veg.data$UTMY
veg.data$Easting2 <- veg.data$Easting * veg.data$Easting
veg.data$Northing2 <- veg.data$Northing * veg.data$Northing
veg.data$EastingNorthing <- veg.data$Northing * veg.data$Easting

veg.data$MAPPET <- veg.data$MAP * veg.data$PET
veg.data$MAT2 <- veg.data$MAT * veg.data$MAT
veg.data$CMDMAT <- veg.data$CMD * veg.data$MAT
veg.data$MWMT2 <- veg.data$MWMT * veg.data$MWMT

veg.data$bio9 <- veg.data$MTD
veg.data$bio15 <- veg.data$PS

# Lowland 
veg.data$Lowland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                         "BlackSpruce2", "BlackSpruce3",
                                         "BlackSpruce4", "BlackSpruce5",
                                         "BlackSpruce6", "BlackSpruce7",
                                         "BlackSpruce8", "TreedFen", 
                                         "TreedSwamp", "GraminoidFen",
                                         "Marsh", "ShrubbyFen",
                                         "ShrubbySwamp", "ShrubbyBog")])
# Peatland
veg.data$Peatland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                          "BlackSpruce2", "BlackSpruce3",
                                          "BlackSpruce4", "BlackSpruce5",
                                          "BlackSpruce6", "BlackSpruce7",
                                          "BlackSpruce8", "TreedFen", 
                                          "GraminoidFen", 
                                          "ShrubbyFen","ShrubbyBog")])

# Mineral
veg.data$Mineral <- rowSums(veg.data[, c("TreedSwamp", "ShrubbySwamp", 
                                         "Marsh")])

# Upland
veg.data$Upland <- rowSums(veg.data[, c("DeciduousR", "Deciduous1", 
                                        "Deciduous2", "Deciduous3",
                                        "Deciduous4", "Deciduous5",
                                        "Deciduous6", "Deciduous7",
                                        "Deciduous8", "MixedwoodR", 
                                        "Mixedwood1", "Mixedwood2", 
                                        "Mixedwood3", "Mixedwood4", 
                                        "Mixedwood5", "Mixedwood6", 
                                        "Mixedwood7", "Mixedwood8",
                                        "PineR", "Pine1", 
                                        "Pine2", "Pine3",
                                        "Pine4", "Pine5",
                                        "Pine6", "Pine7",
                                        "Pine8", "WhiteSpruceR", 
                                        "WhiteSpruce1", "WhiteSpruce2", 
                                        "WhiteSpruce3", "WhiteSpruce4", 
                                        "WhiteSpruce5", "WhiteSpruce6", 
                                        "WhiteSpruce7", "WhiteSpruce8")])

# CCR1234
veg.data$CCR1234 <- rowSums(veg.data[, c("CCDeciduousR", "CCDeciduous1", 
                                        "CCDeciduous2", "CCDeciduous3",
                                        "CCDeciduous4", "CCMixedwoodR",
                                        "CCMixedwood1", "CCMixedwood2",
                                        "CCMixedwood3", "CCMixedwood4", 
                                        "CCPineR", "CCPine1",
                                        "CCPine2", "CCPine3",
                                        "CCPine4", "CCWhiteSpruceR",
                                        "CCWhiteSpruce1", "CCWhiteSpruce2",
                                        "CCWhiteSpruce3", "CCWhiteSpruce4")])

# Soil
soil.data$Easting <- soil.data$UTMX
soil.data$Northing <- soil.data$UTMY
soil.data$Easting2 <- soil.data$Easting * soil.data$Easting
soil.data$Northing2 <- soil.data$Northing * soil.data$Northing
soil.data$EastingNorthing <- soil.data$Northing * soil.data$Easting

soil.data$MAPPET <- soil.data$MAP * soil.data$PET
soil.data$MAT2 <- soil.data$MAT * soil.data$MAT
soil.data$CMDMAT <- soil.data$CMD * soil.data$MAT
soil.data$MWMT2 <- soil.data$MWMT * soil.data$MWMT

soil.data$bio9 <- soil.data$MTD
soil.data$bio15 <- soil.data$PS
soil.data$paspen <- soil.data$pAspen

# 2.4 Standardize row names
rownames(climate.data) <- climate.data$SiteYearQu
rownames(veg.data) <- veg.data$SiteYearQu
rownames(soil.data) <- soil.data$SiteYearQu

veg.data <- veg.data[rownames(climate.data), ]
soil.data <- soil.data[rownames(climate.data), ]

# 2.5 Add a protocol factor
climate.data$Protocol <- as.factor(ifelse(climate.data$Year < 2009, "Old", "New"))
veg.data$Protocol <- as.factor(ifelse(veg.data$Year < 2009, "Old", "New"))
soil.data$Protocol <- as.factor(ifelse(soil.data$Year < 2009, "Old", "New"))

# 2.6 Save the results
save(climate.data, veg.data, soil.data, veg.pm, soil.pm, veg.species.list, soil.species.list,
     file = "0_data/species/processed/lichen-model-data.Rdata")

# 3.0 Vascular plants ----
rm(list=ls())
gc()

# 3.1 Load the species data and prediction matrix for the north
load("0_data/species/raw/R Dataset SpTable for ABMI North plant coefficients 2024_Quad.RData")
veg.data <- qd
veg.pm <- pm
veg.species.list <- SpTable

# 3.2 Load the species data and prediction matrix for the south
load("0_data/species/raw/R Dataset SpTable for ABMI South plant coefficients 2024_Quad.RData")
soil.data <- qd
soil.pm <- pm
soil.species.list <- SpTable

rm(d, pm, qd, FirstSpCol, LastSpCol, SppToCheck, SpTable, SpTable.ua)

# 3.3 Create the climate data
climate.data <- veg.data[, 1:1407]
climate.data$Easting <- climate.data$UTMX
climate.data$Northing <- climate.data$UTMY
climate.data$Easting2 <- climate.data$Easting * climate.data$Easting
climate.data$Northing2 <- climate.data$Northing * climate.data$Northing
climate.data$EastingNorthing <- climate.data$Northing * climate.data$Easting

climate.data$MAPPET <- climate.data$MAP * climate.data$PET
climate.data$MAT2 <- climate.data$MAT * climate.data$MAT
climate.data$CMDMAT <- climate.data$CMD * climate.data$MAT
climate.data$MWMT2 <- climate.data$MWMT * climate.data$MWMT

climate.data$bio9 <- climate.data$MTD
climate.data$bio15 <- climate.data$PS

# Veg
veg.data$Easting <- veg.data$UTMX
veg.data$Northing <- veg.data$UTMY
veg.data$Easting2 <- veg.data$Easting * veg.data$Easting
veg.data$Northing2 <- veg.data$Northing * veg.data$Northing
veg.data$EastingNorthing <- veg.data$Northing * veg.data$Easting

veg.data$MAPPET <- veg.data$MAP * veg.data$PET
veg.data$MAT2 <- veg.data$MAT * veg.data$MAT
veg.data$CMDMAT <- veg.data$CMD * veg.data$MAT
veg.data$MWMT2 <- veg.data$MWMT * veg.data$MWMT

veg.data$bio9 <- veg.data$MTD
veg.data$bio15 <- veg.data$PS

# Lowland 
veg.data$Lowland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                         "BlackSpruce2", "BlackSpruce3",
                                         "BlackSpruce4", "BlackSpruce5",
                                         "BlackSpruce6", "BlackSpruce7",
                                         "BlackSpruce8", "TreedFen", 
                                         "TreedSwamp", "GraminoidFen",
                                         "Marsh", "ShrubbyFen",
                                         "ShrubbySwamp", "ShrubbyBog")])
# Peatland
veg.data$Peatland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                          "BlackSpruce2", "BlackSpruce3",
                                          "BlackSpruce4", "BlackSpruce5",
                                          "BlackSpruce6", "BlackSpruce7",
                                          "BlackSpruce8", "TreedFen", 
                                          "GraminoidFen",  
                                          "ShrubbyFen","ShrubbyBog")])

# Mineral
veg.data$Mineral <- rowSums(veg.data[, c("TreedSwamp", "ShrubbySwamp", 
                                         "Marsh")])

# Upland
veg.data$Upland <- rowSums(veg.data[, c("DeciduousR", "Deciduous1", 
                                        "Deciduous2", "Deciduous3",
                                        "Deciduous4", "Deciduous5",
                                        "Deciduous6", "Deciduous7",
                                        "Deciduous8", "MixedwoodR", 
                                        "Mixedwood1", "Mixedwood2", 
                                        "Mixedwood3", "Mixedwood4", 
                                        "Mixedwood5", "Mixedwood6", 
                                        "Mixedwood7", "Mixedwood8",
                                        "PineR", "Pine1", 
                                        "Pine2", "Pine3",
                                        "Pine4", "Pine5",
                                        "Pine6", "Pine7",
                                        "Pine8", "WhiteSpruceR", 
                                        "WhiteSpruce1", "WhiteSpruce2", 
                                        "WhiteSpruce3", "WhiteSpruce4", 
                                        "WhiteSpruce5", "WhiteSpruce6", 
                                        "WhiteSpruce7", "WhiteSpruce8")])

# CCR1234
veg.data$CCR1234 <- rowSums(veg.data[, c("CCDeciduousR", "CCDeciduous1", 
                                        "CCDeciduous2", "CCDeciduous3",
                                        "CCDeciduous4", "CCMixedwoodR",
                                        "CCMixedwood1", "CCMixedwood2",
                                        "CCMixedwood3", "CCMixedwood4", 
                                        "CCPineR", "CCPine1",
                                        "CCPine2", "CCPine3",
                                        "CCPine4", "CCWhiteSpruceR",
                                        "CCWhiteSpruce1", "CCWhiteSpruce2",
                                        "CCWhiteSpruce3", "CCWhiteSpruce4")])

# Soil
soil.data$Easting <- soil.data$UTMX
soil.data$Northing <- soil.data$UTMY
soil.data$Easting2 <- soil.data$Easting * soil.data$Easting
soil.data$Northing2 <- soil.data$Northing * soil.data$Northing
soil.data$EastingNorthing <- soil.data$Northing * soil.data$Easting

soil.data$MAPPET <- soil.data$MAP * soil.data$PET
soil.data$MAT2 <- soil.data$MAT * soil.data$MAT
soil.data$CMDMAT <- soil.data$CMD * soil.data$MAT
soil.data$MWMT2 <- soil.data$MWMT * soil.data$MWMT

soil.data$bio9 <- soil.data$MTD
soil.data$bio15 <- soil.data$PS
soil.data$paspen <- soil.data$pAspen

# 3.4 Standardize row names
rownames(climate.data) <- climate.data$SiteYearQu
rownames(veg.data) <- veg.data$SiteYearQu
rownames(soil.data) <- soil.data$SiteYearQu

veg.data <- veg.data[rownames(climate.data), ]
soil.data <- soil.data[rownames(climate.data), ]

# 3.5 Save the results
save(climate.data, veg.data, soil.data, veg.pm, soil.pm, veg.species.list, soil.species.list,
     file = "0_data/species/processed/vascular-plant-model-data.Rdata")

# 4.0 Soil mites ----
rm(list=ls())
gc()

# 4.1 Load the species data and prediction matrix for the north
load("0_data/species/raw/R Dataset SpTable for ABMI North mite coefficients 2024_Quad.RData")
veg.data <- qd
veg.pm <- pm
veg.species.list <- SpTable

# 4.2 Load the species data and prediction matrix for the south
load("0_data/species/raw/R Dataset SpTable for ABMI South mite coefficients 2024_Quad.RData")
soil.data <- qd
soil.pm <- pm
soil.species.list <- SpTable

rm(d, pm, qd, FirstSpCol, LastSpCol, SpTable, SpTable.ua)

# 4.3 Create the climate data and standarize across files
climate.data <- veg.data[, 1:327]
climate.data$Easting <- climate.data$UTMX
climate.data$Northing <- climate.data$UTMY
climate.data$Easting2 <- climate.data$Easting * climate.data$Easting
climate.data$Northing2 <- climate.data$Northing * climate.data$Northing
climate.data$EastingNorthing <- climate.data$Northing * climate.data$Easting

climate.data$MAPPET <- climate.data$MAP * climate.data$PET
climate.data$MAT2 <- climate.data$MAT * climate.data$MAT
climate.data$CMDMAT <- climate.data$CMD * climate.data$MAT
climate.data$MWMT2 <- climate.data$MWMT * climate.data$MWMT

climate.data$bio9 <- climate.data$MTD
climate.data$bio15 <- climate.data$PS

# Veg
veg.data$Easting <- veg.data$UTMX
veg.data$Northing <- veg.data$UTMY
veg.data$Easting2 <- veg.data$Easting * veg.data$Easting
veg.data$Northing2 <- veg.data$Northing * veg.data$Northing
veg.data$EastingNorthing <- veg.data$Northing * veg.data$Easting

veg.data$MAPPET <- veg.data$MAP * veg.data$PET
veg.data$MAT2 <- veg.data$MAT * veg.data$MAT
veg.data$CMDMAT <- veg.data$CMD * veg.data$MAT
veg.data$MWMT2 <- veg.data$MWMT * veg.data$MWMT

veg.data$bio9 <- veg.data$MTD
veg.data$bio15 <- veg.data$PS

# Lowland 
veg.data$Lowland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                         "BlackSpruce2", "BlackSpruce3",
                                         "BlackSpruce4", "BlackSpruce5",
                                         "BlackSpruce6", "BlackSpruce7",
                                         "BlackSpruce8", "TreedFen", 
                                         "TreedSwamp", "GraminoidFen",
                                         "Marsh", "ShrubbyFen",
                                         "ShrubbySwamp", "ShrubbyBog")])
# Peatland
veg.data$Peatland <- rowSums(veg.data[, c("BlackSpruceR", "BlackSpruce1", 
                                          "BlackSpruce2", "BlackSpruce3",
                                          "BlackSpruce4", "BlackSpruce5",
                                          "BlackSpruce6", "BlackSpruce7",
                                          "BlackSpruce8", "TreedFen", 
                                          "GraminoidFen",  
                                          "ShrubbyFen","ShrubbyBog")])

# Mineral
veg.data$Mineral <- rowSums(veg.data[, c("TreedSwamp", "ShrubbySwamp", 
                                         "Marsh")])

# Upland
veg.data$Upland <- rowSums(veg.data[, c("DeciduousR", "Deciduous1", 
                                        "Deciduous2", "Deciduous3",
                                        "Deciduous4", "Deciduous5",
                                        "Deciduous6", "Deciduous7",
                                        "Deciduous8", "MixedwoodR", 
                                        "Mixedwood1", "Mixedwood2", 
                                        "Mixedwood3", "Mixedwood4", 
                                        "Mixedwood5", "Mixedwood6", 
                                        "Mixedwood7", "Mixedwood8",
                                        "PineR", "Pine1", 
                                        "Pine2", "Pine3",
                                        "Pine4", "Pine5",
                                        "Pine6", "Pine7",
                                        "Pine8", "WhiteSpruceR", 
                                        "WhiteSpruce1", "WhiteSpruce2", 
                                        "WhiteSpruce3", "WhiteSpruce4", 
                                        "WhiteSpruce5", "WhiteSpruce6", 
                                        "WhiteSpruce7", "WhiteSpruce8")])

# CCR1234
veg.data$CCR1234 <- rowSums(veg.data[, c("CCDeciduousR", "CCDeciduous1", 
                                        "CCDeciduous2", "CCDeciduous3",
                                        "CCDeciduous4", "CCMixedwoodR",
                                        "CCMixedwood1", "CCMixedwood2",
                                        "CCMixedwood3", "CCMixedwood4", 
                                        "CCPineR", "CCPine1",
                                        "CCPine2", "CCPine3",
                                        "CCPine4", "CCWhiteSpruceR",
                                        "CCWhiteSpruce1", "CCWhiteSpruce2",
                                        "CCWhiteSpruce3", "CCWhiteSpruce4")])

# Soil
soil.data$Easting <- soil.data$UTMX
soil.data$Northing <- soil.data$UTMY
soil.data$Easting2 <- soil.data$Easting * soil.data$Easting
soil.data$Northing2 <- soil.data$Northing * soil.data$Northing
soil.data$EastingNorthing <- soil.data$Northing * soil.data$Easting

soil.data$MAPPET <- soil.data$MAP * soil.data$PET
soil.data$MAT2 <- soil.data$MAT * soil.data$MAT
soil.data$CMDMAT <- soil.data$CMD * soil.data$MAT
soil.data$MWMT2 <- soil.data$MWMT * soil.data$MWMT

soil.data$bio9 <- soil.data$MTD
soil.data$bio15 <- soil.data$PS
soil.data$paspen <- soil.data$pAspen

# 4.4 Standardize row names
rownames(climate.data) <- climate.data$SiteYearQu
rownames(veg.data) <- veg.data$SiteYearQu
rownames(soil.data) <- soil.data$SiteYearQu

veg.data <- veg.data[rownames(climate.data), ]
soil.data <- soil.data[rownames(climate.data), ]

# 4.5 Save the results
save(climate.data, veg.data, soil.data, veg.pm, soil.pm, veg.species.list, soil.species.list,
     file = "0_data/species/processed/mite-model-data.Rdata")

rm(list=ls())
gc()
