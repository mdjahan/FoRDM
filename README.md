# FoRDM

**Fo**rest Many-Objective **R**obust **D**ecision **M**aking (**FoRDM**) is an R-based toolkit for supporting robust forest management under deep uncertainty. **FoRDM** provides a forestry-focused, user-friendly application of MORDM to forest simulation outputs. It supports regret- and satisficing-based robustness, objective weighting, time aggregation, and robustness preferences. **FoRDM** identifies robust solutions, generates Pareto fronts, and offers interactive 2D, 3D, and parallel-coordinate visualizations. An analytical module highlights trade-offs between robustness and performance.

## Table of Contents
1. [Introduction](#introduction)  
2. [Structure](#structure)
3. [Input file](#input-file)  
4. [Functions](#functions)  
   - [build_fordm_table](#build_fordm_table)
   - [build_objectives_regret](#build_objectives_regret)
   - [build_objectives_satisficing](#build_objectives_satisficing)
   - [fordm_analysis_regret](#fordm_analysis_regret)
   - [fordm_analysis_satisficing](#fordm_analysis_satisficing)
   - [visualize_fordm_2d](#visualize_fordm_2d)
   - [visualize_fordm_3d](#visualize_fordm_3d)
   - [visualize_fordm_parcoord](#visualize_fordm_parcoord)
   - [visualize_fordm_parcoord_management](#visualize_fordm_parcoord_management)
   - [robustness_tradeoff_analysis](#robustness_tradeoff_analysis)
5. [Example](#example)  
6. [Citation](#citation)  
7. [Funding](#funding)
8. [Acknowledgment](#acknowledgment)
9. [References](#references)

---

## Introduction
Forests worldwide are increasingly affected by climate change (Hartmann et al., 2022; Forzieri et al., 2021; Patacca et al., 2023), with rising risks of mortality and natural disturbances posing major threats to ecosystem services (Hartmann et al., 2025; McDowell et al., 2020; Seidl et al., 2017). Therefore, it is essential to identify management strategies that safeguard key services. However, selecting effective strategies is challenging due to ecosystem complexity, the unprecedented and rapid climate change (Armstrong McKay et al., 2022), and deep uncertainty in ecological and socioeconomic conditions (Keenan, 2015; Yousefpour & Hanewinkel, 2016).

Decision support under such uncertainty requires tools that can explore plausible forest futures. Climate change represents deep uncertainty, where outcomes and probabilities are unknown, requiring evaluation across a broad range of plausible futures (Radke et al., 2017; Lempert et al., 2003). Robust Decision Making (RDM) addresses this challenge by identifying strategies that perform satisfactorily across many futures, focusing on downside risk rather than optimizing for a single scenario (Lempert et al., 2003; Kasprzyk et al., 2013; Radke et al., 2017). Robustness is commonly assessed using regret-based measures, which minimize how much worse an option performs compared to the best alternative, or satisficing-based measures, which evaluate whether minimum performance thresholds are met (Hadka et al., 2015; Radke et al., 2017). For complex, multi-objective forest management, RDM can be extended to Many-Objective RDM (MORDM), combining evolutionary optimization, Pareto-front generation, and interactive visualization (Kasprzyk et al., 2013). 

Yet, MORDM has seen limited adoption in forestry because existing tools are often complex and not tailored to forest simulation data, limiting accessibility for many users. FoRDM addresses this gap by providing an easy-to-use, forestry-focused toolkit that allows a wide range of users to evaluate robust management strategies, explore trade-offs, and visualize outcomes interactively across large simulation datasets.

## Structure
Main implementation is an R package. This package provides helpers to build input tables and objectives, run robustness analyses (regret-based and satisficing-based), and visualize results (2D, 3D & Parallel Coordinate Pareto fronts) as well as a robustness trade-off analysis.

## Input file
The input file (.csv) should contain pre-processed outputs from a forest simulation model. These data need to be structured so that each row represents a combination of management alternative, state of the world (SOW), time step, and one or more objective values. States of the world can reflect any sources of uncertainty specified by the user—such as climate projections, socioeconomic pathways, or model parameter variability—while management alternatives represent the different strategies evaluated in the simulation. Objective columns capture performance indicators of interest, for example ecosystem services, economic returns, or other measures used to compare strategies. The user is responsible for preparing these inputs in advance, including defining the set of management options, specifying uncertainties, and calculating the objective outcomes that will be used for the robustness analysis.

Example column structure:
| management | sow | time | objective1 | objective2 | ... |
|------------|-----|------|------------|------------|-----|

## Functions

### **build_fordm_table()**
Transforms a given input file (`data.frame`) into the required FoRDM input format. Identifies columns for management, SOW (state-of-world), and time, treating all other columns as objectives. Also needs definition of the time unit.

**Inputs**
- `data`: `data.frame` containing the input data.  
- `management`: name of the management column in the input data.  
- `sow`: name of the SOW (state-of-world) column in the input data.  
- `time`: name of the time column in the input data.
- `time_unit`: unit of time used in the time column. Options are "years" (default) or "decades". 

**Output**
- A list containing the formatted table for analysis, including the input data, mapping for identification of columns, and objective columns.

---

### **build_objectives_regret()**
Creates an objectives `data.frame` for regret-based analysis, defining names, optimization directions, weights, time aggregation methods, and discount rates for each objective.

**Inputs**
- `names`: character vector of objective column names.  
- `direction`: character vector specifying "maximize" or "minimize" for each objective.  
- `weights`: numeric vector of relative weights (must sum to 1).  
- `time_aggregation`: character vector specifying time aggregation methods ("mean", "sum", "max", "min").  
- `discount_rate`: numeric vector representing discount rates for each objective (e.g., 0.02 for 2%).

**Output**
- A `data.frame` with columns: `names`, `direction`, `weights`, `time_aggregation`, `discount_rate`.

---

### **build_objectives_satisficing()**
Creates an objectives `data.frame` for satisficing-based analysis, defining names, time aggregation, discount rates, thresholds, and directions for each objective.

**Inputs**
- `names`: character vector of objective column names.  
- `time_aggregation`: character vector specifying time aggregation methods ("mean", "sum", "max", "min").  
- `discount_rate`: numeric vector representing discount rates (e.g., 0.02 for 2%).  
- `threshold`: numeric vector of thresholds for each objective.  
- `direction`: character vector specifying "above" or "below" for each objective.

**Output**
- A `data.frame` with columns: `names`, `time_aggregation`, `discount_rate`, `threshold`, `direction`.

---

### **fordm_analysis_regret()**
Conducts a regret-based robustness analysis. Aggregates objectives across time (with discounting), computes regrets for each SOW and management, and selects robust representative SOWs. Produces Pareto fronts and identifies the optimal robust management.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives_regret()`.  
- `robustness`: numeric value (0-1) specifying the robustness level (e.g., 0.9 for 90%).  

**Output**
- A list containing:
  - `optimal`: The management strategy identified as most robust.
  - `pareto_front`: The Pareto front of robust management strategies.
  - `method`: The method used.
  - `robustness`: The robustness level used.

---

### **fordm_analysis_satisficing()**
Performs a satisficing-based robustness analysis. Aggregates objectives and applies thresholds to find satisficing alternatives. Optimal robust management and Pareto front are computed via optimization on Euclidean distance. Returns optimal robust management and Pareto front.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives_satisficing()`.  
- `robustness`: numeric value (0-1) specifying the robustness level (e.g., 0.9 for 90%).

**Output**
- A list containing:
  - `optimal`: The management strategy that balances all objectives while meeting the robustness threshold.
  - `pareto_front`: The Pareto front of robust management strategies.

---

### **visualize_fordm_2d()**
Generates a 2D scatter plot of the Pareto front for two selected objectives using `ggplot2`. Supports regret and satisficing methods.

**Inputs**
- `analysis_output`: result from `fordm_analysis_regret()` or `fordm_analysis_satisficing()`.  
- `x`: name of the objective for the x-axis.  
- `y`: name of the objective for the y-axis.  
- `fordm_method`: "regret" or "satisficing".

**Output**
- A `ggplot2` plot visualizing the 2D Pareto front with management labels.

---

### **visualize_fordm_3d()**
Creates an interactive 3D Pareto front plot using `plotly` for three selected objectives. Supports regret and satisficing methods.

**Inputs**
- `analysis_output`: result from `fordm_analysis_regret()` or `fordm_analysis_satisficing()`.  
- `x`, `y`, `z`: names of the objectives for the three axes.  
- `fordm_method`: "regret" or "satisficing".

**Output**
- A `plotly` plot (interactive 3D scatter plot) visualizing the Pareto front.

---

### **visualize_fordm_parcoord()**
Creates a parallel coordinates plot of the Pareto front across all objectives using `plotly`. For regret-based analysis, shows objective values with uniform coloring. For satisficing-based analysis, includes robustness as an additional dimension with gradient color coding.

**Inputs**
- `analysis_output`: result from `fordm_analysis_regret()` or `fordm_analysis_satisficing()`.  
- `fordm_method`: "regret" or "satisficing".

**Output**
- A `plotly` parallel coordinates plot visualizing the Pareto front across all objectives. In satisficing mode, lines are colored by robustness percentage.

---

### **visualize_fordm_parcoord_management()**
Creates a parallel coordinates plot showing SOW (State-of-the-World) performance across objectives for a selected management strategy using `plotly`. For regret-based analysis, lines are colored by robustness percentile (0-100%). For satisficing-based analysis, lines are colored binary (red = not satisfied, green = all thresholds satisfied).

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives_regret()` or `build_objectives_satisficing()`.  
- `fordm_method`: "regret" or "satisficing".  
- `management`: character string specifying which management strategy to visualize.

**Output**
- A `plotly` parallel coordinates plot showing how the selected management performs across different SOWs, with each line representing one SOW scenario.

---

### **robustness_tradeoff_analysis()**
Explores trade-offs when relaxing robustness for better performance in regret-based FoRDM analysis. Sweeps robustness levels (0-100%), selects the optimal management at each level, tracks switches in optimal management, and summarizes marginal benefits/losses per objective.

**Inputs**
- `fordm_table`: output from `build_fordm_table()`.  
- `objectives`: output from `build_objectives_regret()`.  

**Output**
- A `list` with:
  - `summary`: list of data.frames. First entry gives the initial optimal management and its robustness range; subsequent entries correspond to switches and include `robustness_range`, `optimal_management`, and per-objective benefit/loss stats (`<prev_mgmt>_<objective>_benefit_min/mean/max`, `<prev_mgmt>_<objective>_loss_min/mean/max`).
  - `plot`: a ggplot2 scatter plot showing objective values for optimal managements across robustness levels (0-100%).

---

## Example

```r
library(FoRDM)

#Load your data
df <- read.csv("YOUR_DATA.csv")

#Define data frame structure for processing in FoRDM
fordm_table <- build_fordm_table(df, management="management", sow="scenario", time="decade", time_unit = "years")

#Regret based approach
#Define objectives
objectives_regret <- build_objectives_regret(
      names = c("objective1","objective2","objective3"),
      direction = c("maximize","maximize","maximize"),
      weights = c(0.5,0.25,0.25),
      time_aggregation = c("sum","mean","mean"),
      discount_rate = c(0.02,0,0))
#Run the regret robustness analysis
output_fordm_regret <- fordm_analysis_regret(fordm_table = fordm_table,
                                objectives = objectives_regret,
                                robustness = 0.9)
#output
output_fordm_regret$optimal
output_fordm_regret$pareto_front

#visualize regret output
visualize_fordm_2d(output_fordm_regret,x="objective1",y="objective2",fordm_method = "regret")
visualize_fordm_3d(output_fordm_regret,x="objective1",y="objective2",z="objective3",fordm_method = "regret")
visualize_fordm_parcoord(output_fordm_regret, fordm_method = "regret")
visualize_fordm_parcoord_management(fordm_table, objectives_regret, fordm_method = "regret",management="M2")

#Satisficing based approach
#Define objectives
objectives_satisficing <- build_objectives_satisficing(
    names = c("objective1","objective2","objective3"),
    time_aggregation = c("sum","mean","mean"),
    discount_rate = c(0.02,0,0),
    threshold = c(4000,40,40),
    direction = c("above","above","above"))
#Run the satisficing robustness analysis
output_fordm_satisficing <- fordm_analysis_satisficing(fordm_table = fordm_table,
                                             objectives = objectives_satisficing,
                                             robustness = 0.8)
#output
output_fordm_satisficing$optimal
output_fordm_satisficing$pareto_front

#visualize satisficing output
visualize_fordm_2d(output_fordm_satisficing,x="objective1",y="objective2",fordm_method = "satisficing")
visualize_fordm_3d(output_fordm_satisficing,x="objective1",y="objective2",z="objective3",fordm_method = "satisficing")
visualize_fordm_parcoord(output_fordm_satisficing, fordm_method = "satisficing")
visualize_fordm_parcoord_management(fordm_table, objectives_satisficing, fordm_method = "satisficing",management="M2")

#Robustness Trade-Off Analysis
output_rta <- robustness_tradeoff_analysis(fordm_table = fordm_table,
                                           objectives = objectives_regret)
#output
output_rta$summary
output_rta$plot
```

---

## Citation
Djahangard, M. and Yousefpour, R. (2025). FoRDM: Forest Many-Objective Robust Decision Making Toolkit. R package version 1.0.0. doi:10.5281/zenodo.17738074

## Funding
This work was funded by the HORIZON EUROPE's project "eco2adapt" (Ecosystem-based Adaptation and Changemaking to Shape, Protect, and Sustain the Resilience of Tomorrow's Forests, Grant no: 101059498).

## Acknowledgment
The authors thank the EU Horizon 2020 project "DecisionES" (Decision Support for the Supply of Ecosystem Services under Global Change, Grant no: 101007950) for supporting this work.

## References
Armstrong McKay, D. I., Staal, A., Abrams, J. F., Winkelmann, R., Sakschewski, B., Loriani, S., Fetzer, I., Cornell, S. E., Rockström, J., and Lenton, T. M.: Exceeding 1.5°C global warming could trigger multiple climate tipping points, Science, 377, eabn7950, https://doi.org/10.1126/science.abn7950, 2022.

Forzieri, G., Girardello, M., Ceccherini, G., Spinoni, J., Feyen, L., Hartmann, H., Beck, P. S. A., Camps-Valls, G., Chirici, G., Mauri, A., and Cescatti, A.: Emergent vulnerability to climate-driven disturbances in European forests, Nat Commun, 12, 1081, https://doi.org/10.1038/s41467-021-21399-7, 2021.

Hadka, D., Herman, J., Reed, P., and Keller, K.: An open source framework for many-objective robust decision making, Environmental Modelling & Software, 74, 114–129, https://doi.org/10.1016/j.envsoft.2015.07.014, 2015.

Hartmann, H., Bastos, A., Das, A. J., Esquivel-Muelbert, A., Hammond, W. M., Martínez-Vilalta, J., McDowell, N. G., Powers, J. S., Pugh, T. A. M., Ruthrof, K. X., and Allen, C. D.: Climate Change Risks to Global Forest Health: Emergence of Unexpected Events of Elevated Tree Mortality Worldwide, Annual Review of Plant Biology, 73, 673–702, https://doi.org/10.1146/annurev-arplant-102820-012804, 2022a.

Hartmann, H., Bastos, A., Das, A. J., Esquivel-Muelbert, A., Hammond, W. M., Martínez-Vilalta, J., McDowell, N. G., Powers, J. S., Pugh, T. A. M., Ruthrof, K. X., and Allen, C. D.: Climate Change Risks to Global Forest Health: Emergence of Unexpected Events of Elevated Tree Mortality Worldwide, Annual Review of Plant Biology, 73, 673–702, https://doi.org/10.1146/annurev-arplant-102820-012804, 2022b.

Kasprzyk, J. R., Nataraj, S., Reed, P. M., and Lempert, R. J.: Many objective robust decision making for complex environmental systems undergoing change, Environmental Modelling & Software, 42, 55–71, https://doi.org/10.1016/j.envsoft.2012.12.007, 2013.

Keenan, R. J.: Climate change impacts and adaptation in forest management: a review, Annals of Forest Science, 72, 145–167, https://doi.org/10.1007/s13595-014-0446-5, 2015.

Lempert, R. J., Popper, S. W., and Bankes, S. C.: Shaping the Next One Hundred Years: New Methods for Quantitative, Long-Term Policy Analysis, RAND Corporation, Erscheinungsort nicht ermittelbar, 1 pp., 2003.

McDowell, N. G., Allen, C. D., Anderson-Teixeira, K., Aukema, B. H., Bond-Lamberty, B., Chini, L., Clark, J. S., Dietze, M., Grossiord, C., Hanbury-Brown, A., Hurtt, G. C., Jackson, R. B., Johnson, D. J., Kueppers, L., Lichstein, J. W., Ogle, K., Poulter, B., Pugh, T. A. M., Seidl, R., Turner, M. G., Uriarte, M., Walker, A. P., and Xu, C.: Pervasive shifts in forest dynamics in a changing world, Science, 368, eaaz9463, https://doi.org/10.1126/science.aaz9463, 2020.

Patacca, M., Lindner, M., Lucas-Borja, M. E., Cordonnier, T., Fidej, G., Gardiner, B., Hauf, Y., Jasinevičius, G., Labonne, S., Linkevičius, E., Mahnken, M., Milanovic, S., Nabuurs, G.-J., Nagel, T. A., Nikinmaa, L., Panyatov, M., Bercak, R., Seidl, R., Ostrogović Sever, M. Z., Socha, J., Thom, D., Vuletic, D., Zudin, S., and Schelhaas, M.-J.: Significant increase in natural disturbance impacts on European forests since 1950, Global Change Biology, 29, 1359–1376, https://doi.org/10.1111/gcb.16531, 2023.

Radke, N., Yousefpour, R., von Detten, R., Reifenberg, S., and Hanewinkel, M.: Adopting robust decision-making to forest management under climate change, Annals of Forest Science, 74, 43, https://doi.org/10.1007/s13595-017-0641-2, 2017.

Seidl, R., Thom, D., Kautz, M., Martin-Benito, D., Peltoniemi, M., Vacchiano, G., Wild, J., Ascoli, D., Petr, M., Honkaniemi, J., Lexer, M. J., Trotsiuk, V., Mairota, P., Svoboda, M., Fabrika, M., Nagel, T. A., and Reyer, C. P. O.: Forest disturbances under climate change, Nature Clim Change, 7, 395–402, https://doi.org/10.1038/nclimate3303, 2017.

Yousefpour, R. and Hanewinkel, M.: Climate Change and Decision-Making Under Uncertainty, Curr Forestry Rep, 2, 143–149, https://doi.org/10.1007/s40725-016-0035-y, 2016.