context('Testing scan1var in DO')

library(qtl2)
library(vqtl2)


testthat::test_that(
  desc = 'DO experiment',
  code = {
    
    gatti_file <- 'https://raw.githubusercontent.com/rqtl/qtl2data/master/DO_Gatti2014/do.zip'

    gatti_cross <- read_cross2(file = gatti_file)

    small_do_cross <- subset(x = gatti_cross, ind = 1:100, chr = 1:5)

    map <- insert_pseudomarkers(small_do_cross$gmap, step = 10)

    pr <- calc_genoprob(cross = small_do_cross, map = map, quiet = FALSE)

    apr <- genoprob_to_alleleprob(probs = pr, quiet = FALSE)

    s1v <- scan1var(pheno_name = 'WBC',
                    mean_covar_names = 'NEUT',
                    var_covar_names = 'NEUT',
                    alleleprobs = apr,
                    non_genetic_data = as.data.frame(x = small_do_cross$pheno))

    expect_true(object = is_scan1var(x = s1v))
    
    expect_equal(object = nrow(x = s1v),
                 expected = sum(sapply(X = map, FUN = length)) + 1)
  }
)

