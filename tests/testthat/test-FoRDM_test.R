test_that("FoRDM workflow & visualization runs without error", {
  #Example dataset (minimal)
  df <- data.frame(
    management = rep(c("M1","M2"), each = 12),
    scenario   = rep(rep(c("sow1","sow2","sow3"), each = 4), times = 2),
    year       = rep(seq(2020,2050,by=10), times = 6),
    objective1 = c(1679, 1824, 1945, 1055, 1679, 1794, 2449, 1497, 1679, 1515, 1816, 1155, 2429, 2431, 2323, 1495, 2429, 2495, 2398, 1838, 2429, 2071, 2167, 1187),
    objective2 = c(31, 41, 47, 50, 31, 41, 46, 50, 30, 41, 47, 49, 33, 45, 47, 49, 33, 44, 48, 49, 33, 44, 48, 50),
    objective3   = c(29, 35, 43, 44, 29, 34, 38, 43, 28, 35, 41, 45, 34, 43, 46, 47, 34, 44, 47, 48, 35, 43, 47, 45),
    stringsAsFactors = FALSE
  )
  
  expect_no_error({
    fordm_table <- build_fordm_table(
      df,
      management = "management",
      sow        = "scenario",
      time       = "year"
    )
    
    objectives_regret <- build_objectives_regret(
      names = c("objective1","objective2","objective3"),
      direction = c("maximize","maximize","maximize"),
      weights = c(0.5,0.25,0.25),
      time_aggregation = c("sum","mean","mean"),
      discount_rate = c(0.02,0,0)
    )
    
    out_regret <- fordm_analysis_regret(
      fordm_table = fordm_table,
      objectives  = objectives_regret,
      robustness  = 0.9
    )
  })
  
  expect_true(is.list(out_regret))
  expect_true(all(c("optimal","pareto_front") %in% names(out_regret)))
  expect_s3_class(out_regret$optimal, "data.frame")
  expect_s3_class(out_regret$pareto_front, "data.frame")
  
  #Satisficing approach
  objectives_satisficing <- build_objectives_satisficing(
    names = c("objective1","objective2","objective3"),
    time_aggregation = c("sum","mean","mean"),
    discount_rate = c(0.02,0,0),
    threshold = c(4000,40,40),
    direction = c("above","above","above")
  )
  
  out_satisficing <- fordm_analysis_satisficing(
    fordm_table = fordm_table,
    objectives  = objectives_satisficing,
    robustness  = 0.8
  )
  
  expect_true(is.list(out_satisficing))
  expect_true(all(c("optimal","pareto_front") %in% names(out_satisficing)))
  expect_s3_class(out_satisficing$optimal, "data.frame")
  expect_s3_class(out_satisficing$pareto_front, "data.frame")
  
  #Robustness Trade-Off Analysis
  out_rta <- robustness_tradeoff_analysis(
    fordm_table = fordm_table,
    objectives  = objectives_regret
  )
  expect_true(all(c("summary","plot") %in% names(out_rta)))
  
  #Visualization (skipping on CI/headless)
  skip_on_ci()
  skip_if_not_installed("ggplot2")
  expect_no_error(visualize_fordm_2d(out_regret, x = "objective1", y = "objective2", fordm_method = "regret"))
  expect_no_error(visualize_fordm_3d(out_regret, x = "objective1", y = "objective2", z = "objective3", fordm_method = "regret"))
  expect_no_error(visualize_fordm_parcoord(out_regret, fordm_method = "regret"))
  expect_no_error(visualize_fordm_parcoord_management(fordm_table, objectives_regret, fordm_method = "regret", management = "M2"))
})
