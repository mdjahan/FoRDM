# FoRDM

Description...

## Table of contents
1. [Introduction](#introduction)  
2. [Structure](#structure)  
3. [Functions](#functions)  
   - [build_fordm_table](#build_fordm_table)  
   - [build_objectives](#build_objectives)  
   - [discount_fun](#discount_fun)  
   - [fordm_analysis_regret](#fordm_analysis_regret)  
   - [fordm_analysis_qperform](#fordm_analysis_qperform)  
   - [visualize_fordm_2d](#visualize_fordm_2d)  
   - [visualize_fordm_3d](#visualize_fordm_3d)  
   - [robustness_frontier_explorer](#robustness_frontier_explorer)  
   - [visualize_rfe](#visualize_rfe)  
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

### build_fordm_table
Description  
Transfers a provided data.frame into the FoRDM input format. Identifies management, SOW (state-of-world) and time columns; all other columns are treated as objectives.

Inputs
- data: data.frame containing the input data.
- management: name (string) of the management column.
- sow: name (string) of the SOW (state-of-world) column.
- time: name (string) of the time column.

Output
- A list with:
  - data: the original data.frame,
  - mapping: list(management, sow, time),
  - objectives: character vector of objective column names.

### build_objectives
Description  
Constructs an objectives data.frame specifying objective names, optimization direction, weights, time-aggregation method and discount rates for each objective.

Inputs
- obj_names: character vector of objective column names.
- obj_dirs: character vector of "maximize" / "minimize" (default: all "maximize").
- obj_weights: numeric vector of relative weights (must sum to 1).
- obj_timeagg: character vector for time aggregation per objective ("mean" or "sum").
- obj_dr: numeric vector of discount rates per objective.

Output
- A data.frame with columns: obj_names, obj_dirs, obj_weights, obj_timeagg, obj_dr.

### discount_fun
Description  
Internal helper to aggregate values across time with optional discounting. Supports "sum" or "mean" aggregation with a discount rate.

Inputs
- x: numeric vector of values across time for a single objective.
- t: numeric vector of time indices corresponding to x.
- disc_type: "sum" or "mean".
- d: discount rate (numeric, e.g., 0.02).

Output
- Single numeric aggregated value (discounted sum or discounted mean).

### fordm_analysis_regret
Description  
Performs regret-based (Regret Type 2) multi-objective robustness analysis. Aggregates across time (with discounting), computes global ideals/worsts, calculates per-SOW and per-management regrets, forms weighted scalar regrets and selects robust representative SOWs per management. Produces Pareto front (real and normalized) and identifies the optimal robust management.

Inputs
- fordm_table: output from build_fordm_table().
- objectives: output from build_objectives().
- quantile: numeric 0-1 robustness threshold (e.g., 0.05).
- sow_selection: "representative" (default) or "mean" — how to choose SOW per management.

Output
- A list with:
  - optimal: row for the selected optimal management (renamed column "management"),
  - pareto_front_real: data.frame of Pareto front with real objective values,
  - pareto_front_normalized: data.frame of Pareto front with objectives normalized to global ideal/worst.

### fordm_analysis_qperform
Description  
Performs quantile-performance robustness analysis. Aggregates across time (with discounting), computes per-management quantile values for each objective, normalizes them and computes weighted scores to identify optimal management. Returns Pareto front in real (quantiles) and normalized forms.

Inputs
- fordm_table: output from build_fordm_table().
- objectives: output from build_objectives().
- quantile: single numeric or named vector of quantiles (0-1) per objective.

Output
- A list with:
  - optimal: row for the selected optimal management (renamed column "management"),
  - pareto_front_real: data.frame of Pareto front with quantile values (columns named as objectives),
  - pareto_front_normalized: data.frame of Pareto front with normalized quantile values.

### visualize_fordm_2d
Description  
Create a 2D ggplot2 scatter plot of the Pareto front for two selected objectives. Supports plotting real or normalized values.

Inputs
- analysis_output: result from fordm_analysis_regret() or fordm_analysis_qperform().
- x: objective name for x-axis (string).
- y: objective name for y-axis (string).
- values: "real" (default) or "normalized".

Output
- A ggplot2 object (plot) showing the 2D Pareto front with management labels.

### visualize_fordm_3d
Description  
Create a 3D interactive Pareto front plot using plotly for three selected objectives. Supports plotting real or normalized values.

Inputs
- analysis_output: result from fordm_analysis_regret() or fordm_analysis_qperform().
- x, y, z: objective names for the three axes (strings).
- values: "real" (default) or "normalized".

Output
- A plotly object (interactive 3D scatter) showing the Pareto front.

### robustness_frontier_explorer
Description  
Explores the robustness frontier across a range of robustness (quantile) levels. Works with both regret-based and quantile-performance methods. Tracks which management is best at each robustness level, computes marginal benefits and losses when management changes, and returns a table of frontier results.

Inputs
- fordm_table: output from build_fordm_table().
- objectives: output from build_objectives().
- quantile_range: numeric vector length 2 with min and max robustness quantile (e.g., c(0, 0.5)).
- sow_selection: "representative" or "mean".
- method: "regret" (default) or "qperform".

Output
- data.frame with one row per robustness level (for the selected best management), including:
  - management, robustness_level,
  - objective columns (real or quantile-based as appropriate),
  - marginal benefit and marginal loss columns for each objective (named <obj>_benefit and <obj>_loss).

### visualize_rfe
Description  
Visualizes robustness frontier explorer output. Plots objective trajectories across robustness levels, annotates management labels and shows marginal benefits/losses when management changes.

Inputs
- rfe_output: data.frame returned by robustness_frontier_explorer().

Output
- A ggplot2 object visualizing the robustness frontier with annotations for benefits (→) and losses (←).

## Example
...

## Citation
Djahangard & Yousefpour 2025

## Funding
This work was funded by the EU HORIZON project "eco2adapt"...  
We also thank the EU ... project "DecisionES" for support...

## References
...
