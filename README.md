<p align="right">
  <img src="logo.png" alt="FoRDM logo" width="200" />
</p>

# FoRDM
**Fo**rest research related multi-objective **R**obust **D**ecision **M**aking (**FoRDM**) ... package provides tools for multi-objective robustness analysis, including regret-based and quantile-performance methods. It also includes visualization tools for exploring Pareto fronts and robustness frontiers.
Current release is R-package... also a simplified, user-friendly version as shiny app...

## Table of contents
1. [Introduction](#introduction)  
2. [Structure](#structure)
3. [Input file](#input-file)  
4. [Functions](#functions)  
   - [build_fordm_table](#build_fordm_table)  
   - [build_objectives](#build_objectives)
   - [fordm_analysis_regret](#fordm_analysis_regret)  
   - [fordm_analysis_qperform](#fordm_analysis_qperform)  
   - [visualize_fordm_2d](#visualize_fordm_2d)  
   - [visualize_fordm_3d](#visualize_fordm_3d)  
   - [robustness_frontier_explorer](#robustness_frontier_explorer)  
   - [visualize_rfe](#visualize_rfe)  
5. [Example](#example)  
6. [Citation](#citation)  
7. [Funding](#funding)  
8. [References](#references)

---

## Introduction
...

## Structure
Main implementation is R-package.... That file provides helpers to build input tables and objectives, run robustness analyses (regret and quantile-performance) and visualize results (2D/3D Pareto front) as well as robustness frontier exploration.

## Input file
The input file (.csv-file)... forest simulation model output ... values of e.g., ecosystem services...  needs to be ... containing the columns...
Column file example:
| management | sow | time | value1 | value2 | ... |
|------------|-----|------|--------|--------|-----|

## Functions

### **build_fordm_table()**
Transforms a given `data.frame` into the required FoRDM input format. Identifies columns for management, SOW (state-of-world), and time, treating all other columns as objectives.

**Inputs**
- `data`: `data.frame` containing the input data.  
- `management`: name of the management column in the input data.  
- `sow`: name of the SOW (state-of-world) column in the input data.  
- `time`: name of the time column in the input data.

**Output**
- A list containing:  
  - `data`: the original `data.frame`,  
  - `mapping`: a list with `management`, `sow`, and `time` column names,  
  - `objectives`: a character vector of objective column names.

---

### **build_objectives()**
Creates an objectives `data.frame` to define the names, optimization directions, weights, time-aggregation methods, and discount rates for each objective to be included in the FoRDM analysis.

**Inputs**
- `obj_names`: character vector of objective column names.  
- `obj_dirs`: character vector specifying "maximize" or "minimize" for each objective (default: "maximize").  
- `obj_weights`: numeric vector of relative weights (must sum to 1).  
- `obj_timeagg`: character vector specifying time aggregation methods ("mean" or "sum").  
- `obj_dr`: numeric vector representing discount rates for each objective (e.g., 0.02 indicates a 2% rate) applied during time aggregation.

**Output**
- A `data.frame` with columns: `obj_names`, `obj_dirs`, `obj_weights`, `obj_timeagg`, `obj_dr`.

---

### **fordm_analysis_regret()**
Conducts a regret-based (Regret Type 2) multi-objective robustness analysis. Aggregates objectives across time (with discounting), computes regrets for each SOW and management and selects robust representative SOWs. Produces Pareto fronts (real and normalized) and identifies the optimal robust management.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives()`.  
- `quantile`: numeric value (0-1) specifying the robustness threshold (e.g., 0.05 indicates a robustness level of 95%).  
- `sow_selection`: "representative" (default) or "mean" — determines how robustness across SOWs are calculated per management. "representative": Selects the SOW closest to the user-defined quantile as a representative. "mean": Uses the mean across all SOWs below the quantile.

**Output**
- A list containing:  
  - `optimal`: row for the optimal management (renamed column "management"),  
  - `pareto_front_real`: `data.frame` of the Pareto front with real objective values,  
  - `pareto_front_normalized`: `data.frame` of the Pareto front with normalized objective values.

---

### **fordm_analysis_qperform()**
Performs a quantile-performance robustness analysis. Aggregates objectives across time (with discounting), calculates per-management quantile values for each objective, normalizes them, and computes weighted scores to identify the optimal management. Returns Pareto fronts in both real (quantile-based) and normalized forms.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives()`.  
- `quantile`: single numeric value or named vector of quantiles (0-1) for each objective.

**Output**
- A list containing:  
  - `optimal`: the optimal management strategy at the specified robustness level, including real objective values,
  - `pareto_front_real`: the Pareto front of management strategies with real objective values at the specified robustness level,
  - `pareto_front_normalized`: the Pareto front of management strategies with normalized objective values at the specified robustness level.

---

### **visualize_fordm_2d()**
Generates a 2D scatter plot of the Pareto front for two selected objectives using `ggplot2`. Supports plotting real or normalized values.

**Inputs**
- `analysis_output`: result from `fordm_analysis_regret()` or `fordm_analysis_qperform()`.  
- `x`: name of the objective for the x-axis (string).  
- `y`: name of the objective for the y-axis (string).  
- `values`: "real" (default) or "normalized".

**Output**
- A `ggplot2` object visualizing the 2D Pareto front with management labels.

---

### **visualize_fordm_3d()**
Creates an interactive 3D Pareto front plot using `plotly` for three selected objectives. Supports plotting real or normalized values.

**Inputs**
- `analysis_output`: result from `fordm_analysis_regret()` or `fordm_analysis_qperform()`.  
- `x`, `y`, `z`: names of the objectives for the three axes (strings).  
- `values`: "real" (default) or "normalized".

**Output**
- A `plotly` object (interactive 3D scatter plot) visualizing the Pareto front.

---

### **robustness_frontier_explorer()**
Analyzes the robustness frontier across a range of robustness (quantile) levels. Supports both regret-based and quantile-performance methods. Tracks the best management at each robustness level, computes marginal benefits and losses when management changes, and returns a table of frontier results.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives()`.  
- `quantile_range`: numeric vector of length 2 specifying the minimum and maximum robustness quantiles (e.g., `c(0, 0.5)`).  
- `sow_selection`: "representative" or "mean".  
- `method`: "regret" (default) or "qperform".

**Output**
- A `data.frame` with one row per robustness level (for the selected best management), including:  
  - `management`, `robustness_level`,  
  - objective columns (real or quantile-based as appropriate),  
  - marginal benefit and marginal loss columns for each objective (e.g., `<obj>_benefit` and `<obj>_loss`).

---

### **visualize_rfe()**
Visualizes the output of the robustness frontier explorer. Plots objective trajectories across robustness levels, annotates management labels, and highlights marginal benefits (→) and losses (←) when management changes.

**Inputs**
- `rfe_output`: `data.frame` returned by `robustness_frontier_explorer()`.

**Output**
- A `ggplot2` object visualizing the robustness frontier with annotations for benefits and losses.

## Example

```r
# Load package
library(FoRDM)

# Load your data (replace with your path)
df <- read.csv("YOUR_DATA.csv")

# Build FoRDM table (columns in your data must match)
FoRDM_table <- build_fordm_table(df, management = "management", sow = "scenario", time = "year")

# Define objectives
objectives <- build_objectives(
  obj_names   = c("standing_biomass", "biodiversity", "harvest_revenue"), #identical with the column names in your input data
  obj_dirs    = c("maximize", "maximize", "maximize"),
  obj_weights = c(0.2, 0.2, 0.6),
  obj_timeagg = c("mean", "mean", "sum"),
  obj_dr      = c(0, 0, 0.02)
)

# Run regret-based FoRDM analysis (quantile performance analysis follows the same procedure)
output_regret <- fordm_analysis_regret(FoRDM_table, objectives, quantile = 0.01, sow_selection = "mean")

# Inspect optimal robust management
print(output_regret$optimal)
# Inspect pareto front
print(output_regret$pareto_front_real) #real values
print(output_regret$pareto_front_normalized) #normalized values

# Visualize FoRDM analysis output
visualize_fordm_2d(output_fordm_regret,x="biodiversity",y="harvest_revenue",values = "real")
visualize_fordm_3d(output_fordm_regret,x="biodiversity",y="standing_biomass",z="harvest_revenue",values = "real")

```

## Citation
Djahangard & Yousefpour 2025

## Funding
This work was funded by the EU HORIZON project "eco2adapt"...  
We also thank the EU ... project "DecisionES" for support...

## References
...
...existing code...
