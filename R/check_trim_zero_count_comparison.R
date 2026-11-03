#!/usr/bin/env Rscript
source('R/compare_trim_zero_count_models.R')
d <- expand.grid(plot_id=1:3,jaar=2000:2007)
d$geteld <- TRUE
d$count_adjusted <- c(2,3,4)[d$plot_id]*.8^(d$jaar-2000)
f <- fit_zero_count_curve(d,2000:2007,'linear')
stopifnot(f$ok,isTRUE(all.equal(unname(f$index),100*.8^(0:7),tolerance=1e-7)))
# Dropping a real all-zero year or adding a pseudo-count must be caught.
z <- d;z$count_adjusted[z$jaar==2003] <- 0
fz <- fit_zero_count_curve(z,2000:2007,'linear')
stopifnot(fz$ok,sum(fz$data$count_adjusted==0)==3L,length(fz$index)==8L,all(is.finite(fz$index)),all(fz$index>0))
z10 <- z;z10$count_adjusted <- 10*z10$count_adjusted
f10 <- fit_zero_count_curve(z10,2000:2007,'linear')
stopifnot(f10$ok,isTRUE(all.equal(fz$index,f10$index,tolerance=1e-6)))
fs <- fit_zero_count_curve(z,2000:2007,'smooth')
stopifnot(fs$ok,length(fs$index)==8L,sum(fs$data$count_adjusted==0)==3L)
empty <- z;empty$count_adjusted <- 0
stopifnot(!fit_zero_count_curve(empty,2000:2007,'linear')$ok)
# An unobserved year remains tagged as prediction, never treated as a counted zero.
gap <- z[!(z$jaar==2002),]
fg <- fit_zero_count_curve(gap,2000:2007,'linear')
stopifnot(fg$ok,identical(fg$unobserved_years,2002L),!2002L%in%fg$data$jaar)
cat('Telmodelvergelijking: bekende groei, echte nullen, schaal en ontbrekend jaar OK.\n')
cv_data <- expand.grid(plot_id=1:3,jaar=1990:2019);cv_data$geteld<-TRUE
cv_data$count_adjusted <- c(2,3,4)[cv_data$plot_id]*.95^(cv_data$jaar-1990)
cv <- zero_count_cv(cv_data,1990:2019,'linear')
stopifnot(nrow(cv)==5L,all(cv$status=='berekenbaar'),sum(cv$n_test)==nrow(cv_data),abs(sum(cv$deviance))<1e-6)
rare <- cv_data;rare$count_adjusted[rare$plot_id==3&rare$jaar!=1990]<-0
rcv <- zero_count_cv(rare,1990:2019,'linear')
stopifnot(any(rcv$status=='onvoldoende_positieve_trainingssteun'))
cat('Geblokkeerde tijdsvalidatie bewaart volledige dekking en meldt ontbrekende trainingssteun.\n')

# Inner IRLS convergence alone must not hide a failed smoothing optimisation.
bad_optim <- fs$model;bad_optim$outer.info$conv <- 'iteration limit reached'
stopifnot(!zero_count_fit_converged(bad_optim),zero_count_fit_converged(fs$model))
