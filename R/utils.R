#
# pull_additive_component <- function(gp) {
#
# 	tibble::tibble(add = switch(
# 		attr(x = gp, which = 'crosstype'),
# 		'f2' = gp[,2,] + 2*gp[,3,],
# 		'bc' = gp[,2],
# 		'do' =
# 	)
# 	)
# }


tryNA <- function(expr) {
  suppressWarnings(tryCatch(expr = expr,
                            error = function(e) NA,
                            finally = NA))
}

fit_dglm <- function(mf, vf, locus_data, family, wts = NULL, error_silently = TRUE) {

  # this didn't work -- some problem with how dglm eval's namespaces?
  # fit_dglm_ <- purrr::compose(ifelse(test = error_silently, yes = tryNA, no = identity),
  #                             dglm::dglm)
  #
  # fit_dglm_(formula = mf,
  #           dformula = vf,
  #           data = force(locus_data),
  #           method = 'ml',
  #           family = family,
  #           ykeep = FALSE)

  if (error_silently) {
    tryNA(
      dglm::dglm(
        formula = mf,
        dformula = vf,
        data = locus_data,
        method = 'ml',
        family = family,
        ykeep = FALSE)
    )
  } else {
    dglm::dglm(
      formula = mf,
      dformula = vf,
      data = locus_data,
      method = 'ml',
      family = family,
      ykeep = FALSE
    )
  }
}

fit_hglm <- function(mf, df, data, glm_family) {#, obs_weights) {
  stop('commented out because hglm package archived on CRAN')
  # hglm::hglm2(meanmodel = mf, disp = df, data = data, calc.like = TRUE, family = glm_family)#, weights = obs_weights)
}

# fit_dhglm <- function(mf, df, data) {
#   stop('dhglm not yet implemented.')
# }

# fit_model <- function(formulae,
#                       data,
#                       mean = c('alt', 'null'),
#                       var = c('alt', 'null'),
#                       model = c('dglm', 'hglm', 'dhglm'),
#                       glm_family = c('gaussian', 'poisson'),
#                       permute_what = c('none', 'mean', 'var', 'both'),
#                       the.perm = seq(from = 1, to = nrow(data)),
#                       obs_weights = rep(1, nrow(data))) {
#
#   mean <- match.arg(arg = mean)
#   var <- match.arg(arg = var)
#   model <- match.arg(arg = model)
#   glm_family <- match.arg(arg = glm_family)
#   permute_what <- match.arg(arg = permute_what)
#
#   mf <- switch(mean, alt = formulae[['mean.alt.formula']], null = formulae[['mean.null.formula']])
#   vf <- switch(var, alt = formulae[['var.alt.formula']], null = formulae[['var.null.formula']])
#
#   fit_model <- switch(EXPR = model,
#                       dglm = fit_dglm,
#                       hglm = fit_hglm,
#                       dhglm = fit_dhglm)
#
#   glm_family <- switch(EXPR = glm_family,
#                        gaussian = stats::gaussian,
#                        poisson = stats::poisson)
#
#   data <- switch(EXPR = permute_what,
#                  none = data,
#                  mean = permute.mean.QTL.terms_(df = data, the.perm = the.perm),
#                  var = permute.var.QTL.terms_(df = data, the.perm = the.perm),
#                  both = permute.QTL.terms_(df = data, the.perm = the.perm))
#
#   tryNA(fit_model(mf = mf, df =  vf, data = data, glm_family = glm_family))#, obs_weights = obs_weights)
#   # tryNA(do.call(what = fit_model,
#   # args = list(mf = mf, df =  vf, data = data, glm_family = glm_family, weights = obs_weights)))
# }



log_lik <- function(f) {

  if (inherits(x = f, what = 'dglm')) {
    if (abs(f$m2loglik) > 1e8) { return(NA) }
    return(-0.5*f$m2loglik)
  }
  if (inherits(x = f, what = 'hglm')) {
    stop('no hglm for now.')
    # if (abs(f$likelihood$hlik) > 1e8) { return(NA) }
    # return(f$likelihood$hlik)
  }
  return(stats::logLik(object = f))
}

LRT <- function(alt, null) {

  if (any(identical(alt, NA), identical(null, NA))) {
    return(NA)
  }

  if (!identical(class(alt), class(null))) {
    stop('Can only calculate LOD on models of the same class.')
  }

  if (!inherits(x = alt, what = c('dglm', 'hglm'))) {
    stop('Can only calcualte LOD on models of class dglm or hglm.')
  }

  LRT <- 2*(log_lik(alt) - log_lik(null))

}

LOD <- function(alt, null) {
  return(0.5*LRT(alt = alt, null = null)/log(10))
}

LOD_from_LLs <- function(null_ll, alt_ll) {
  return((alt_ll - null_ll)/log(10))
}

LRT_from_LLs <- function(null_ll, alt_ll) {
  return(2*(alt_ll - null_ll))
}


dof <- function(f) {
  if (inherits(x = f, what = 'dglm')) {
    length(stats::coef(f)) + length(stats::coef(f$dispersion.fit)) - 2L
  }
}

pull_allele_names <- function(apr) {
  dimnames(x = apr)[[2]]
}

pull_marker_names <- function(apr) {
  dimnames(x = apr)[[3]]
}

make_formula <- function(response_name = NULL,
                         covar_names = '1') {

  stats::as.formula(
    paste(response_name,
          '~',
          paste(
            covar_names,
            collapse = '+'
          )
    )
  )

}

prepend_class <- function(x, new_class) {
  class(x = x) <- c(new_class, class(x = x))
  return(x)
}


conditionally <- function(fun){
  function(first_arg, ..., execute){
    if(execute) return(fun(first_arg, ...))
    else return(first_arg)
  }
}

# cond_filter <- conditionally(filter)
# cond_select <- conditionally(select)
cond_mutate <- conditionally(dplyr::mutate)

pull_effects <- function(model, effect_name_prefix = NULL) {

  term <- estimate <- std.error <- 'fake global for CRAN'
  measure <- val <- united <- 'fake global for CRAN'

  model %>%
    broom::tidy() %>%
    dplyr::mutate(term = dplyr::case_when(term == '(Intercept)' ~ 'intercept',
                                          TRUE ~ term)) %>%
    cond_mutate(term = paste0(effect_name_prefix, '_', term),
                execute = !is.null(effect_name_prefix)) %>%
    dplyr::select(term, estimate, std.error) %>%
    tidyr::gather(key = measure, value = val, estimate, std.error) %>%
    dplyr::mutate(measure = dplyr::case_when(measure == 'estimate' ~ 'estim',
                                             measure == 'std.error' ~ 'se')) %>%
    tidyr::unite(col = 'united', term, measure) %>%
    tidyr::spread(key = united, value = val)
}

#
# broom::tidy(x = null_fit) %>%
#   dplyr::mutate(term = ifelse(test = term == '(Intercept)',
#                               yes = 'intercept',
#                               no = term)) %>%
#   if (TRUE) dplyr::mutate(a = 3) %>%
#   dplyr::select(term, estimate, std.error) %>%
#   tidyr::gather(key = measure, value = val, estimate, std.error) %>%
#   tidyr::unite(col = 'united', term, measure) %>%
#   tidyr::spread(key = united, value = val)
#
