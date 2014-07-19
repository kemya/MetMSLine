require(fgui)


Auto.PCA<- function(PreProc.output="QC_Corrected.csv",Yvar="Y.csv",QCInterval=5,PCA.method="svd",scaling="uv",out.tol=1.2,study.dir="D:/R_data_processing/STUDY NAME/") {
  ##automatic multivariate data analysis function. Function takes QC corrected output csv files and performs PCA, automated 
  ##outlier removal based on Hotellings T2 distribution. Based on an acceptable tolerance representing a proportional expansion of the ellipse
  ##around the ellipse. Strong outliers identified by 2 rounds of PCA calculation are saved in a seperate .csv result for visual examination.
  ##function saves all figures according to user defined settings.
  ##Function then performs linear regression analysis to any Y-variable where non-zero data exists for more than 10 samples, using pearson product moment correlation with p-values calculated by F-test and then corrected by Bonferroni's
  ##method, subfolders for each Y-variable are generated and results saved within. Scatterplots demonstrating the relationship between X and Y are also automatically generated.
  
  study.dir<-paste(study.dir,"PreProc.QC.RLSC.results/",sep="")
  
  ###save parameters used for data generation###
  Parameters<-data.frame(PreProc.output,Yvar,QCInterval,PCA.method,scaling,out.tol)
  
  setwd(study.dir)
  
  require(pcaMethods)
 
  ###Load .csv files for X and Y matrices###
  X<-as.data.frame(read.csv(PreProc.output,header=T))
  
  X<-X[-which(X$RSD_corr_below!=1),] # subset all variables below RSD threshold
  X<-X[rowSums(is.na(X))<5, ] # remove all observations with more than 5 N/A
  
  ###read in Y variables from parent directory###
  Ydir.name<-substr(study.dir,1,nchar(study.dir)-24)
  
  setwd(Ydir.name)
  
  Y<-t(read.csv(Yvar,header=T,row.names=1))#dietary or Y independent variables for regression analyses
  
  ###create Auto.PCA results sub directory to keep everything tidy####
  
  dir.name<-paste(substr(study.dir,1,nchar(study.dir)-24),"Auto.PCA.results/",sep="")
  
  dir.create(dir.name)
 
  setwd(dir.name)
  date<-Sys.time()
  date<-gsub("-",".",date)
  write.csv(Parameters,paste("Parameters",substr(date,1,10),".csv",sep=" "),row.names=FALSE)
  
  dir<-paste(dir.name,"PCA.model.1/",sep="")
  ##create new folder in which to save results
  dir.create(dir)
  setwd(dir)
  ##QC and sample class dummy matrix
  
  XCMScolumnsIndex<-c(1:which(colnames(X)=="RSD_corr_below"))
  XCMScolumns<-X[,XCMScolumnsIndex]
  PCA.data<-X[,-XCMScolumnsIndex] # all observations in run order
  
  PCA.index<-1:ncol(PCA.data)
  QCdummyMindex<-seq(1,length(PCA.data),QCInterval) # dummy matrix of QC injection position for PCA modelling
  QCdummyM<-rep(0,ncol(PCA.data))
  QCdummyM[QCdummyMindex]<-1
  
  ####PCA analysis, figure creation and outlier removal
   
  ##Preprocessing matrix for PCA and PLS
  
  #PCA.data.scaled<-prep(PCA.data, scale = c(scaling), center = TRUE, simple = TRUE, reverse = FALSE)
  tPCA.data<-t(PCA.data)
  ##PCA using probabilistic PCA method 
  pca.result <- pca(tPCA.data, nPcs = 2, method=PCA.method,scale=scaling, centre=TRUE, cv="q2",seed=123)
  
  ## Get the estimated principal axes (loadings)
  loadings <- pca.result@loadings
  loadings<-cbind(XCMScolumns,loadings)
  write.csv(loadings,"Loadings.PCA.1.csv",row.names=FALSE)
  
  model.summary<-data.frame(pca.result@R2,pca.result@R2cum,pca.result@cvstat)
  write.csv(model.summary,"model.CV.summary.1.csv")
  ## Get the estimated scores
  scores <- pca.result@scores
  write.csv(scores,"Scores.PCA.1.csv")
  DModX<-DModX(pca.result) # distance to model calculation/possible plot here??
   
  ##Hotellings T2 statistic and ellipse calculation function##
  HotE<- function (x, y, len = 200,alfa=0.95) 
  { N <- length(x)
    A <- 2
    mypi <- seq(0, 2 * pi, length = len)
    r1 <- sqrt(var(x) * qf(alfa,2, N-2) * (2*(N^2-1)/(N*(N - 2))))
    r2 <- sqrt(var(y) * qf(alfa,2, N-2) * (2*(N^2-1)/(N *(N-2))))
    cbind(r1 * cos(mypi) + mean(x), r2*sin(mypi)+mean(y))
  }
  
  HotEllipse<-abs(cbind(HotE(scores[,1],scores[,2])))*out.tol ##HotE(scores[,2],scores[,3])))*out.tol
  outliers<-as.numeric()
  for (i in 1:nrow(scores)){
    
    sample<-abs(scores[i,])
    out.PC1<-which(HotEllipse[,1]<sample[1])
    out.PC1.PC2<-any(HotEllipse[out.PC1,2]<sample[2])*1
    #out.PC2<-which(HotEllipse[,3]<sample[2])
    #out.PC3<-which(HotEllipse[,4]<sample[3])
    #out.PC1.PC3<-any(HotEllipse[out.PC3,1]<sample[1])*1
    #out.PC2.PC3<-any(HotEllipse[out.PC3,3]<sample[2])*1
    
    outlier<-ifelse(out.PC1.PC2>0,1,0)#+out.PC1.PC3+out.PC2.PC3>0,1,0)
    outliers<-c(outliers,outlier)
  }
  QCdummyM<-ifelse(outliers==1,2,QCdummyM)
  outliers<-which(outliers==1)
  
  ## Now plot the scores and save as PNG and PDF files
  pdf("PCA_scores.pdf")
  plotPcs(pca.result, type = "scores",col=QCdummyM+1,pch=19)
  dev.off()
  
  png("PCA_scores.png",width=1200,height=1200,res=275)
  plotPcs(pca.result, type = "scores",col=QCdummyM+1,pch=19)
  dev.off()
  
  
  if(length(outliers)>1){
    ## name Model 1 outliers and create summary
    dir<-paste(dir.name,"PCA.model.2/",sep="")
    ##create new folder in which to save results
    dir.create(dir)
    setwd(dir)
    outlier.names.1<-as.matrix(paste(rep("Model_1",length(outliers)),row.names(tPCA.data)[outliers],sep=" "))
    outlier.scores.1<-as.matrix(scores[outliers,])
    outlier.DModX.1<-as.matrix(DModX[outliers])
     outliers.summary.1<-cbind(outlier.names.1,outlier.scores.1,outlier.DModX.1)
    colnames(outliers.summary.1) <- c("sample", "PC1.scores","PC2.scores","DModX")#,"PC3.scores","DModX")
    
    tPCA.data<-tPCA.data[-outliers,]
    
    QCdummyM<-QCdummyM[-outliers]
    pca.result.2 <- pca(tPCA.data, nPcs = 2, method=PCA.method,scale=scaling, centre=TRUE, cv="q2",seed=123)
    loadings.2 <- pca.result.2@loadings
    scores.2 <- pca.result.2@scores
    ###bind loadings to XCMS variable information
    loadings.2<-cbind(XCMScolumns,loadings.2)
    write.csv(loadings.2,"Loadings.PCA.2.csv",row.names=FALSE)
    write.csv(scores.2,"Scores.PCA.2.csv")
    model.summary<-data.frame(pca.result.2@R2,pca.result.2@R2cum,pca.result.2@cvstat)
    write.csv(model.summary,"model.CV.summary.2.csv")
    
    DModX.2<-DModX(pca.result.2)
    
    HotEllipse<-abs(cbind(HotE(scores.2[,1],scores.2[,2])))*out.tol##,HotE(scores.2[,2],scores.2[,3])))*out.tol
    outliers.2<-as.numeric()
    for (i in 1:nrow(scores.2)){
      
      sample<-abs(scores.2[i,])
      out.PC1<-which(HotEllipse[,1]<sample[1])
      out.PC1.PC2<-any(HotEllipse[out.PC1,2]<sample[2])*1
      #out.PC2<-which(HotEllipse[,3]<sample[2])
      #out.PC3<-which(HotEllipse[,4]<sample[3])
      #out.PC1.PC3<-any(HotEllipse[out.PC3,1]<sample[1])*1
      #out.PC2.PC3<-any(HotEllipse[out.PC3,3]<sample[2])*1
      
      outlier<-ifelse(out.PC1.PC2>0,1,0)##+out.PC1.PC3+out.PC2.PC3>0,1,0)
      outliers.2<-c(outliers.2,outlier)
    }
    QCdummyM<-ifelse(outliers.2==1,2,QCdummyM)
    outliers.2<-which(outliers.2==1)
    
    
    pdf("PCA_scores.2.pdf")
    plotPcs(pca.result.2, type = "scores",col=QCdummyM+1,pch=19)
    dev.off()
    
    png("PCA_scores.2.png",width=1200,height=1200,res=275)
    plotPcs(pca.result.2, type = "scores",col=QCdummyM+1,pch=19)
    dev.off()
          
  
  if(length(outliers.2)>1) {
    ## name Model 2 outliers and create summary
    #names(outliers.2)<-paste(rep("Model_2",length(outliers.2)),names(outliers.2),sep=" ") #names outliers
    ## name Model 1 outliers and create summary
    dir<-paste(dir.name,"PCA.model.3/",sep="")
    ##create new folder in which to save results
    dir.create(dir)
    setwd(dir)
    outlier.names.2<-as.matrix(paste(rep("Model_2",length(outliers.2)),row.names(tPCA.data)[outliers.2],sep=" "))
    outlier.scores.2<-as.matrix(scores[outliers.2,])
    outlier.DModX.2<-as.matrix(DModX[outliers.2])
    
    #rbind(outlier.names.1,outlier.names.2),
    outliers.summary.2<-cbind(rbind(outlier.names.1,outlier.names.2),rbind(outlier.scores.1,outlier.scores.2),rbind(outlier.DModX.1,outlier.DModX.2))
    colnames(outliers.summary.2) <- c("sample", "PC1.scores","PC2.scores","DModX") ##,"PC3.scores","DModX")
    
    tPCA.data<-tPCA.data[-outliers.2,]
  
    QCdummyM<-QCdummyM[-outliers.2]
    pca.result.3 <- pca(tPCA.data, nPcs = 2, method=PCA.method,scale=scaling, centre=TRUE, cv="q2",seed=123)
    loadings.3 <- pca.result.3@loadings
    scores.3 <- pca.result.3@scores
    loadings.3<-cbind(XCMScolumns,loadings.3)
    write.csv(loadings.3,"Loadings.PCA.3.csv",row.names=FALSE)
    write.csv(scores.3,"Scores.PCA.3.csv")
    model.summary<-data.frame(pca.result.3@R2,pca.result.3@R2cum,pca.result.3@cvstat)
    write.csv(model.summary,"model.CV.summary.3.csv")
    
    DModX.3<-as.matrix(DModX(pca.result.3))
  
    HotEllipse<-abs(cbind(HotE(scores.3[,1],scores.3[,2])))*out.tol##,HotE(scores.3[,2],scores.3[,3])))*out.tol
    outliers.3<-as.numeric()
    for (i in 1:nrow(scores.3)){
      
      sample<-abs(scores.3[i,])
      out.PC1<-which(HotEllipse[,1]<sample[1])
      out.PC1.PC2<-any(HotEllipse[out.PC1,2]<sample[2])*1
      #out.PC2<-which(HotEllipse[,3]<sample[2])
      #out.PC3<-which(HotEllipse[,4]<sample[3])
      #out.PC1.PC3<-any(HotEllipse[out.PC3,1]<sample[1])*1
      #out.PC2.PC3<-any(HotEllipse[out.PC3,3]<sample[2])*1
      
      outlier<-ifelse(out.PC1.PC2>0,1,0)##+out.PC1.PC3+out.PC2.PC3>0,1,0)
      outliers.3<-c(outliers.3,outlier)
    }
    QCdummyM<-ifelse(outliers.3==1,2,QCdummyM)
    outliers.3<-which(outliers.3==1)
    
    
    pdf("PCA_scores.3.pdf")
    plotPcs(pca.result.3, type = "scores",col=QCdummyM+1,pch=19)
    dev.off()
    
    
    png("PCA_scores.3.png",width=1200,height=1200,res=275)
    plotPcs(pca.result.3, type = "scores",col=QCdummyM+1,pch=19)
    dev.off()
    
  
  
  if (length(outliers.3)>1){
    ## name Model 3 outliers and create summary
    #names(outliers.3)<-paste(rep("Model_3",length(outliers.3)),names(outliers.3),sep=" ") #names outliers
    setwd(dir.name)
    outlier.names.3<-as.matrix(paste(rep("Model_3",length(outliers.3)),row.names(tPCA.data)[outliers.3],sep=" "))
    outlier.scores.3<-as.matrix(scores[outliers.3,])
    outlier.DModX.3<-as.matrix(DModX[outliers.3])
    #rbind(outlier.names.1,outlier.names.2,outlier.names.3),
    outliers.summary.3<-cbind(rbind(outlier.names.1,outlier.names.2,outlier.names.3),rbind(outlier.scores.1,outlier.scores.2,outlier.scores.3),rbind(outlier.DModX.1,outlier.DModX.2,outlier.DModX.3))
    colnames(outliers.summary.3) <- c("sample", "PC1.scores","PC2.scores","DModX")##,"PC3.scores","DModX")
    write.csv(outliers.summary.3,"outliers_summary.csv",row.names=FALSE)
    
    tPCA.data<-tPCA.data[-outliers.3,]
  
    QCdummyM<-QCdummyM[-outliers.3]
    
  }else if (length(outliers.3)<=1) {
    setwd(dir.name)
    write.csv(outliers.summary.2,"outliers_summary.csv",row.names=FALSE)
  }
    
  }else if (length(outliers.2)<=1) {
    setwd(dir.name)
    write.csv(outliers.summary.1,"outliers_summary.csv",row.names=FALSE)
  }
    
  } else if (length(outliers)==0) {
    setwd(dir.name)
   }
  ##QC sample indexing, sample subsetting and outlier removal

  setwd(dir.name)
  
  Samples<-as.data.frame(t(tPCA.data[-QCdummyM==0,]))
  
  SampleIndex<-colnames(Y) %in% colnames(Samples)  
  Y<-as.data.frame(t(Y[,SampleIndex]))
 
  PCA.outliers.removed<-cbind(XCMScolumns,Samples)
  
  write.csv(Y,"Y.outliers.removed.csv",row.names=TRUE)
  
  write.csv(PCA.outliers.removed,"PCA.outliers.removed.csv",row.names=FALSE)  
  
}  

guiv(Auto.PCA,argOption=list(scaling=c("none", "pareto", "vector", "uv"),PCA.method=c("svd", "nipals", "bpca", "ppca")),helps=NULL)#,argOption=list())#scatter.plots=c("TRUE","FALSE")))
