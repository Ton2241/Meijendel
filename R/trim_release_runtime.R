# Historical cache adapter ONLY for an explicitly isolated, loopback rehearsal.
# The archived cache keeps its true parser version; production validation is untouched.
load_historical_release_cache <- function(sql_path,include_out_of_scope_kavels=NULL) {
 if(!identical(Sys.getenv('MEIJENDEL_ALLOW_HISTORICAL_REHEARSAL'),'1') ||
    !identical(Sys.getenv('MEIJENDEL_BIND_HOST'),'127.0.0.1'))stop('Historische proefcache uitsluitend expliciet op loopback')
 control<-normalizePath(Sys.getenv('MEIJENDEL_RELEASE_MANIFEST'),mustWork=TRUE)
 m<-jsonlite::read_json(control,simplifyVector=TRUE)
 if(!identical(m$schema,'meijendel-integral-release-v1') || !identical(m$mode,'local_rehearsal') || m$year_to>2025L)stop('Geen geschikte historische proefrelease')
 relative<-m$cache$root
 if(grepl('^/|(^|/)\\.\\.(/|$)',relative))stop('Onveilig historisch cachepad')
 path<-normalizePath(file.path(dirname(control),relative),mustWork=TRUE)
 if(!startsWith(path,paste0(dirname(control),'/')))stop('Cachepad buiten release')
 cm<-read_meijendel_manifest(paste0(sub('\\.rds$','',path),'.manifest'))
 if(as.integer(cm[['parser_version']])!=13L || !identical(cm[['sql_sha256']],m$source_hash) ||
    !identical(sha256_file(path),m$cache$sha256) || !identical(sha256_file(sql_path),m$source_hash))stop('Historische bron-/cache-identiteit wijkt af')
 cache<-readRDS(path);expected<-meijendel_cache_identity_from_manifest(cm,13L)
 validate_meijendel_cache(cache,expected,c('plots','plot_analyse_scope','soorten','territoria'))
 if(is.null(include_out_of_scope_kavels))include_out_of_scope_kavels<-meijendel_out_of_scope_from_env()
 data<-apply_meijendel_plot_scope(cache$data,include_out_of_scope_kavels)
 data$sql_path<-sql_path;attr(data,'historical_rehearsal_parser')<-13L
 list(data=data,from_cache=TRUE,cache_path=path,historical_rehearsal=TRUE,parser_version=13L)
}
