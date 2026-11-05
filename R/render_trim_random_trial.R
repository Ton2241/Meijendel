#!/usr/bin/env Rscript
args<-commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
trial<-args[1];old<-args[2];out<-args[3];source(path.expand('~/Documents/GitHub/Meijendel/R/trial_storage.R'));out<-trial_output(out);dir.create(out,recursive=TRUE,showWarnings=FALSE)
r<-read.csv(file.path(trial,'curves.csv'));r<-r[r$replicate_id==0L,]
a<-read.csv(file.path(old,'curves.csv'));a<-a[a$series=='jaarindex',]
s<-read.csv(file.path(trial,'summary.csv'));nm<-setNames(s$soort_naam,s$soort_id)
for(id in s$soort_id){
 p<-r[r$soort_id==id,];q<-a[a$soort_id==id,]
 p$plot_value<-100*p$index_value/mean(p$index_value[p$jaar%in%1979:1983]);q$plot_value<-100*q$index_value/mean(q$index_value[q$jaar%in%1979:1983])
 grDevices::png(file.path(out,paste0('curve_',id,'.png')),width=1700,height=900,res=140)
 par(mfrow=c(1,2),mar=c(4,4,3,1),oma=c(3,1,3,1))
 for(recent in c(FALSE,TRUE)){
  pp<-if(recent)p[p$jaar>=2005,] else p;qq<-if(recent)q[q$jaar>=2005,] else q
  ymax<-max(c(pp$plot_value,qq$plot_value),na.rm=TRUE)*1.05
  plot(range(c(pp$jaar,qq$jaar)),c(0,if(ymax>0)ymax else 1),type='n',xlab='Jaar',ylab='Index (gemiddeld 1979–1983 = 100)',main=if(recent)'2005–2025' else 'Volledige reeks')
  lines(qq$jaar,qq$plot_value,col='#343434');points(qq$jaar,qq$plot_value,pch=16,cex=.5,col='#343434')
  lines(pp$jaar,pp$plot_value,col='#0072B2',lwd=2);abline(h=0,col='gray70');if(!recent)abline(v=1983.5,lty=3,col='gray50')
 }
 mtext(paste0(nm[as.character(id)],' — proef met gedeelde kavelinformatie'),outer=TRUE,side=3,line=1,font=2,cex=1.2)
 par(fig=c(0,1,.01,.09),oma=c(0,0,0,0),new=TRUE,mar=c(0,0,0,0));plot.new()
 legend('center',legend=c('Bestaande jaarindex','Modelverwachting met random kaveleffect'),col=c('#343434','#0072B2'),lty=1,lwd=c(1,2),bty='n',horiz=TRUE)
 dev.off()
}

# Extra uncertainty for completely unobserved reference plots, separately from count noise.
d<-read.csv(file.path(trial,'diagnostics.csv'));d<-d[d$replicate_id==0L,]
u<-d[c('soort_id','period','tau2','n_unknown_reference_cells')]
u$unknown_site_relative_sd<-sqrt(expm1(u$tau2))
u$unknown_site_extra_link_sd<-sqrt(u$tau2)
u$marginal_mean_multiplier<-exp(u$tau2/2)
write.csv(u,file.path(out,'unknown_site_uncertainty.csv'),row.names=FALSE)
