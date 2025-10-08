# FoRDM

Description...

## Table of contents
1. [Introduction](#introduction)  
2. [Structure](#structure)  
3. [Functions](#functions)  
4. [Example](#example)  
5. [Citation](#citation)  
6. [Funding](#funding)  
7. [References](#references)

---

## Introduction
...

## Structure
Main implementation is R-package.... That file provides helpers to build input tables and objectives, run robustness analyses (regret and quantile-performance) and visualize results (2D/3D Pareto front) as well as robustness frontier exploration.

## Functions
Main exported / useful functions (from RPackage/R/FoRDM.R). Descriptions and inputs below are provisional — use the in-file documentation for full details.

- FoRDM::build_fordm_table  
  - Description: Build FoRDM input table (formats a data.frame into the structure expected by analyses).  
  - Inputs: data, management (column name), sow (state-of-world column name), time (time column name).  
  - Returns: formatted list/data structure with data, mapping and objective names.

- FoRDM::build_objectives  
  - Description: Create objectives table (names, direction, weights, time aggregation, discounting).  
  - Inputs: obj_names, obj_dirs, obj_weights, obj_timeagg, obj_dr.  
  - Returns: data.frame of objectives.

- FoRDM::discount_fun  
  - Description: Helper to aggregate across time with optional discounting.  
  - Inputs: x (values), t (time), disc_type ("sum" or "mean"), d (discount rate).

- FoRDM::fordm_analysis_regret  
  - Description: Regret-based robustness analysis (Regret Type 2 multi-objective).  
  - Inputs: fordm_table (from build_fordm_table), objectives (from build_objectives), quantile (robustness quantile), sow_selection ("representative" or "mean").  
  - Returns: list with optimal management, pareto_front_real, pareto_front_normalized.

- FoRDM::fordm_analysis_qperform  
  - Description: Quantile-performance robustness analysis (quantile-based per-objective).  
  - Inputs: fordm_table, objectives, quantile (single or vector per objective).  
  - Returns: list with optimal management, pareto_front_real, pareto_front_normalized.

- FoRDM::visualize_fordm_2d  
  - Description: 2D Pareto front plot for two selected objectives.  
  - Inputs: analysis_output, x, y (objective names), values ("real" or "normalized").

- FoRDM::visualize_fordm_3d  
  - Description: 3D Pareto front plot (plotly).  
  - Inputs: analysis_output, x, y, z, values ("real" or "normalized").

- FoRDM::robustness_frontier_explorer  
  - Description: Explore robustness frontier across quantile range; compute marginal benefits/losses and management changes.  
  - Inputs: fordm_table, objectives, quantile_range, sow_selection, method ("regret" or "qperform").  
  - Returns: data.frame of frontier results.

- FoRDM::visualize_rfe  
  - Description: Visualization for robustness frontier explorer results.  
  - Inputs: rfe_output (output of robustness_frontier_explorer).

## Example
Minimal example to run in R (adapt paths / package name as needed):

```r
# create toy data
data <- data.frame(
  management = rep(c("m1","m2"), each = 6),
  sow = rep(c("s1","s2","s3"), times = 4),
  time = rep(1:3, times = 4),
  obj1 = runif(12, 0, 100),
  obj2 = runif(12, 0, 100)
)

# prepare inputs
fordm_tbl <- FoRDM::build_fordm_table(data, management = "management", sow = "sow", time = "time")
objectives <- FoRDM::build_objectives(obj_names = c("obj1","obj2"))

# run regret analysis
res_regret <- FoRDM::fordm_analysis_regret(fordm_tbl, objectives, quantile = 0.05)

# inspect result
print(res_regret$optimal)
```

## Citation
Provide suggested citation for the package or related publication here.

## Funding
List funding sources and acknowledgements here.

## References
Add bibliographic references relevant to FoRDM and robustness analysis here.
