# lib/paths.sh — resolve project root when invoked from bin/<script>.sh
# -----------------------------------------------------------------------------
# Usage (before sourcing lib/config.sh):
#   _bin_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=paths.sh
#   source "$_bin_here/../lib/paths.sh"
#   SCRIPT_DIR="$(um_project_root_from_bin_path "${BASH_SOURCE[0]}")"
# -----------------------------------------------------------------------------

um_project_root_from_bin_path() {
    (cd "$(dirname "$1")/.." && pwd)
}
