# ---
# title: Locate the _setup Inputs on ABMI-DATA2
# author: Brendan Casey
# created: 2026-10-05
# inputs: none
# outputs: none; defines setup_input_root and setup_input()
# notes:
#   - Every external file _setup/ reads is mirrored, unchanged,
#     under //ABMI-DATA2/science/sdmMethodsDev/0_data/
#     setup_inputs/ by 00_mirror_setup_inputs.R, so _setup/ can be
#     run by anyone with access to that share. The originals stay
#     where they were; 00_mirror_setup_inputs.R lists them and
#     setup_inputs/inputs_manifest.csv records each copy.
#   - The scripts' own SDM_* environment variables still override
#     each path, so a source can be read from its original
#     location. SDM_SETUP_INPUT_ROOT moves the whole mirror.
# ---

# 1. The mirror root ----
setup_input_root <- Sys.getenv(
  "SDM_SETUP_INPUT_ROOT",
  unset = "//ABMI-DATA2/science/sdmMethodsDev/0_data/setup_inputs"
)

# 2. setup_input() ----

#' Build a Path Inside the _setup Input Mirror
#'
#' @param ... Character. Path components below the mirror root,
#'   starting with the source folder (for example "bird_models").
#' @return Character. The full path.
#'
#' @example # Example usage of the function
#' # setup_input("bird_models", "Data", "lookups", "birdlist.csv")
setup_input <- function(...) {
  file.path(setup_input_root, ...)
}

# End of script ----
