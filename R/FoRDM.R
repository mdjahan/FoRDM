#' @importFrom magrittr %>%
#' @importFrom rlang .data sym :=
#' @importFrom dplyr group_by ungroup bind_rows mutate summarise across all_of cur_column cur_group_rows rowwise c_across starts_with slice_min slice_max filter arrange left_join select rename reframe lag first pick everything
#' @importFrom tibble as_tibble_row
#' @importFrom ggplot2 ggplot aes geom_point geom_text geom_vline geom_line labs theme_bw facet_wrap scale_fill_gradientn scale_color_gradientn scale_x_reverse geom_blank theme element_text
#' @importFrom tidyr pivot_longer
#' @importFrom stats quantile as.formula ecdf
#' @importFrom emoa nondominated_points
#' @importFrom utils globalVariables
NULL

#Suppress notes about global variables used in dplyr/ggplot2
utils::globalVariables(c(
  "regret_scalar", "regret_quantile", 
  "euclidean_distance", "management", "satisficing",
  "robustness_level", "value", "values", "all_satisfied",
  "robustness"
))

#' Build FoRDM Table
#'
#' Transfers the provided data table into the format for FoRDM analysis. The columns that represent management, sow (state-of-the-world, scenarios), and time have to be defined. All other columns are treated as objectives.
#' @param data A data.frame containing the input data.
#' @param management The name of the management column.
#' @param sow The name of the state-of-the-worlds (SOW) column.
#' @param time The name of the time column.
#' @param time_unit The unit of time used in the time column. Options are "years" (default) or "decades". 
#' 
#' @return A list with the processed data for further use in the FoRDM analysis, including the input data, mapping for identification of columns and objective columns.
#' 
#' @export
build_fordm_table <- function(data, management, sow, time, time_unit = "years") {
  stopifnot(management %in% names(data))
  stopifnot(sow %in% names(data))
  stopifnot(time %in% names(data))
  
  obj_cols <- setdiff(names(data), c(management, sow, time))
  if (length(obj_cols) == 0) stop("No objective columns found.")
  
  # Validate time_unit
  valid_units <- c("years", "decades")
  if (!time_unit %in% valid_units) {
    stop(sprintf("time_unit must be one of: %s", paste(valid_units, collapse = ", ")))
  }
  
  list(
    data = data,
    mapping = list(management = management, sow = sow, time = time),
    objectives = obj_cols,
    time_unit = time_unit
  )
}

#' Build Objectives Data Frame for Regret Analysis
#'
#' Specify for which objectives regret-based FoRDM analysis should be applied. For each objective, define its name, direction, weight, time aggregation method (mean, sum, min or max), and discount rate.
#'
#' @param names Names of objectives as the column names in the provided data.
#' @param direction Direction of objective function: 'maximize' or 'minimize'.
#' @param weights Relative weights (0-1) for each objective, must sum to 1.
#' @param time_aggregation Time aggregation across objectives: 'mean', 'sum', 'min' or 'max'.
#' @param discount_rate Annual discount rates for each objective (e.g., 0.02 means 2% per year), applied during time aggregation.
#' 
#' @return A data frame specifying objectives, directions, weights, time aggregation methods, and discount rates for use in FoRDM analysis.
#' 
#' @export
build_objectives_regret <- function(names,
                             direction = rep("maximize", length(names)),
                             weights = rep(1/length(names), length(names)),
                             time_aggregation = rep("mean", length(names)),
                             discount_rate = rep(0, length(names))) {
  stopifnot(length(names) == length(direction),
            length(names) == length(weights),
            length(names) == length(time_aggregation),
            length(names) == length(discount_rate))
  #check weighting equals 1
  sum_w <- sum(weights)
  tol <- 1e-2
  if (abs(sum_w - 1) > tol) {
    stop(sprintf("Error: weights must sum to 1. Provided sum = %g", sum_w))
  } else if (abs(sum_w - 1) > .Machine$double.eps^0.5) {
    remainder <- 1 - sum_w
    weights <- weights + remainder / length(weights)
    warning(sprintf("weights were adjusted by distributing remainder %g equally to sum to 1.", remainder))
  }
  #ouput data frame
  data.frame(
    names = names,
    direction = direction,
    weights = weights,
    time_aggregation = time_aggregation,
    discount_rate = discount_rate,
    stringsAsFactors = FALSE
  )
}

#Internal function for calculating time aggregation and discounting
time_aggregation_fun <- function(x, t, timeagg, d, time_unit = "years") {
  #Time from start
  time_start <- min(t, na.rm = TRUE)
  time_from_start <- t - time_start
  #Convert to years for discounting
  if (time_unit == "decades") { #e.g., 1,2,3 -> 10,20,30
    time_in_years <- time_from_start * 10
  } else { #years
    time_in_years <- time_from_start
  }
  
  if (timeagg == "sum") {
    sum(x / (1 + d)^time_in_years, na.rm = TRUE)
  } else if (timeagg == "mean") {
    w <- 1 / (1 + d)^time_in_years
    sum(x * w, na.rm = TRUE) / sum(w)
  } else if (timeagg == "max") {
    max(x, na.rm = TRUE)
  } else if (timeagg == "min") {
    min(x, na.rm = TRUE)
  } else {
    stop("Unknown aggregation type")
  }
}

#' FoRDM Regret-Based many-objective Robust Decision-Making Analysis
#'
#' Performs a regret-based (Type II or cVaR) many-objective robustness analysis for the provided data and objectives, providing a optimal robust management and the Pareto front.
#' 
#' @param fordm_table Output from build_fordm_table().
#' @param objectives Output from build_objectives_regret().
#' @param robustness Numeric (0-1) specifying the quantile of regret used to define robustness, e.g., 0.9 evaluates management performance that is at least as good as in 90% of SOWs.
#' @param method the method used to evaluate robustness
#' - `"regretII"`: Regret type II (regret to best performing alternative) approach using the robustness quantile of scenario regrets.  
#' - `"CVaR"`: Conditional Value at Risk, using the mean of the worst (1 - robustness) fraction of weighted regrets for risk-aware selection.
#' 
#' @return A list containing the results of the FoRDM analysis: 
#'   - `optimal`: The management strategy identified as most robust given the regret metrics.  
#'   - `pareto_front`: The Pareto front of robust management strategies.  
#'
#' 
#' @export
fordm_analysis_regret <- function(fordm_table, objectives, robustness = 0.9, method = "regretII") {
  data <- fordm_table$data
  mapping <- fordm_table$mapping
  management_col <- mapping$management
  sow_col <- mapping$sow
  time_col <- mapping$time
  obj_col <- objectives$names
  dir_col <- objectives$direction
  
  #1. Aggregate obejctive values across time
  df_aggregated <- dplyr::group_by(data, .data[[management_col]], .data[[sow_col]])
  df_aggregated <- dplyr::summarise(
    df_aggregated,
    dplyr::across(
      dplyr::all_of(obj_col),
      ~ {
        timeagg <- objectives$time_aggregation[obj_col == dplyr::cur_column()]
        disc_rate <- objectives$discount_rate[obj_col == dplyr::cur_column()]
        time_aggregation_fun(.x, data[[time_col]][dplyr::cur_group_rows()], timeagg, disc_rate, fordm_table$time_unit)
      }
    ),
    .groups = "drop"
  )

  #2. For each management, calculate regret as distance to global ideal for each objective
    for (i in seq_along(objectives$names)) {
      col <- objectives$names[i]
      dir <- objectives$direction[i]
      
      # Compute a global ideal 
      if (dir == "maximize") {
        global_ideal <- max(df_aggregated[[col]],na.rm = TRUE)
        regret <- (global_ideal - df_aggregated[[col]]) / pmax(abs(global_ideal), 1e-12)
      } else if (dir == "minimize") {
        global_ideal <- min(df_aggregated[[col]],na.rm = TRUE)
        regret <- (df_aggregated[[col]] - global_ideal) / pmax(abs(global_ideal), 1e-12)
      }
      
      regret <- pmax(regret, 0)  # optional: only count missed opportunity
      df_aggregated[[paste0("regret_", col)]] <- regret
    }

  #3. Calculate the weighted scalar of regrets per management and SOW
  df_scalar <- df_aggregated %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      regret_scalar = sum(dplyr::c_across(dplyr::starts_with("regret_")) * objectives$weights, na.rm = TRUE)
    ) %>%
    dplyr::ungroup()
  
  #4. Calculation of regret type II metrics or conditional value at risk (CVaR), using quantiles
  df_quantile <- df_scalar %>%
    dplyr::group_by(.data[[management_col]]) %>%
    dplyr::mutate(
      regret_quantile = quantile(regret_scalar, probs = robustness, na.rm = TRUE)
    ) %>%
    dplyr::ungroup()
  #Regret Type 2
  if(method == "regretII"){
    df_final <- df_quantile %>%
      dplyr::group_by(.data[[management_col]]) %>%
      dplyr::slice_min(abs(regret_scalar - regret_quantile), n = 1, with_ties = FALSE) %>%
      dplyr::ungroup() %>%
      dplyr::select(-c(all_of(sow_col),regret_quantile))
  } else if(method == "CVaR"){
    #CVaR
    df_final <- df_quantile %>%
      dplyr::group_by(.data[[management_col]]) %>%
      dplyr::filter(regret_scalar >= regret_quantile) %>%
      dplyr::summarise(
        dplyr::across(starts_with("regret_"), ~ mean(.x, na.rm = TRUE)),
        dplyr::across(all_of(obj_col), ~ mean(.x, na.rm = TRUE)),
        .groups = "drop"
      )%>%
      dplyr::select(-c(regret_quantile))
  } else stop("Unkown method")

  #5. Find optimal management (minimizing regret), including a tolerance to include near-optimal management
  tolerance <- 0.01 #1%
  min_regret <- min(df_final$regret_scalar, na.rm = TRUE)
  optimal <- df_final %>%
    dplyr::filter(regret_scalar <= min_regret * (1 + tolerance)) %>%
    dplyr::select(-c(regret_scalar))

  #6. Calculate Pareto front based on regret per objective
  indicator_columns <- grep('^regret_', names(df_final), value = TRUE)
  #Pareto front calculation
  regret_matrix <- t(as.matrix(df_final[, indicator_columns]))
  pareto_points <- emoa::nondominated_points(regret_matrix)
  #Output
  pareto_indices <- unlist(apply(pareto_points, 2, function(point) {
    which(apply(regret_matrix, 2, function(row) all(row == point)))
  }))
  pareto_front <- unique(df_final[pareto_indices, ])
  #final output with rounding
  optimal <- data.frame(lapply(optimal, function(x) if(is.numeric(x)) round(x, 3) else x))
  pareto_front <- data.frame(lapply(pareto_front, function(x) if(is.numeric(x)) round(x, 3) else x))
  list(
    optimal = as.data.frame(optimal),
    pareto_front = as.data.frame(pareto_front),
    method = method,
    robustness = robustness
  )
}

#' Build Objectives Data Frame for Satisficing Analysis
#'
#' Specify information for satisficing-based FoRDM analysis. For each objective, define its name, time aggregation method (mean, sum, min or max), discount rate, threshold and direction.
#'
#' @param names Names of objectives as the column names in the provided data.
#' @param time_aggregation Time aggregation across objectives: 'mean', 'sum', 'min' or 'max'.
#' @param discount_rate Discount rates for each objective (e.g., 0.02 means 2% per time step), applied during time aggregation.
#' @param threshold Numeric value(s) defining the satisficing level for each objective.
#' @param direction 'above' if values should meet or exceed the threshold, 'below' if they should be lower.
#' 
#' @return A data frame specifying objectives name, time aggregation method, discount rate, threshold and direction for use in satisficing FoRDM analysis.
#' 
#' @export
build_objectives_satisficing <- function(names,
                                         time_aggregation = rep("mean", length(names)),
                                         discount_rate = rep(0, length(names)),
                                         threshold,
                                         direction = rep("above",length(names)))
{
  stopifnot(length(names) == length(time_aggregation),
            length(names) == length(discount_rate),
            length(names) == length(threshold),
            length(names) == length(direction))
  #ouput data frame
  data.frame(
    names = names,
    time_aggregation = time_aggregation,
    discount_rate = discount_rate,
    threshold = threshold,
    direction = direction,
    stringsAsFactors = FALSE
  )
}


#' FoRDM Satisficing-Based many-objective Robust Decision-Making Analysis
#'
#' Performs a satisficing-based many-objective robustness analysis for the provided data and objectives, providing a optimal robust management and the Pareto front.
#' 
#' @param fordm_table Output from build_fordm_table().
#' @param objectives Output from build_objectives_satisficing().
#' @param robustness Numeric (0-1) specifying the robustness level across SOWs, e.g., 0.9 evaluates management performance that meets objectives in at least 90% of SOWs.
#' 
#' @return A list containing the FoRDM analysis results:  
#'   - `optimal`: The management strategy that balances all objectives (Euclidean distance) while meeting the robustness threshold.  
#'   - `pareto_front`: The Pareto front of robust management strategies.
#'  
#' @export
fordm_analysis_satisficing <- function(fordm_table, objectives, robustness = 0.9) {
  data <- fordm_table$data
  mapping <- fordm_table$mapping
  management_col <- mapping$management
  sow_col <- mapping$sow
  time_col <- mapping$time
  obj_col <- objectives$names
  
  #1. Aggregate objective values across time
  df_aggregated <- dplyr::group_by(data, .data[[management_col]], .data[[sow_col]])
  df_aggregated <- dplyr::summarise(
    df_aggregated,
    dplyr::across(
      dplyr::all_of(obj_col),
      ~ {
        timeagg <- objectives$time_aggregation[obj_col == dplyr::cur_column()]
        disc_rate <- objectives$discount_rate[obj_col == dplyr::cur_column()]
        time_aggregation_fun(.x, data[[time_col]][dplyr::cur_group_rows()], timeagg, disc_rate, fordm_table$time_unit)
      }
    ),
    .groups = "drop"
  )
  
  #2. Calculate Euclidean distance to global ideal point for each management-SOW combination (for later optimization)
  #Global ideal
  global_stats <- df_aggregated %>%
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(obj_col),
        list(min = ~min(.x, na.rm = TRUE), max = ~max(.x, na.rm = TRUE)),
        .names = "{.col}_{.fn}"
      )
    )
  df_aggregated <- df_aggregated %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(obj_col),
        ~ {
          obj_name <- dplyr::cur_column()
          dir <- objectives$direction[objectives$names == obj_name]
          min_val <- global_stats[[paste0(obj_name, "_min")]]
          max_val <- global_stats[[paste0(obj_name, "_max")]]
          
          #Normalize to [0,1] where 1 = ideal
          if (dir == "above") {
            #maximize
            (.x - min_val) / (max_val - min_val)
          } else {
            #minimize:
            (max_val - .x) / (max_val - min_val)
          }
        },
        .names = "norm_{.col}"
      )
    ) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      #Euclidean distance to ideal point (where all normalized values = 1)
      euclidean_distance = sqrt(sum((dplyr::c_across(dplyr::starts_with("norm_")) - 1)^2))
    ) %>%
    dplyr::ungroup()
  
  #3. Calculate satisficing threshold for each objective
  for (obj in obj_col) {
    thr <- objectives$threshold[obj_col == obj]
    dir <- tolower(objectives$direction[obj_col == obj])
    flag_col <- paste0("flag_", obj)
    if (dir == "above") {
      df_aggregated[[flag_col]] <- !is.na(df_aggregated[[obj]]) & (df_aggregated[[obj]] >= thr)
    } else if (dir == "below") {
      df_aggregated[[flag_col]] <- !is.na(df_aggregated[[obj]]) & (df_aggregated[[obj]] <= thr)
    } else {
      stop("Unknown direction: ", dir)
    }
  }
  #
  flag_cols <- paste0("flag_", objectives$names)
  df_satisficing <- df_aggregated %>%
    dplyr::group_by(.data[[management_col]]) %>%
    dplyr::reframe({
      #Calculate satisficing robustness
      satisficing_val <- mean(dplyr::if_all(dplyr::all_of(flag_cols), ~ .x))
      #Calculate the quantile value of Euclidean distance at robustness level
      quantile_distance <- quantile(euclidean_distance, probs = robustness, na.rm = TRUE)
      #Find the SOW closest to this quantile value (representative for the robustness level)
      closest_idx <- which.min(abs(euclidean_distance - quantile_distance))
      quantile_row <- dplyr::pick(dplyr::everything())[closest_idx, ]
      
      result <- tibble::tibble(
        satisficing = satisficing_val,
        euclidean_distance = quantile_row$euclidean_distance
      )
      for (obj in obj_col) {
        result[[obj]] <- quantile_row[[obj]]
      }
      result
    }) %>%
    dplyr::ungroup()
  
  #4. Filter managements that satisfice the robustness level either for all objectives or any objective
  df_satisficing <- df_satisficing[df_satisficing$satisficing >= robustness,]
  
  #5. Return Robust Satisficing Optimal and Pareto front
  if (nrow(df_satisficing) == 0) {
    warning("No management meets the specified robustness criteria.")
    return(NULL)
  }
  #optimal (based on Euclidean distance)
  optimal <- df_satisficing %>%
    dplyr::slice_min(euclidean_distance) %>%
    dplyr::select(management, satisficing, dplyr::all_of(obj_col))

  
  #Pareto Front including the robustness depending on direction
  cols <- c("satisficing", obj_col) #columns for optimization
  df_trans <- df_satisficing[, cols]
  #Transform to "minimize" for emoa
  for (col in cols) {
    if (col == "satisficing") {
      df_trans[[col]] <- -df_trans[[col]]
    } else {
      dir <- tolower(objectives$direction[objectives$names == col])
      if (dir == "above") df_trans[[col]] <- -df_trans[[col]]  #maximize -> minimize
      #"below" already minimizing
    }
  }
  #emoa calculation
  trans_matrix <- t(as.matrix(df_trans))
  pareto_points <- emoa::nondominated_points(trans_matrix)
  #Find indices of Pareto optimal solutions
  pareto_indices <- unlist(apply(pareto_points, 2, function(point) {
    which(apply(trans_matrix, 2, function(row) all(row == point)))
  }))
  #Pareto Front
  pareto_front <- unique(df_satisficing[pareto_indices, ])
  pareto_front <- pareto_front %>%
    dplyr::select(management, satisficing, dplyr::all_of(obj_col))

  #6. Output
  #Final output with rounding: 
  optimal <- data.frame(lapply(optimal, function(x) if(is.numeric(x)) round(x, 3) else x))
  pareto_front <- data.frame(lapply(pareto_front, function(x) if(is.numeric(x)) round(x, 3) else x))
  list(
    optimal = as.data.frame(optimal),
    pareto_front = as.data.frame(pareto_front),
    robustness = robustness
  )
}

#' Visualize 2D Pareto Front
#'
#' Plots a 2D plot of the Pareto front of management alternatives from FoRDM_analysis output.
#'
#' @param analysis_output Output list from FoRDM_analysis_regret() or FoRDM_analysis_satisficing().
#' @param x Name of the objective for the x-axis (string).
#' @param y Name of the objective for the y-axis (string).
#' @param fordm_method Either "regret" or "satisficing".
#' 
#' @return A ggplot2 object showing the 2D Pareto front for the selected objectives.
#' 
#' @export
visualize_fordm_2d <- function(analysis_output, x, y, fordm_method) {
  df <- analysis_output$pareto_front
  available <- names(df)
  if (!(x %in% available)) stop(sprintf("Column '%s' not found in pareto_front_%s. Available: %s", x, values, paste(available, collapse=", ")))
  if (!(y %in% available)) stop(sprintf("Column '%s' not found in pareto_front_%s. Available: %s", y, values, paste(available, collapse=", ")))
  #expand axis range 
  x_min <- min(df[[x]], na.rm = TRUE)*0.95
  x_max <- max(df[[x]], na.rm = TRUE)*1.05
  y_min <- min(df[[y]], na.rm = TRUE)*0.95
  y_max <- max(df[[y]], na.rm = TRUE)*1.05

  #Plot specification
  if (fordm_method == "satisficing") {
    ro <- analysis_output$robustness
    title <- "2D FoRDM Pareto Front (Satisficing)"
    subtitle <- paste0("objective values at ",ro*100,"% robustness")
    ggplot2::ggplot(df, ggplot2::aes(x = .data[[x]], y = .data[[y]], fill = satisficing*100)) +
      ggplot2::geom_point(shape = 21, size = 8, color = "black", stroke = 1, alpha = 0.7) +
      ggplot2::geom_text(ggplot2::aes(label = .data[["management"]]), hjust = 0.5, vjust = -0.85, size = 5) +
      ggplot2::labs(
        title = title,
        subtitle = subtitle,
        x = x,
        y = y,
        fill = "robustness [%]"
      ) +
      ggplot2::ylim(y_min, y_max) +
      ggplot2::xlim(x_min, x_max) +
      scale_fill_gradientn(
        colors = c("red", "yellow", "#d1d63b"),
        values = c(0, 0.8, 1),
        limits = c(60, 100)) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 17, face = "bold"),
        axis.title.x = ggplot2::element_text(size = 16),
        axis.title.y = ggplot2::element_text(size = 16),
        axis.text.x = ggplot2::element_text(size = 16),
        axis.text.y = ggplot2::element_text(size = 16)
      )
  } else if(fordm_method == "regret"){
    me <- analysis_output$method
    ro <- analysis_output$robustness
    if(me == "regretII"){
      title <- "2D FoRDM Pareto Front (Regret II)"
      subtitle <- paste0("objective values at ",ro*100,"% robustness")
    }
    if(me == "CVaR"){
      title <- "2D FoRDM Pareto Front (CVaR)"
      subtitle <- paste0("CVaR per objective of ",(1-ro)*100,"% worst SOWs")
    }
    ggplot2::ggplot(df, ggplot2::aes(x = .data[[x]], y = .data[[y]])) +
      ggplot2::geom_point(shape = 21, size = 8, fill = "#d1d63b", color = "black", stroke = 1, alpha = 0.6) +
      ggplot2::geom_text(ggplot2::aes(label = .data[["management"]]), hjust = 0.5, vjust = -0.85, size = 5) +
      ggplot2::labs(
        title = title,
        subtitle = subtitle,
        x = x,
        y = y
      ) +
      ggplot2::ylim(y_min, y_max) +
      ggplot2::xlim(x_min, x_max) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 17, face = "bold"),
        axis.title.x = ggplot2::element_text(size = 16),
        axis.title.y = ggplot2::element_text(size = 16),
        axis.text.x = ggplot2::element_text(size = 16),
        axis.text.y = ggplot2::element_text(size = 16)
      )
  } else stop("Unknown fordm method")
}

#' Visualize 3D Pareto Front
#'
#' Plots a 3D plot of the Pareto front of management alternatives from FoRDM_analysis output.
#' 
#' @param analysis_output Output from FoRDM_analysis_regret or FoRDM_analysis_satisficing.
#' @param x Name of the objective for the x-axis (string).
#' @param y Name of the objective for the y-axis (string).
#' @param z Name of the objective for the z-axis (string).
#' @param fordm_method Either "regret" or "satisficing".
#' 
#' @return A plotly object showing the 3D Pareto front for the selected objectives.
#' 
#' @export
visualize_fordm_3d <- function(analysis_output, x, y, z, fordm_method) {
  df <- analysis_output$pareto_front
  
  #error check for column specification
  available <- names(df)
  for (var in c(x, y, z)) {
    if (!(var %in% available)) {
      stop(sprintf("Column '%s' not found in pareto_front. Available: %s", 
                   var, paste(available, collapse = ", ")))
    }
  }
  
  if (fordm_method == "satisficing") {
    ro <- analysis_output$robustness
    title <- "3D FoRDM Pareto Front (Satisficing)"
    subtitle <- paste0("objective values at ",ro*100,"% robustness")
    plotly::plot_ly(
      df,
      x = ~.data[[x]],
      y = ~.data[[y]],
      z = ~.data[[z]],
      type = "scatter3d",
      mode = "markers+text",
      marker = list(
        size = 11,
        symbol = 'circle',
        line = list(width = 1, color = 'black'),
        color = ~satisficing*100,
        colorscale = list(c(0, "red"),c(0.8,"yellow"), c(1, "#d1d63b")),
        cmin = 60,
        cmax = 100,
        colorbar = list(title = "robustness [%]",
                        titlefont = list(size = 15),
                        tickfont = list(size = 15),
                        thickness = 20,
                        len = 0.5)
      ),
      text = ~.data[["management"]],
      textposition = "top center",
      hoverinfo = "text",
      hovertext = ~paste(
        "<b>Management:</b>", .data[["management"]], "<br>",
        "<b>", x, ":</b>", signif(.data[[x]], 4), "<br>",
        "<b>", y, ":</b>", signif(.data[[y]], 4), "<br>",
        "<b>", z, ":</b>", signif(.data[[z]], 4), "<br>",
        "<b>robustness:</b>", signif(.data[["satisficing"]], 3)
      )
    ) %>%
      plotly::layout(
        scene = list(
          xaxis = list(title = x),
          yaxis = list(title = y),
          zaxis = list(title = z)
        ),
        font = list(size = 14.5),
        margin = list(t = 10, b = 40, l = 20, r = 20),
        title = list(text = paste(title, if(!is.null(subtitle)) paste0("<br><sub>", subtitle, "</sub>")), y = 0.95)
      )
  } else if(fordm_method == "regret") {
    me <- analysis_output$method
    ro <- analysis_output$robustness
    if(me == "regretII"){
      title <- "3D FoRDM Pareto Front (Regret II)"
      subtitle <- paste0("Objective values at ", ro*100, "% robustness")
    }
    if(me == "CVaR"){
      title <- "3D FoRDM Pareto Front (CVaR)"
      subtitle <- paste0("CVaR per objective of ", (1-ro)*100, "% worst SOWs")
    }
    plotly::plot_ly(
      df,
      x = ~.data[[x]],
      y = ~.data[[y]],
      z = ~.data[[z]],
      type = "scatter3d",
      mode = "markers+text",
      marker = list(
        size = 11,
        symbol = 'circle',
        line = list(width = 1, color = 'black'),
        color = '#d1d63b',
        opacity = 0.8
      ),
      text = ~.data[["management"]],
      textposition = "top center",
      hoverinfo = "text",
      hovertext = ~paste(
        "<b>Management:</b>", .data[["management"]], "<br>",
        "<b>", x, ":</b>", signif(.data[[x]], 4), "<br>",
        "<b>", y, ":</b>", signif(.data[[y]], 4), "<br>",
        "<b>", z, ":</b>", signif(.data[[z]], 4)
      )
    ) %>%
      plotly::layout(
        scene = list(
          xaxis = list(title = x),
          yaxis = list(title = y),
          zaxis = list(title = z)
        ),
        font = list(size = 14.5),
        margin = list(t = 10, b = 40, l = 20, r = 20),
        title = list(text = paste(title, if(!is.null(subtitle)) paste0("<br><sub>", subtitle, "</sub>")), y = 0.95)
      )
  } else stop("Unkown fordm method")
}

#' Visualize a Parallel Coordinates plot of the Pareto Front for FoRDM Analysis Results
#'
#' Creates a parallel coordinates plot showing the Pareto front from FoRDM analysis.
#'
#' @param analysis_output Output from fordm_analysis_regret() or fordm_analysis_satisficing().
#' @param fordm_method Either "regret" or "satisficing".
#' 
#' @return A parallel coordinates plot object.
#' 
#' @export
visualize_fordm_parcoord <- function(analysis_output, fordm_method) {
  df <- analysis_output$pareto_front
  
  if (fordm_method == "regret") {
    obj_cols <- setdiff(names(df), c("management", grep("^regret_", names(df), value = TRUE)))
    parcoord_data <- df %>% dplyr::select(management, dplyr::all_of(obj_cols))
    dimensions <- lapply(obj_cols, function(obj) {
      rng <- range(parcoord_data[[obj]], na.rm = TRUE)
      tickvals <- c(rng[1], rng[2])
      ticktext <- sprintf("%.2f", tickvals)
      list(
        label = obj,
        values = as.formula(paste0("~`", obj, "`")),
        range = rng,
        tickvals = tickvals,        
        ticktext = ticktext
      )
    })
    me <- analysis_output$method
    ro <- analysis_output$robustness
    if (me == "regretII") {
      title <- "Parallel Coordinates Plot (Regret II)"
      subtitle <- paste0("Pareto front - objective values at ", ro*100, "% robustness")
    }
    if (me == "CVaR") {
      title <- "Parallel Coordinates Plot (CVaR)"
      subtitle <- paste0("Pareto front - CVaR per objective of ", (1-ro)*100, "% worst SOWs")
    }
    p <- plotly::plot_ly(
      parcoord_data,
      type = "parcoords",
      line = list(color = "#d1d63b"),
      dimensions = dimensions,
      domain = list(
        x = c(0, 1),
        y = c(0, 0.93)
      )
    ) %>%
      plotly::layout(
        font = list(size = 19),
        title = list(text = paste0(title, "<br><sub>", subtitle, "</sub>"), y = 0.95),
        margin = list(t = 100, l = 80, r = 80)
      )
    
  } else if (fordm_method == "satisficing") {
    obj_cols <- setdiff(names(df), c("management", "satisficing"))
    parcoord_data <- df %>% dplyr::select(management, dplyr::all_of(obj_cols), satisficing)
    dimensions <- lapply(obj_cols, function(obj) {
      rng <- range(parcoord_data[[obj]], na.rm = TRUE)
      list(
        label = obj,
        values = as.formula(paste0("~`", obj, "`")),
        range = rng,
        tickvals = rng,
        ticktext = sprintf("%.2f", rng)
      )
    })
    dimensions[[length(dimensions) + 1]] <- list(
      label = "Robustness [%]",
      values = ~satisficing * 100,
      range = c(60, 100),
      tickvals = c(60, 100),
      ticktext = c("60", "100")
    )
    p <- plotly::plot_ly(
      parcoord_data,
      type = "parcoords",
      line = list(
        color = ~satisficing * 100,
        colorscale = list(c(0, "red"),c(0.8, "yellow"),c(1, "#d1d63b")),
        cmin = 60,
        cmax = 100,
        colorbar = list(title = "Robustness [%]",
                        titlefont = list(size = 15),
                        tickfont = list(size = 15),
                        thickness = 20,
                        len = 0.5)
      ),
      dimensions = dimensions,
      domain = list(
        x = c(0, 1),
        y = c(0, 0.93)
      )
    ) %>%
      plotly::layout(
        title = list(text = "Parallel Coordinates Plot (Satisficing)<br><sub>Pareto front - mean objective values across SOWs</sub>", y = 0.95),
        font = list(size = 19),
        margin = list(t = 100, l = 80, r = 80)
      )
  } else {
    stop("Unknown fordm_method. Must be 'regret' or 'satisficing'.")
  }
  p
}

#' Visualize Parallel Coordinates Plot for a single selected management across all SOWs
#'
#' Creates a parallel coordinates plot showing SOW performance across objectives for a selected management strategy.
#'
#' @param fordm_table Output from build_fordm_table().
#' @param objectives Output from build_objectives_regret() or build_objectives_satisficing().
#' @param fordm_method Either "regret" or "satisficing".
#' @param management Character string specifying which management to visualize.
#' 
#' @return A parallel coordinates plot object.
#' 
#' @export
visualize_fordm_parcoord_management <- function(fordm_table, objectives, fordm_method, management) {
  data <- fordm_table$data
  mapping <- fordm_table$mapping
  management_col <- mapping$management
  sow_col <- mapping$sow
  time_col <- mapping$time
  obj_col <- objectives$names
  
  #Error check for management
  if (!(management %in% unique(data[[management_col]]))) {
    stop(sprintf("Management '%s' not found. Available: %s", 
                 management, paste(unique(data[[management_col]]), collapse = ", ")))
  }
  
  #Selection and calculation of management (analog to regret or satisficing based calculation)
  data_mgmt <- data[data[[management_col]] == management, ]
  df_aggregated <- dplyr::group_by(data_mgmt, .data[[sow_col]])
  df_aggregated <- dplyr::summarise(
    df_aggregated,
    dplyr::across(
      dplyr::all_of(obj_col),
      ~ {
        timeagg <- objectives$time_aggregation[obj_col == dplyr::cur_column()]
        disc_rate <- objectives$discount_rate[obj_col == dplyr::cur_column()]
        time_aggregation_fun(.x, data_mgmt[[time_col]][dplyr::cur_group_rows()], timeagg, disc_rate, fordm_table$time_unit)
      }
    ),
    .groups = "drop"
  )
  #regret-based calculation
  if (fordm_method == "regret") {
    for (i in seq_along(objectives$names)) {
      col <- objectives$names[i]
      dir <- objectives$direction[i]
      data_all <- dplyr::group_by(data, .data[[management_col]], .data[[sow_col]])
      data_all <- dplyr::summarise(
        data_all,
        !!col := {
          timeagg <- objectives$time_aggregation[i]
          disc_rate <- objectives$discount_rate[i]
          time_aggregation_fun(.data[[col]], data[[time_col]][dplyr::cur_group_rows()], timeagg, disc_rate, fordm_table$time_unit)
        },
        .groups = "drop"
      )
      
      if (dir == "maximize") {
        global_ideal <- max(data_all[[col]], na.rm = TRUE)
        regret <- (global_ideal - df_aggregated[[col]]) / pmax(abs(global_ideal), 1e-12)
      } else if (dir == "minimize") {
        global_ideal <- min(data_all[[col]], na.rm = TRUE)
        regret <- (df_aggregated[[col]] - global_ideal) / pmax(abs(global_ideal), 1e-12)
      }
      
      regret <- pmax(regret, 0)
      df_aggregated[[paste0("regret_", col)]] <- regret
    }
    df_aggregated <- df_aggregated %>%
      dplyr::rowwise() %>%
      dplyr::mutate(
        regret_scalar = sum(dplyr::c_across(dplyr::starts_with("regret_")) * objectives$weights, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()
    df_aggregated <- df_aggregated %>%
      dplyr::mutate(
        robustness = ecdf(regret_scalar)(regret_scalar) * 100
      )
    parcoord_data <- df_aggregated %>%
      dplyr::select(dplyr::all_of(obj_col), robustness, dplyr::all_of(sow_col))
    dimensions <- list()
    for (obj in obj_col) {
      rng <- range(parcoord_data[[obj]], na.rm = TRUE)
      tickvals <- rng
      ticktext <- sprintf("%.2f", rng)  # round to 2 decimals
      
      dimensions[[length(dimensions) + 1]] <- list(
        label = obj,
        values = as.formula(paste0("~`", obj, "`")),
        range = rng,
        tickvals = tickvals,
        ticktext = ticktext
      )
    }
    rng <- c(0, 100)
    tickvals <- rng
    ticktext <- sprintf("%.2f", rng)
    dimensions[[length(dimensions) + 1]] <- list(
      label = "Robustness [%]",
      values = ~robustness,
      range = rng,
      tickvals = tickvals,
      ticktext = ticktext
    )
    #plot
    p <- plotly::plot_ly(
      parcoord_data,
      type = 'parcoords',
      line = list(
        color = ~robustness,
        colorscale = list(
          c(0, "red"),
          c(0.8,"yellow"),
          c(1, "#d1d63b")
        ),
        cmin = 0,
        cmax = 100,
        colorbar = list(title = "Robustness [%]",
                        titlefont = list(size = 15),
                        tickfont = list(size = 15),
                        thickness = 20,
                        len = 0.6)
      ),
      dimensions = dimensions,
      domain = list(
        x = c(0, 1),
        y = c(0, 0.93)
      ),
      customdata = as.formula(paste0("~", sow_col))
    ) %>%
      plotly::layout(
        title = list(
          text = paste0("Parallel Coordinates Plot (Regret)<br><sub>Management: ", 
                       management, " - SOWs colored by robustness percentile</sub>"),
          y = 0.95
        ),
        font = list(size = 19),
        margin = list(t = 100, l = 80, r = 80)
      )
    #satisficing-based calculation
  } else if (fordm_method == "satisficing") {
    for (obj in obj_col) {
      thr <- objectives$threshold[objectives$names == obj]
      dir <- tolower(objectives$direction[objectives$names == obj])
      flag_col <- paste0("flag_", obj)
      
      if (dir == "above") {
        df_aggregated[[flag_col]] <- !is.na(df_aggregated[[obj]]) & (df_aggregated[[obj]] >= thr)
      } else if (dir == "below") {
        df_aggregated[[flag_col]] <- !is.na(df_aggregated[[obj]]) & (df_aggregated[[obj]] <= thr)
      } else {
        stop("Unknown direction: ", dir)
      }
    }
    flag_cols <- paste0("flag_", objectives$names)
    df_aggregated <- df_aggregated %>%
      dplyr::mutate(
        all_satisfied = dplyr::if_all(dplyr::all_of(flag_cols), ~ .x)
      )
    parcoord_data <- df_aggregated %>%
      dplyr::select(dplyr::all_of(obj_col), all_satisfied, dplyr::all_of(sow_col))
    dimensions <- list()
    for (i in seq_along(obj_col)) {
      obj <- obj_col[i]
      
      obj_range <- c(min(parcoord_data[[obj]], na.rm = TRUE), 
                     max(parcoord_data[[obj]], na.rm = TRUE))
      
      dimensions[[i]] <- list(
        label = obj,
        values = as.formula(paste0("~`", obj, "`")),
        range = obj_range,
        tickvals = obj_range,                
        ticktext = sprintf("%.2f", obj_range)
      )
    }
    #plot
   p <- plotly::plot_ly(
      parcoord_data,
      type = 'parcoords',
      line = list(
        color = ~ifelse(all_satisfied, 1, 0),
        colorscale = list(
          c(0, "red"),
          c(0.5, "red"),
          c(0.5, "#d1d63b"),
          c(1, "#d1d63b")
        ),
        cmin = 0,
        cmax = 1,
        colorbar = list(
          title = "Status",
          tickmode = "array",
          tickvals = c(0.25, 0.75),
          ticktext = c("Not Satisfied", "All Satisfied"),
          thickness = 20,
          len = 0.5,
          titlefont = list(size = 15),
          tickfont = list(size = 15)
        )
      ),
      dimensions = dimensions,
      domain = list(
        x = c(0, 1),
        y = c(0, 0.93)
      ),
      customdata = as.formula(paste0("~", sow_col))
    ) %>%
      plotly::layout(
        title = list(
          text = paste0("Parallel Coordinates Plot (Satisficing)<br><sub>Management: ", 
                       management, " - SOWs colored by threshold satisfaction</sub>"),
          y = 0.95
        ),
        font = list(size = 19),
        margin = list(t = 100, l = 80, r = 80)
      )
    
  } else {
    stop("Unknown fordm_method. Must be 'regret' or 'satisficing'.")
  }
  
  return(p)
}

#' Robustness Trade-Off Analysis (Regret-based)
#'
#' Analyzes what happens when you sacrifice robustness for better performance.
#' Shows marginal benefits and losses for each objective when switching between management strategies across different robustness levels.
#'
#' @param fordm_table Output from build_FoRDM_table().
#' @param objectives Output from build_objectives_regret().
#' 
#' @return List containing the list of optimal managements at certain robustness levels, and a plot
#' 
#' @export
robustness_tradeoff_analysis <- function(fordm_table, objectives) {
  data <- fordm_table$data
  mapping <- fordm_table$mapping
  management_col <- mapping$management
  sow_col <- mapping$sow
  time_col <- mapping$time
  obj_col <- objectives$names
  dir_col <- objectives$direction
  
  #1. Aggregate objective values across time
  df_aggregated <- dplyr::group_by(data, .data[[management_col]], .data[[sow_col]])
  df_aggregated <- dplyr::summarise(
    df_aggregated,
    dplyr::across(
      dplyr::all_of(obj_col),
      ~ {
        timeagg <- objectives$time_aggregation[obj_col == dplyr::cur_column()]
        disc_rate <- objectives$discount_rate[obj_col == dplyr::cur_column()]
        time_aggregation_fun(.x, data[[time_col]][dplyr::cur_group_rows()], timeagg, disc_rate, fordm_table$time_unit)
      }
    ),
    .groups = "drop"
  )
  
  #2. Calculate regret for each objective
  for (i in seq_along(objectives$names)) {
    col <- objectives$names[i]
    dir <- objectives$direction[i]
    if (dir == "maximize") {
      global_ideal <- max(df_aggregated[[col]], na.rm = TRUE)
      regret <- (global_ideal - df_aggregated[[col]]) / pmax(abs(global_ideal), 1e-12)
    } else if (dir == "minimize") {
      global_ideal <- min(df_aggregated[[col]], na.rm = TRUE)
      regret <- (df_aggregated[[col]] - global_ideal) / pmax(abs(global_ideal), 1e-12)
    }
    regret <- pmax(regret, 0)
    df_aggregated[[paste0("regret_", col)]] <- regret
  }
  
  #3. Calculate weighted regret scalar
  df_scalar <- df_aggregated %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      regret_scalar = sum(dplyr::c_across(dplyr::starts_with("regret_")) * objectives$weights, na.rm = TRUE)
    ) %>%
    dplyr::ungroup()
  
  #4. Robustness levels (0.5 to 1.0 in 0.05 steps)
  robustness_range <- seq(1.0, 0.0, by = -0.05)
  
  #5. Loop through robustness levels and track optimal management
  results <- list()
  prev_best_mgmt <- NULL
  best_mgmt_tracker <- character(length(robustness_range))
  for (i in seq_along(robustness_range)) {
    rr <- robustness_range[i]
    df_quantile <- df_scalar %>%
      dplyr::group_by(.data[[management_col]]) %>%
      dplyr::mutate(
        regret_quantile = quantile(regret_scalar, probs = rr, na.rm = TRUE)
      ) %>%
      dplyr::ungroup()
    df_final <- df_quantile %>%
      dplyr::group_by(.data[[management_col]]) %>%
      dplyr::slice_min(abs(regret_scalar - regret_quantile), n = 1, with_ties = FALSE) %>%
      dplyr::ungroup()
    #Select the optimal management at each robustness level
    best_row <- df_final[which.min(df_final$regret_scalar), ] %>%
      select(all_of(management_col),all_of(obj_col))
    #
    df_final <- dplyr::mutate(df_final, robustness_level = rr)
    best_mgmt_tracker[i] <- best_row[[management_col]]
    #Add tracking columns
    df_final <- dplyr::mutate(
      df_final,
      best_mgmt = best_row[[management_col]],
      prev_best_mgmt = prev_best_mgmt,
    )
    prev_best_mgmt <- best_row[[management_col]]
    results[[as.character(rr)]] <- df_final
  }
  #Add next best management tracking
  for (i in seq_along(results)) {
    next_best <- if (i < length(results)) best_mgmt_tracker[i + 1] else NA
    results[[i]] <- dplyr::mutate(results[[i]], next_best_mgmt = next_best)
  }
  
  # 6. Identify switches and calculate benefit/loss for each switch
  best_mgmt_tracker_unique <- best_mgmt_tracker[!duplicated(best_mgmt_tracker)]
  switch_indices <- match(best_mgmt_tracker_unique, best_mgmt_tracker)[-1]
  #only include robustness recommendations until 50% robustness
  for(i in seq_along(switch_indices)){
    if(switch_indices[i]>11){
      switch_indices <- switch_indices[-i]
      best_mgmt_tracker_unique <- best_mgmt_tracker_unique[-(i+1)]
    }
  }
  #Add first output for initial management
  if(length(switch_indices) >= 1){
    initial_range <- robustness_range[1:(switch_indices[1]-1)]
  } else{
    initial_range <- robustness_range[1:21]
  }
  initial_row <- as.data.frame(tibble::tibble(
    robustness_range = paste0(min(initial_range), "-", max(initial_range)),
    optimal_management = best_mgmt_tracker[1]
  ))
  #in case of switch:
  if(length(switch_indices) >= 1){ 
    summary_list <- list()
    for (si in seq_along(switch_indices)) {
      idx <- switch_indices[si]
      mgmt <- best_mgmt_tracker[idx]
      benefit_range <- robustness_range[idx:21]
      loss_range <- robustness_range[1:(idx-1)]
      prev_mgmts <- unique(best_mgmt_tracker[1:(idx - 1)])
      benefit_diffs <- list()
      loss_diffs <- list()
      for (prev_mgmt in prev_mgmts) {
        benefit_diffs[[prev_mgmt]] <- list()
        loss_diffs[[prev_mgmt]] <- list()
        for (obj in obj_col) {
          benefit_diffs[[prev_mgmt]][[obj]] <- c()
          loss_diffs[[prev_mgmt]][[obj]] <- c()
        }
      }
      #Benefit for each robustness level and previous management
      for (i in idx:21) {
        val_best <- results[[i]] %>%
          dplyr::filter(.data[[management_col]] == mgmt) %>%
          dplyr::select(all_of(obj_col))
        for (prev_mgmt in prev_mgmts) {
          val_previous <- results[[i]] %>%
            dplyr::filter(.data[[management_col]] == prev_mgmt) %>%
            dplyr::select(all_of(obj_col))
          if (nrow(val_best) > 0 && nrow(val_previous) > 0) {
            for (j in 1:nrow(val_previous)) {
              for (obj in obj_col) {
                diff <- as.numeric(val_best[[obj]]) - as.numeric(val_previous[j, obj])
                benefit_diffs[[prev_mgmt]][[obj]] <- c(benefit_diffs[[prev_mgmt]][[obj]], diff)
              }
            }
          }
        }
      }
      
      #Loss for each robustness level and previous management
      for (i in 1:(idx-1)) {
        val_best <- results[[i]] %>%
          dplyr::filter(.data[[management_col]] == mgmt) %>%
          dplyr::select(all_of(obj_col))
        for (prev_mgmt in prev_mgmts) {
          val_previous <- results[[i]] %>%
            dplyr::filter(.data[[management_col]] == prev_mgmt) %>%
            dplyr::select(all_of(obj_col))
          if (nrow(val_best) > 0 && nrow(val_previous) > 0) {
            for (j in 1:nrow(val_previous)) {
              for (obj in obj_col) {
                diff <- as.numeric(val_best[[obj]]) -  as.numeric(val_previous[j, obj])
                loss_diffs[[prev_mgmt]][[obj]] <- c(loss_diffs[[prev_mgmt]][[obj]], diff)
              }
            }
          }
        }
      }
      
      #Min/mean/max values across loss and benefit for each management and objective
      benefit_stats <- list()
      loss_stats <- list()
      for (prev_mgmt in prev_mgmts) {
        for (obj in obj_col) {
          bdiffs <- benefit_diffs[[prev_mgmt]][[obj]]
          ldiffs <- loss_diffs[[prev_mgmt]][[obj]]
          benefit_stats[[paste0(prev_mgmt, "_", obj, "_benefit_min")]] <- if(length(bdiffs)) min(bdiffs, na.rm = TRUE) else NA
          benefit_stats[[paste0(prev_mgmt, "_", obj, "_benefit_mean")]] <- if(length(bdiffs)) mean(bdiffs, na.rm = TRUE) else NA
          benefit_stats[[paste0(prev_mgmt, "_", obj, "_benefit_max")]] <- if(length(bdiffs)) max(bdiffs, na.rm = TRUE) else NA
          loss_stats[[paste0(prev_mgmt, "_", obj, "_loss_min")]] <- if(length(ldiffs)) min(ldiffs, na.rm = TRUE) else NA
          loss_stats[[paste0(prev_mgmt, "_", obj, "_loss_mean")]] <- if(length(ldiffs)) mean(ldiffs, na.rm = TRUE) else NA
          loss_stats[[paste0(prev_mgmt, "_", obj, "_loss_max")]] <- if(length(ldiffs)) max(ldiffs, na.rm = TRUE) else NA
        }
      }
  
      #Summary
      summary_row <- tibble::tibble(
        robustness_range = paste0(min(benefit_range), "-", max(benefit_range)),
        optimal_management = mgmt
      )
      for (nm in names(benefit_stats)) {
        summary_row[[nm]] <- benefit_stats[[nm]]
      }
      for (nm in names(loss_stats)) {
        summary_row[[nm]] <- loss_stats[[nm]]
      }
      summary_list[[si]] <- as.data.frame(summary_row)
    }
    summary_list <- c(list(initial_row), summary_list)
  } else{
    summary_list <- list(data.frame(
      robustness_range = paste0("0-1"),
      optimal_management = best_mgmt_tracker_unique))
  }
  
  #plot values across robustness levels
  results_selected <- lapply(results, function(df) {
    dplyr::select(df, dplyr::all_of(management_col), robustness_level, dplyr::all_of(obj_col))
  })
  all_results <- do.call(rbind, results_selected)
  #Only keep optimal management rows
  optimal_managements <- best_mgmt_tracker_unique
  optimal_rows <- all_results[all_results[[management_col]] %in% optimal_managements, ]
  plot_data <- optimal_rows %>%
    tidyr::pivot_longer(cols = dplyr::all_of(obj_col), names_to = "objective", values_to = "value")
  #Barplot: mean value per management per objective
  plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = .data[[management_col]], y = value)) +
    ggplot2::geom_point(ggplot2::aes(fill = robustness_level*100), shape = 21, color = "black", stroke = 0.1, size = 4) +
    ggplot2::facet_wrap(~objective, scales = "free_y") +
    ggplot2::labs(
      title = "Expected Objective Values for Optimal Managements Across Robustness Range (0 - 100%)",
      x = "Management",
      y = "Objective Value"
    ) +
    ggplot2::theme_bw() +
   ggplot2::scale_fill_gradientn(
      colors = c("darkred","red", "yellow", "#d1d63b"),
      values = c(0,0.5,0.7, 1),
      name = "Robustness [%]") +
    ggplot2::theme(
      strip.text = ggplot2::element_text(size = 14, face = "bold"),
      plot.title = ggplot2::element_text(size = 17, face = "bold"),
      axis.title.x = ggplot2::element_text(size = 16),
      axis.title.y = ggplot2::element_text(size = 16),
      axis.text.x = ggplot2::element_text(size = 14, angle = 45, hjust = 1),
      axis.text.y = ggplot2::element_text(size = 14)
    )

  return(list(summary = summary_list, plot = plot))
}


